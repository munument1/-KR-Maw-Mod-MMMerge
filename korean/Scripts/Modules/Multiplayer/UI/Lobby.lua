local events = Multiplayer.events
local UIUtils = Multiplayer.require("UI/UtilsUI.lua")
local relay = Multiplayer.require("Network/Relay.lua")
local conn = Multiplayer.require("Network/Lobby.lua")
local msgs = Multiplayer.require("Network/Lobby/Messages.lua")

local function TextTumbler(...)
	return UIUtils.TextTumbler(Multiplayer.UI_SCREEN, ...)
end
local function SimpleText(...)
	return UIUtils.SimpleText(Multiplayer.UI_SCREEN, ...)
end

-- Create "Direct connect / server list" tumbler for client
local UpdateHostTable
local ServerListOpen = false

local ClienConnTumb = TextTumbler(350, 125, nil, "서버 목록", " 직접 연결", true,
	function(self)
		ServerListOpen = self.On
		if ServerListOpen then
			conn.EnableLobbyLookup()
			conn.BroadcastHostsListRequest()
			Multiplayer.utils.delayed_call2(UpdateHostTable, 200)
		else
			conn.DisableLobbyLookup()
		end
	end,
	function() return not conn.ImHost() and Multiplayer.in_game and Multiplayer.CurrentUITab() == "connection" end
)

local function ToggleServerList(state)
	if state == nil then
		ServerListOpen = not ServerListOpen
		ClienConnTumb.set_state(ServerListOpen)
	else
		ServerListOpen = state
		ClienConnTumb.set_state(state)
	end
	return ServerListOpen
end

function events.MultiplayerStopped()
	ToggleServerList(false)
end

function events.MultiplayerStarted()
	ToggleServerList(false) -- Multiplayer.selected_role() == "client"
end

function events.MultiplayerRoleChanged(role)
	ToggleServerList(false) -- role == "client"
end

-- Create "Closed / Open" tumbler for host with "?" button for tooltip

local HostOpenTumb = TextTumbler(480, 125, nil, "열림 ", "닫힘", false,
	function(self)
		if self.On then
			local inputs = {
				{header = "이름:       ", default = conn.MyHostGlobals.Name, empty = "서버 이름 입력", multiline = false, limit = 40},
				{header = "비밀번호:   ", default = conn.MyHostGlobals.Password, empty = "없음", multiline = false, hidden = true, limit = 40},
				{header = "설명:", default = conn.MyHostGlobals.Description, empty = "서버 설명 입력", multiline = true},
			}

			UIUtils.PopupInput(
				"로비 열기", "서버 정보 입력:", inputs, "  열기 ", nil,
				function(values)
					conn.MyHostGlobals.Name = values[inputs[1].header]
					conn.MyHostGlobals.Password = values[inputs[2].header]
					conn.MyHostGlobals.Description = values[inputs[3].header]
					conn.EnableLobbyLookup()
					conn.BroadcastMyHost()
				end,
				function()
					self.set_state(conn.LobbyLookupState())
				end)
		else
			conn.DisableLobbyLookup()
		end
	end,
	function() return conn.ImHost() and Multiplayer.in_game and Multiplayer.CurrentUITab() == "connection" end
)

function events.MultiplayerStopped()
	conn.DisableLobbyLookup()
	HostOpenTumb.set_state(false)
end

function events.MultiplayerRoleChanged(role)
	if role ~= "host" then
		conn.DisableLobbyLookup()
		HostOpenTumb.set_state(false)
	end
end

function events.LobbyHostingEnabled()
	HostOpenTumb.set_state(true)
end

function events.LobbyHostingDisabled()
	HostOpenTumb.set_state(false)
end

SimpleText("?", 620, 125, nil,
	function() return conn.ImHost() and Multiplayer.in_game and Multiplayer.CurrentUITab() == "connection" end,
	function()
		CustomUI.DisplayTooltip("비공개 서버는 직접 연결만 허용합니다.\n  \n공개 LAN 서버는 로컬 네트워크에서 찾을 수 있습니다.\n  \n인터넷 공개 서버는 접속 가능한 로비 서버에 등록됩니다.", 30)
	end
)

-- Create hosts table

local function _ServerListOpen()
	return ServerListOpen and Multiplayer.CurrentUITab() == "connection"
end

local function LobbyHosts()
	local hosts
	if not Multiplayer.internet_connection then
		hosts = conn.LANHosts
		for _, host in pairs(hosts) do
			host.Lobby = "LAN"
			host.LobbyAddr = msgs.LAN_LOBBY
		end
	else
		hosts = {}
		for addr, lobby in pairs(conn.Lobbies) do
			for _, host in pairs(lobby.Hosts) do
				host.Lobby = lobby.Name
				host.LobbyAddr = addr
				table.insert(hosts, host)
			end
		end
	end
	return hosts
end

local function FilterHosts(hosts)
	local result = {}
	for _, host in pairs(hosts) do
		if conn.Selection.SkipPassword and host.PasswordUsed or
			conn.Selection.SkipFull and host.Players >= host.MaxPlayers or
			#conn.Selection.Version > 0 and conn.Selection.Version ~= host.Version then
			-- do nothing
		else
			table.insert(result, host)
		end
	end

	table.sort(result, function(v1,v2) return v1.Name < v2.Name end)
	return result
