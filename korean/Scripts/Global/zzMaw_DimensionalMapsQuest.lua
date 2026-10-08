local ORACLES = {[314] = 4, [413] = 4, [794] = 0}

local TIERS = {100, 140, 170, 200}
for level = 220, 500, 20 do
	TIERS[#TIERS + 1] = level
end

local TEXT_TOO_LOW = "세계 사이의 균열은 충분히 성장한 이들에게만 열립니다. 일행 중 한 명이 %d레벨에 도달하면 다시 찾아오십시오."
local TEXT_GIVE = "장막 너머를 살펴보다가 반대편 세계의 영향으로 뒤바뀐 장소를 발견했습니다. 이 지도를 받으십시오. %s의 문을 다시 열면 다른 차원의 생물들이 기다리고 있을 것입니다 (지도 레벨 %d). 그곳을 정리한 뒤 돌아오십시오."
local TEXT_NOT_CLEARED = "제가 알려드린 균열은 아직 남아 있습니다. 그곳을 정리한 뒤 돌아오십시오."
local TEXT_REWARD = "%s의 균열이 봉인됐군요. 보상으로 금화 %d개를 받으십시오."
local TEXT_ALL_DONE = "제가 찾은 균열을 모두 봉인하셨습니다. 더 알려드릴 곳이 없습니다."

local function highestLevel()
	local best = 0
	for i = 0, Party.High do
		best = math.max(best, Party[i].LevelBase)
	end
	return best
end

local function rollQuestMap(tier, level)
	if not vars.seed then
		vars.seed = os.time()
	end
	math.randomseed((vars.seed + tier*7919) % 2147483647)
	local pool = getDimensionMapPool()
	if #pool == 0 then
		pool = mapDungeons
	end
	assignedAffixes = {}
	local m = {}
	m.BonusStrength = pool[math.random(1, #pool)]
	m.Bonus2 = getUniqueAffix()
	m.Charges = getUniqueAffix()
	m.Charges = m.Charges + getUniqueAffix()*1000
	m.BonusExpireTime = getUniqueAffix()
	local roll = math.random()
	m.Bonus = roll <= 0.1 and 4 or roll < 0.3 and 3 or 2
	math.randomseed(os.time())
	m.MaxCharges = (level - 20)/10
	m.Level = getDimensionMapLevel(m.BonusStrength, m.MaxCharges)
	return m
end

local function giveMap(m)
	evt.Add("Items", 290)
	local it = Mouse.Item
	it.BonusStrength = m.BonusStrength
	it.Bonus = m.Bonus
	it.Bonus2 = m.Bonus2
	it.Charges = m.Charges
	it.BonusExpireTime = m.BonusExpireTime
	it.MaxCharges = m.MaxCharges
	if vars.madnessMode then
		vars.ownedMaps = (vars.ownedMaps or 0) + 1
	end
end

local function dimensionalMapsTopic()
	local q = vars.dimensionalMapsQuest or {Tier = 1}
	vars.dimensionalMapsQuest = q
	local level = TIERS[q.Tier]
	if not level then
		q.Done = true
		Message(TEXT_ALL_DONE)
		return
	end
	local m = q.Map
	if not m then
		if highestLevel() < level then
			Message(string.format(TEXT_TOO_LOW, level))
			return
		end
		m = rollQuestMap(q.Tier, level)
		q.Map = m
		giveMap(m)
		Message(string.format(TEXT_GIVE, Game.MapStats[m.BonusStrength].Name, m.Level))
		return
	end
	if not q.Cleared then
		Message(TEXT_NOT_CLEARED)
		return
	end
	local reward = q.Level*1000
	AddGoldExp(reward, reward)
	Message(string.format(TEXT_REWARD, q.MapName, reward))
	q.Tier = q.Tier + 1
	q.Map = nil
	q.Cleared = nil
	q.Level = nil
	q.MapName = nil
	if not TIERS[q.Tier] then
		q.Done = true
	end
end

function events.LoadMap()
	local q = vars.dimensionalMapsQuest
	if q and q.Map and not q.Cleared and mapvars.mapAffixes and not mapvars.completed then
		mapvars.dimensionalMapsTier = q.Tier
	end
end

function events.LeaveMap()
	local q = vars.dimensionalMapsQuest
	local affixes = mapvars.mapAffixes
	if not (q and q.Map) or q.Cleared or not mapvars.completed or not affixes or mapvars.dimensionalMapsTier ~= q.Tier then
		return
	end
	q.Cleared = true
	q.Level = getDimensionMapLevel(Map.MapStatsIndex, affixes.Power)
	q.MapName = Game.MapStats[Map.MapStatsIndex].Name
end

for npc, slot in pairs(ORACLES) do
	Quest{
		"DimensionalMaps" .. npc,
		BaseName = "DimensionalMaps",
		NPC = npc,
		Slot = slot,
		Ungive = dimensionalMapsTopic,
		Texts = {Topic = "차원 지도"},
	}
end