end

local function ChangeRelay(Addr)
	if Multiplayer.internet_connection and relay.have_relay_access(Addr, true, false, 2000) then
		relay.set_relay_addrport(Addr:match("(%A*):(%d*)"))
	end
end

local function Connect(entry)
	local Input = entry.Data.PasswordUsed and {{header = "비밀번호", default = "", empty = "없음", hidden = true, limit = 40}}
	local Descr = entry.Data.Description

	local ServerDesc = ("%s\n  \n%s\n  \n%s\n  \n%s"):format(
		entry.Data.Name, Descr,
		("플레이어: %d / %d"):format(entry.Data.Players, entry.Data.MaxPlayers), "버전: " .. entry.Data.Version)

	local ProgressTemplate = "%d번째 시도. 응답을 기다리는 중..."
	local Attempt = 0
	local Request
	local function Caller()
		if Attempt > 0 and not conn.CurrentJoinRequest() then
			ChangeRelay(entry.Data.LobbyAddr)
			return true, "Connected"
		elseif Attempt == 4 then
			Attempt = Attempt + 1
			return false, "시간 초과"
		elseif Attempt > 4 then
			conn.ClearPendingRequests()
			return true, "시간 초과"
		end
		conn.Join(entry.Data.LobbyAddr, Request)
		Attempt = Attempt + 1
		return false, ProgressTemplate:format(Attempt)
	end

	local function Accepted(values)
		Request = msgs.NewJoinRequest(entry.Data.SessionCode, Multiplayer.my_session_code(), values and values[Input[1].header] or "")
		UIUtils.PopupProgress("연결할 서버: " .. entry.Data.Name, "", Caller, 3000, 15000, "JoiningLobby")
	end

	UIUtils.PopupInput("서버 연결", ServerDesc, Input, "연결", nil, Accepted)
end

function events.JoinLobbyRejected(reason)
	CustomUI.DisplayTooltip("참가 요청 거부: " .. reason, 30, nil, nil, nil, Multiplayer.UI_SCREEN)
end

local HostTable = UIUtils.TextTable(Multiplayer.UI_SCREEN, {"Repr"}, 40, 175, _ServerListOpen, {Repr = Connect})

UpdateHostTable = function()
	conn.PurgeInactive()
	local hosts = FilterHosts(LobbyHosts())
	for i, host in pairs(hosts) do
		hosts[i] = {Data = host, Repr = ("%d. %s | %s | %d / %d | %s | %s"):format(i, host.Name, host.PasswordUsed and "P" or " ", host.Players, host.MaxPlayers, host.Lobby, host.Version)}
	end
	HostTable:load(hosts)
end

function events.MultiplayerStopped()
	HostTable:clear()
end

-- Create table header

local HeaderY = 150

SimpleText("Update", 40, HeaderY, Game.Smallnum_fnt, _ServerListOpen,
	function()
		conn.BroadcastHostsListRequest()
		UpdateHostTable()
	end)

SimpleText("가득 찬 서버 숨기기", 150, HeaderY, Game.Smallnum_fnt,
	function() return _ServerListOpen() and not conn.Selection.SkipFull end,
	function() conn.Selection.SkipFull = true; UpdateHostTable() end
)
SimpleText("비밀번호 서버 숨기기", 250, HeaderY, Game.Smallnum_fnt,
	function() return _ServerListOpen() and not conn.Selection.SkipPassword end,
	function() conn.Selection.SkipPassword = true; UpdateHostTable() end
)
SimpleText("다른 버전 숨기기", 400, HeaderY, Game.Smallnum_fnt,
	function() return _ServerListOpen() and #conn.Selection.Version == 0 end,
	function() conn.Selection.Version = Multiplayer.VERSION; UpdateHostTable() end
)

SimpleText("가득 찬 서버 표시", 150, HeaderY, Game.Smallnum_fnt,
	function() return _ServerListOpen() and conn.Selection.SkipFull end,
	function() conn.Selection.SkipFull = false; UpdateHostTable() end
)
SimpleText("비밀번호 서버 표시", 250, HeaderY, Game.Smallnum_fnt,
	function() return _ServerListOpen() and conn.Selection.SkipPassword end,
	function() conn.Selection.SkipPassword = false; UpdateHostTable() end
)
SimpleText("다른 버전 표시", 400, HeaderY, Game.Smallnum_fnt,
	function() return _ServerListOpen() and #conn.Selection.Version > 0 end,
	function() conn.Selection.Version = ""; UpdateHostTable() end
)


Multiplayer.utils.MillisecCounter(function()
	if Game.CurrentScreen == Multiplayer.UI_SCREEN and ServerListOpen then
		conn.BroadcastHostsListRequest()
		UpdateHostTable()
	end
end, 10000)

--

return {
	ServerListOpen = _ServerListOpen,
	ToggleServerList = ToggleServerList
}
