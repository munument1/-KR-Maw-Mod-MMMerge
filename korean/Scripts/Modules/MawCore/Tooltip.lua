-- Tooltip.lua -- item tooltip section registry: ONE
-- BuildItemInformationBox handler running named sections in sort order
-- (sort keys mirror the old file load order; see the registrations at the
-- bottom). print(MawCore.Tooltip.describe()) lists them in-game.
--
-- Section fn(t) -> string appends to t.Description (bring your own "\n\n"),
-- or mutates t and returns nil, which is what most migrated bodies do.
--
-- Tooltip rendering knowledge (images, geometry, draw timing): GREENFIELD.md
-- par.6. The Structs handler in extraEditableDescriptions.lua stays raw and
-- still runs before every section.

local Tooltip = {}
MawCore.Tooltip = Tooltip

local Formulas = MawCore.Formulas

--Resistance enchants print as a %. The tooltip holds the RAW roll, so it has
--to be turned into stored power first -- a ring's counts half.
local function resistancePercent(roll, it)
	return Formulas.reductionPercent(Formulas.resistanceEnchantPower(roll, GetItemEquipStat(it)==10))
end

local sections = {}
local seq = 0

-- Tooltip.addSection("sockets", 500, fn) -- lower sort key = earlier in tooltip;
-- equal keys keep registration order.
function Tooltip.addSection(id, sort, fn)
	for _, s in ipairs(sections) do
		assert(s.id ~= id, ("tooltip: section %s already registered"):format(id))
	end
	seq = seq + 1
	sections[#sections + 1] = {id = id, sort = sort, seq = seq, fn = fn}
	table.sort(sections, function(a, b)
		if a.sort ~= b.sort then
			return a.sort < b.sort
		end
		return a.seq < b.seq
	end)
end

function Tooltip.remove(id)
	for i, s in ipairs(sections) do
		if s.id == id then
			table.remove(sections, i)
			return true
		end
	end
	return false
end

function Tooltip.describe()
	local out = {"tooltip sections:"}
	for _, s in ipairs(sections) do
		out[#out + 1] = ("  %4d %s"):format(s.sort, s.id)
	end
	if #sections == 0 then
		out[#out + 1] = "  (none)"
	end
	return table.concat(out, "\n")
end

function Tooltip.start()
	function events.BuildItemInformationBox(t)
		for _, s in ipairs(sections) do
			local text = s.fn(t)
			if text and t.Description then
				t.Description = t.Description .. text
			end
		end
	end
end


------------------------------------------------------------------------
-- Section bodies, verbatim from the legacy files named on each one; the
-- helpers they call are globals, so they run unchanged from here.
------------------------------------------------------------------------

-- was zzAlchemy.lua
local function tooltipPotions(t)
	local power=math.min(t.Item.Bonus, POTION_POWER_CAP)
	local text=potionText[t.Item.Number]
	if type(text)=="function" then
		text=text(power)
	end
	if text then
		t.Description=text--REMOVED .. "\n(To drink, pick the potion up and right-click over a character's portrait.  To mix, pick the potion up and right-click over another potion.)"
	elseif t.Item.Number>=264 and t.Item.Number<=299 then
		t.Description="이 물약은 제거되었습니다"
	end
	if t.Item.Number==222 then
		t.Description=StrColor(255,255,153,"생명력 회복: " .. GetPotionHeal(222, power) .. " 생명력") .. "\n" .. t.Description
	end
	if t.Item.Number==223 then
		t.Description=StrColor(255,255,153,"주문력 회복: " .. GetPotionHeal(223, power) .. " 주문력") .. "\n" .. t.Description
	end
	if t.Item.Number==232 then
		t.Description="명상 기술 보너스 +" .. StrColor(0,0,200,math.ceil(power^0.5/1.5) + 1) .. " (6시간)"
	end
	if t.Item.Number==247 then
		t.Description=StrColor(255,255,153,"생명력 회복: " .. GetPotionHeal(247, power) .. " 생명력") .. "\n" .. t.Description
	end
	if t.Item.Number==248 then
		t.Description=StrColor(255,255,153,"주문력 회복: " .. GetPotionHeal(248, power) .. " 주문력") .. "\n" .. t.Description
	end
	if t.Item.Number==TRANSCENDENCE_POTION then
		local index=Party[math.min(math.max(Game.CurrentPlayer, 0), Party.High)]:GetIndex()
		local reached=vars.mawTranscendence and vars.mawTranscendence[index] or 0
		t.Description=t.Description .. "\n\n기존에 적용된 최고 단계: " .. reached
			.. " (" .. GetTranscendenceSkillPoints(reached) .. " 기술 포인트)"
	end
		
	if table.find(potionUsingCharges,t.Item.Number) then
		local charges=t.Item.Charges-1
		if charges==-1 then
			charges=5
		end
		t.Description=StrColor(255,255,153,"충전 횟수: " .. charges) .. "\n\n" .. t.Description
	end
	
	if potionRecipeText[t.Item.Number] then
		if extraDescription then
			t.Description=t.Description .. "\n\n" .. potionRecipeText[t.Item.Number]
		else
			t.Description=t.Description .. StrColor(100,100,100,"\n\n조합법 목록을 보려면 Alt를 누르세요")
		end
	end
end

-- was zzAlchemy.lua
local function tooltipReagentPower(t)
	if reagentList[t.Item.Number] then
		local bonus=round(reagentList[t.Item.Number] *((t.Item.Bonus*0.25)/20+1)+t.Item.Bonus*0.75)
		t.Enchantment="위력: " .. bonus
	end
end

-- was zzAlchemy.lua
local function tooltipOrbsGems(t)
	if t.Item.Number>=1041 and t.Item.Number<=1060 then
		--[[
		if t.Name then
			if t.Item.BonusStrength==1 then
				t.Name=StrColor(178,255,255, "Ascended " .. t.Name) 
			end
		end
		]]
		if t.Description then
			local tier=t.Item.Number-1040
			local maxPower=GetGemCap(tier, 0, false)

			t.Description = "아이템의 마법부여 강도를 높이는 특수 보석입니다 (기본 마법부여가 있는 아이템을 우클릭하여 사용).\n최대 위력은 태고 아이템에 붙을 수 있는 최대 마법부여 강도이며, 보석 등급에 따라 달라집니다.\n\n인벤토리 화면에서 U 키를 누르면 보석 3개를 상위 등급 1개로 합성할 수 있습니다.\n보석은 " .. GEM_DROP_MAX_TIER .. "단계까지만 드롭됩니다. " .. GEM_DROP_MAX_TIER+1 .. "-" .. GEM_TIERS .. "단계는 U 키를 눌러 합성해야만 만들 수 있습니다.\n\n등급: " .. StrColor(255, 128, 0, tostring(tier))
			.. "\n최대 위력: " .. StrColor(255, 128, 0, tostring(maxPower))
			.. "\n보너스: " .. StrColor(255, 128, 0, tostring(GEM_STEP)) .. " (" .. GEM_STEP_SKILL .. " 기술 보너스)"
			.. "\n기술 최대 위력: " .. StrColor(255, 128, 0, tostring(GetGemCap(tier, 0, true)))
			.. "\n\n아이템 보정치:\n양손 무기: " .. StrColor(255, 128, 0, tostring(GetGemCap(tier, 1, false)))
			.. "\n갑옷: " .. StrColor(255, 128, 0, tostring(GetGemCap(tier, 3, false)))
			.. "\n투구-장화-장갑-활: " .. StrColor(255, 128, 0, tostring(GetGemCap(tier, 5, false)))
			.. "\n반지: " .. StrColor(255, 128, 0, tostring(GetGemCap(tier, 10, false)))
		end
	end
	if t.Item.Number==1067 then
		if t.Description then
			if t.Item.BonusStrength<10 or t.Item.BonusStrength>1000 then
				t.Description="오라클의 오브는 중심부에 섬뜩한 얼굴이 떠 있는 크고 보랏빛인 신비롭고 강력한 유물입니다. 이 수수께끼의 유물은 자신이 마법부여한 아이템에 전설 능력을 저장하는 것으로 알려져 있습니다.\n\n전설 아이템을 우클릭하면 그 능력을 저장합니다."
			else
				t.Description="오라클의 오브는 중심부에 섬뜩한 얼굴이 떠 있는 크고 보랏빛인 신비롭고 강력한 유물입니다. 이 수수께끼의 유물은 자신이 마법부여한 아이템에 전설 능력을 저장하는 것으로 알려져 있습니다.\n\n다음 전설 능력을 아이템에 부여합니다:"
			end
			t.Description = t.Description .. "\n\n" .. StrColor(255,255,30,legendaryEffects[t.Item.BonusStrength])
		end
	end
	if t.Item.Number==1068 then
		if t.Description then				
			t.Description="\n천상의 오브는 한 아이템의 천상 정수를 다른 아이템으로 옮겨, 신성한 속성을 보존하면서 원래 아이템에서 그 축복을 제거할 수 있습니다.\n\n(천상 아이템을 우클릭하면 힘을 추출해 천상의 오브를 충전하고, 이후 천상이 아닌 아이템을 우클릭하면 그 힘을 이전합니다.)"
			if t.Item.BonusStrength==1 then
				t.Description = t.Description .. "\n\n" .. StrColor(120, 240, 255,"천상 오브의 충전이 완료되어 유물이 아닌 장비에 천상의 힘을 부여할 준비가 되었습니다")
			end
		end
	end
	if t.Item.Number==1069 then
		if t.Description then				
			t.Description=t.Description .. StrColor(255,255,30, "\n\n충전 횟수 증가: " .. t.Item.BonusStrength)
		end
	end
end

-- was zzAlchemy.lua
local function tooltipCraftWithHeldItem(t)
	if Mouse.Item then
		UseItem(t.Item, Mouse.Item)
	end
end

-- was zzMaw-Items.lua
local function tooltipEnchantStats(t)
	if IsEnchantableItem(t.Item) then 

		local it=t.Item
		if t.Type then
			t.Type = t.Type
			
			updateCelestialItem(it)
			
			--add code to increase base stats based on bolster enchant
			--ARMORS
			if t.Item.MaxCharges>0 then
				local txt=Game.ItemsTxt[t.Item.Number]
				local equipStat=txt.EquipStat
				if equipStat>=3 and equipStat<=9 then
				local ac3=txt.Mod2+txt.Mod1DiceCount 
					if ac3>0 then
						local lookup=0
						while Game.ItemsTxt[t.Item.Number].NotIdentifiedName==Game.ItemsTxt[t.Item.Number+lookup+1].NotIdentifiedName do 
							lookup=lookup+1
						end
						local ac=Game.ItemsTxt[t.Item.Number].Mod2+Game.ItemsTxt[t.Item.Number].Mod1DiceCount 
						local ac2=Game.ItemsTxt[t.Item.Number+lookup].Mod2+Game.ItemsTxt[t.Item.Number+lookup].Mod1DiceCount 
						local maxCharges=t.Item.MaxCharges
						--[[
						if vars.insanityMode then
							maxCharges=math.ceil(maxCharges*4/3)
						end
						--]]
						local bonusAC=Formulas.chargesArmorAC(ac2, maxCharges)
						--if t.Item.MaxCharges <= 20 then
							ac=ac3+round(bonusAC)
						--else
						--	local bonusAC=(ac+ac2)*(t.Item.MaxCharges/20)
						--	ac=ac3+round(bonusAC)
						--end
						--same cube raise collectArmorAC applies to the character
						ac=round(ac*ItemQualityMult(t.Item))
						t.BasicStat= "방어력: +" .. ac .. MawQualityText(t.Item)
					end
				end
			end
			--WEAPONS (no charge gate: item-level damage shows on uncharged weapons too)
			do
				local txt=Game.ItemsTxt[t.Item.Number]
				local equipStat=txt.EquipStat
				if equipStat<=2 then
					--the rows addWeaponRows actually applies, artifacts included
					local bonus,lo,hi=GetWeaponDamageMinMax(t.Item)
					t.BasicStat= "공격: +" .. bonus .. "  피해: " .. lo .. "-" .. hi
						.. MawQualityText(t.Item)
				end
			end
			
			
			--add code to build enchant list
			t.Enchantment=""
			if t.Item.Bonus>0 then
				local power=t.Item.BonusStrength
				if t.Item.Bonus==8 or t.Item.Bonus==9 then
					local mult=GetSlotMult(it)
					power=round(power*(1+math.min(power/50/mult,5)))
				end
				if t.Item:T().EquipStat==5 and t.Item:T().Mod2==0 then
					power=math.ceil(power*1.5)
				end
				if t.Item.Bonus>=11 and t.Item.Bonus<=16 then
					local id=Game.CurrentPlayer
					if id>=0 and id<=Party.High then
						local index=Party[id]:GetIndex()
						if vars.legendaries and vars.legendaries[index] and table.find(vars.legendaries[index], 16) then
							power=power*1.5
						end
					end
					power=resistancePercent(power+10, t.Item) .. "%"
				end
				t.Enchantment = itemStatName[t.Item.Bonus] .. " +" .. power
			end
			if HasEnc2(t.Item) then
				local bonus,strength=GetEnc2(t.Item)
				if bonus==8 or bonus==9 then
					local mult=GetSlotMult(it)
					strength=round(strength*(1+math.min(strength/50/mult,5)))
				end
				if t.Item:T().EquipStat==5 and t.Item:T().Mod2==0 then
					strength=math.ceil(strength*1.5)
				end				
				if bonus>=11 and bonus<=16 then
					local id=Game.CurrentPlayer
					if id>=0 and id<=Party.High then
						local index=Party[id]:GetIndex()
						if vars.legendaries and vars.legendaries[index] and table.find(vars.legendaries[index], 16) then
							strength=strength*1.5
						end
					end
					strength=resistancePercent(strength+10, t.Item) .. "%"
				end
				if itemStatName[bonus] then
					t.Enchantment = itemStatName[bonus] .. " +" .. strength .. "\n" .. t.Enchantment
				end
			elseif t.Item.Bonus~=0 and t.Item.BonusStrength~=0 then
				if extraDescription then
					math.randomseed(t.Item.Number*10000+t.Item.MaxCharges*1000+t.Item.Bonus*100+t.Item.BonusStrength*10+t.Item.Charges)
					
					local mult=math.max((Game.BolsterAmount-100)/1000+1,1)
					local cap=100*mult
					local power=t.Item.BonusStrength
					if t.Item.Bonus==8 or t.Bonus==9 then
						power=math.floor((-100+(100^2+power*200)^0.5)/2)
					elseif t.Item.Bonus==10 then
						--power=power*1.5
					end
					local stat=RollEnchantType(t.Item, t.Item.Bonus)
					if stat==8 or stat==9 then
						GetSlotMult(t.Item)
						power=power*(1+math.min(power/50/mult,5))
					elseif stat==10 then
						--power=power*0.667
					end
					local slotMult=slotMult[t.Item:T().EquipStat] or 1
					cap=math.min(cap*slotMult,ENC2_MAX_STRENGTH)

					--was packed as stat*1000+strength and unpacked again on the
					--next line; the decimal round trip was what forced cap<=999
					local bonus=stat
					local strength=math.min(round(power*(1+0.25*math.random())),cap)
					if stat>=11 and stat<=16 then
						--second enchants grant the raw strength, no +10 (collectEnchant)
						strength=resistancePercent(strength, t.Item) .. "%"
					end
					txt=baseStatName[bonus] .. " +" .. strength .. "\n" .. t.Enchantment
					t.Enchantment = StrColor(100,100,100, txt)
					vars.extraShown=true
				end
			end
			if t.Item.Bonus==0 and t.Item.Bonus2==0 and not HasEnc2(t.Item) and extraDescription then
				if vars.enchantSeedList==nil then
				vars.enchantSeedList={}
					for i=0,2500 do
						vars.enchantSeedList[i]=math.random(1,100000)
					end
				end
				math.randomseed(vars.enchantSeedList[t.Item.Number]+t.Item.MaxCharges)
				if math.random(1,10)==1 then
					bonus=math.random(17,24)
				elseif GetItemEquipStat(t.Item)==10 then
					bonus=math.random(1,16)
				else
					bonus=math.random(1,10)
				end
				txt=baseStatName[bonus] .. " +X"
				t.Enchantment = StrColor(100,100,100, txt)
			end
		elseif t.Name then
			--add enchant Name
			t.Name = Game.ItemsTxt[t.Item.Number].Name
			if t.Item.Bonus2>0 then
				local enchString=Game.SpcItemsTxt[t.Item.Bonus2-1].NameAdd
				if string.match(enchString, "^%u") then
					t.Name= enchString .. " " .. t.Name
				else
					t.Name= t.Name .. " " .. enchString
				end
			elseif t.Item.Bonus>0 then
				t.Name= t.Name .. " " .. Game.StdItemsTxt[t.Item.Bonus-1].NameAdd
			end
			--choose colour
			local bonus=0
			if t.Item.Bonus>0 then
				bonus=bonus+1
			end
			if t.Item.Bonus2>0 then
				bonus=bonus+1
			end
			if HasEnc2(t.Item) then
				bonus=bonus+1
			end
			if IsCelestialItem(t.Item) then
				t.Name=StrColor(120, 240, 255,"천상의 " .. t.Name)
			elseif HasLegendaryAffix(t.Item) then
				t.Name=StrColor(255,255,30,"전설의 " .. t.Name)
			elseif IsPrimordialItem(t.Item) then
				t.Name=StrColor(255,0,0,"태고의 " .. t.Name)
			elseif IsAncientItem(t.Item) then
				t.Name=StrColor(255,128,0,"고대 " .. t.Name)
			elseif bonus==3 then
				t.Name=StrColor(163,53,238,t.Name)
			elseif bonus==2 then
				t.Name=StrColor(0,150,255,t.Name)
			elseif bonus==1 then
				t.Name=StrColor(30,255,0,t.Name)
			else
				t.Name=StrColor(255,255,255,t.Name)
			end
		elseif t.Description then
			if HasLegendaryAffix(t.Item) then
				t.Description=""
			end
			local legAffix=GetLegendaryAffix(t.Item)
			if legendaryEffects[legAffix] then
				local legText=legendaryEffects[legAffix]
				if legAffix==21 then
					local count=0
					for i=0, Map.Monsters.High do
						if Map.Monsters[i].Active then
							local dist=getDistanceToMonster(Map.Monsters[i])
							if dist<=512 then
								count=count+1
							end
						end
					end
					local dmg=math.min(count*5,100)
					legText=legText .. "\n현재 추가 피해: " .. dmg .. "%"
				elseif legAffix==22 then
					local count=0
					for i=0, Map.Monsters.High do
						if Map.Monsters[i].Active then
							local dist=getDistanceToMonster(Map.Monsters[i])
							if dist<=512 then
								count=count+1
							end
						end
					end
					local red=round(math.min(1-0.97^count,0.5)*10000)/100
					legText=legText .. "\n현재 피해 감소: " .. red .. "%"
				end
				t.Description = StrColor(255,255,30,legText) .. t.Description
			end
			if t.Item.Bonus2>0 then	
				if (t.Item.MaxCharges>=0 and bonusEffects[t.Item.Bonus2]~= nil) or enchantList[t.Item.Bonus2] then
					text=checktext(t.Item.MaxCharges,t.Item.Bonus2,t.Item)
				else
					text=Game.SpcItemsTxt[t.Item.Bonus2-1].BonusStat
				end
				t.Description = StrColor(255,255,153,text) .. "\n\n" .. t.Description
			end
			if t.Item.Bonus>0 and t.Item.Bonus2==0 and extraDescription then
				local n, c, power, totB2, roll, tot, enchantNumber
				n=t.Item.Number
				c=Game.ItemsTxt[n].EquipStat
				math.randomseed(t.Item.Number*10000+t.Item.MaxCharges*1000+t.Item.Bonus*100+t.Item.BonusStrength*10+t.Item.Charges)
				if c<12 then
					power=6
					totB2=itemStrength[power][c]
					roll=math.random(1,totB2)
					tot=0
					--must stay identical to the apply step in zzAlchemy.lua: this is
					--the promise, that is the delivery, and they share the seed
					for i=0,Game.SpcItemsTxt.High do
						if table.find(enchants[power], Game.SpcItemsTxt[i].Lvl) then
							tot=tot+Game.SpcItemsTxt[i].ChanceForSlot[c]
							if roll<=tot then
								enchantNumber=i+1	--1-based, like Bonus2
								goto continue
							end
						end
					end
				end
				:: continue ::
				if (t.Item.MaxCharges>=0 and bonusEffects[enchantNumber]~= nil) or enchantList[enchantNumber] then
					text=checktext(t.Item.MaxCharges,enchantNumber,t.Item)
				else
					text=Game.SpcItemsTxt[enchantNumber-1].BonusStat
				end
				t.Description = StrColor(100,100,100,text) .. "\n\n" .. t.Description
				vars.extraShown=true
			end
			if t.Item.Bonus>0 and t.Item.BonusStrength>0 then
				if not extraDescription and not vars.extraShown then
					t.Description = t.Description .. "\n\n" .. StrColor(100,100,100,"제작 가능한 능력치를 보려면 Alt를 누르세요")
				end
			end
		end
		if extraDescription and t.Description then
			local txt="\n\n아이템 보너스 위력: " .. t.Item.MaxCharges .. "/" .. GetItemChargesCap(t.Item)
			t.Description =t.Description .. StrColor(100,100,100, txt)
		end
	end
end

-- was zzMaw-Items.lua
local function signed(value)
	if value < 0 then
		return StrColor(255, 64, 64, tostring(value))
	end
	return "+" .. value
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	return keys
end

local function tooltipArtifactScaling(t)
	if not (t.Description and IsArtifactItem(t.Item)) then
		return
	end
	local bonuses = MawCore.Artifacts.BonusesOf(t.Item)
	local cut = t.Description:find("%(Special")
	if cut then
		t.Description = t.Description:sub(1, cut - 1)
	end
	if t.Description:sub(1, 1) == "(" then
		local close = t.Description:find(")", 1, true)
		if close then
			t.Description = t.Description:sub(close + 1):gsub("^%s+", "")
		end
	end
	local lines = {}
	for _, stat in ipairs(sortedKeys(bonuses.Stats)) do
		local name = itemStatName and itemStatName[stat + 1]
		if name then
			lines[#lines + 1] = name .. ": " .. signed(bonuses.Stats[stat])
		end
	end
	for _, skill in ipairs(sortedKeys(bonuses.Skills)) do
		local name = Game.SkillNames[skill]
		if name then
			lines[#lines + 1] = StrColor(255, 255, 153, name .. " 기술")
				.. ": " .. signed(bonuses.Skills[skill])
		end
	end
	if MawArtifactOnHitText then
		for _, line in ipairs(MawArtifactOnHitText(t.Item) or {}) do
			lines[#lines + 1] = StrColor(255, 170, 60, line)
		end
	end
	if #lines > 0 then
		t.Description = t.Description .. "\n\n" .. table.concat(lines, "\n")
	end
	t.Description = t.Description .. StrColor(120, 240, 255,
		"\n\n유물 레벨: " .. round(MawCore.Artifacts.LevelOf(t.Item)))
end

-- was zzMaw-Items.lua
local function tooltipArtifactBaseStats(t)
	if IsArtifactId(t.Item.Number) or table.find(ancientWeapons,t.Item.Number) then 
		if t.Type then
			local id=Game.CurrentPlayer
			if id==-1 then
				id=0
			end
			local txt=Game.ItemsTxt[t.Item.Number]

			if (txt.Skill>=8 and txt.Skill<=11) or txt.Skill==40 then
				local power=MawCore.ItemLevel.PowerFor(MawCore.Artifacts.LevelOf(t.Item))
				local ac=txt.Mod2+txt.Mod1DiceCount
				ac=ac+round(MawCore.Formulas.chargesArmorAC(referenceAC[t.Item.Number] or ac, power))
				ac=math.ceil(ac*MawCore.Artifacts.BaseMult(t.Item))
				ac=round(ac*ItemQualityMult(t.Item))
				if ac>0 then
					t.BasicStat= "방어력: +" .. ac .. MawQualityText(t.Item)
				end
			end
			if txt.EquipStat<=2 then
				local bonus,lo,hi=GetWeaponDamageMinMax(t.Item)
				t.BasicStat= "공격: +" .. bonus .. "  피해: " .. lo .. "-" .. hi
					.. MawQualityText(t.Item)
			end
			local skill=t.Item:T().Skill
			if table.find(twoHandedAxes, t.Item.Number) or table.find(oneHandedAxes, t.Item.Number) then
				skill=3
			end
			if baseRecovery[skill] then
				local pl=Party[0]
				local id=Game.CurrentPlayer
				if id>0 and id<Party.High then
					pl=Party[id]
				end
				local playerLevel=pl.LevelBase
				t.Type = t.Type .. "\n공격 속도: " .. getItemRecovery(t.Item, playerLevel)/100
			end
		end
	end
end

-- was zzMaw-Items.lua
local function tooltipStatCompare(t)
	--partyLevel=getPartyLevel()
	--maxItemBolster=(partyLevel)/5+20
	--failsafe
	--if Game.freeProgression and t.Item and t.Item.Charges==0 and t.Item.Bonus==0 and t.Item.Bonus2==0 and t.Item.MaxCharges>maxItemBolster then
	--	if not Game.freeProgression then
	--		maxItemBolster=maxItemBolster+10
	--	end
	--	t.Item.MaxCharges=round(partyLevel/5)
	--end
	if t.Description then
		local i=Game.CurrentPlayer
		if i==-1 or i>Party.High then return end
		local equipStat=t.Item:T().EquipStat
		if equipStat<=11 then 
			local pl=Party[i]
			local hp=pl.HP
			local sp=pl.SP
			local maxHP=vars.currentHPPool[i]
			local maxSP=vars.currentManaPool[i]
			local playerIndex=pl:GetIndex()
			local oldDPS1, oldDPS2, oldDPS3, oldVitality=calcPowerVitality(pl)
			--substitute item
			local slot=slotMap[equipStat]
			local itemBackup={}
			local it=pl:GetActiveItem(slot)
			if it then
				--backup item
				itemBackup["BodyLocation"]=it.BodyLocation
				itemBackup["Bonus"]=it.Bonus
				itemBackup["Bonus2"]=it.Bonus2
				itemBackup["BonusExpireTime"]=it.BonusExpireTime
				itemBackup["BonusStrength"]=it.BonusStrength
				itemBackup["Broken"]=it.Broken
				itemBackup["Charges"]=it.Charges
				itemBackup["Condition"]=it.Condition
				itemBackup["Hardened"]=it.Hardened
				itemBackup["Identified"]=it.Identified
				itemBackup["MaxCharges"]=it.MaxCharges
				itemBackup["Number"]=it.Number
				itemBackup["Owner"]=it.Owner
				itemBackup["Refundable"]=it.Refundable
				itemBackup["Stolen"]=it.Stolen
				itemBackup["TemporaryBonus"]=it.TemporaryBonus
				
				--substitute item
				it.BodyLocation=t.Item.BodyLocation
				it.Bonus=t.Item.Bonus
				it.Bonus2=t.Item.Bonus2
				it.BonusExpireTime=t.Item.BonusExpireTime
				it.BonusStrength=t.Item.BonusStrength
				it.Broken=t.Item.Broken
				it.Charges=t.Item.Charges
				it.Condition=t.Item.Condition
				it.Hardened=t.Item.Hardened
				it.Identified=t.Item.Identified
				it.MaxCharges=t.Item.MaxCharges
				it.Number=t.Item.Number
				it.Owner=t.Item.Owner
				it.Refundable=t.Item.Refundable
				it.Stolen=t.Item.Stolen
				it.TemporaryBonus=t.Item.TemporaryBonus
			else
				return
			end
			mawRefresh(playerIndex)
			mawRefresh(playerIndex)
			
			local newDPS1, newDPS2, newDPS3, newVitality=calcPowerVitality(pl)
			local increaseDPSPercent=round(math.max(newDPS1, newDPS2, newDPS3)/math.max(oldDPS1, oldDPS2, oldDPS3)*10000-10000)/100
			local increaseVitalityPercent=round(newVitality/oldVitality*10000-10000)/100
			if increaseDPSPercent<0 then
				t.Description = t.Description .. "\n\n" .. "위력: " .. StrColor(255,0,0,increaseDPSPercent .. "%")
			elseif increaseDPSPercent>0 then
				t.Description = t.Description .. "\n\n" .. "위력: " .. StrColor(0,255,0,"+" .. increaseDPSPercent .. "%")
			end
			if increaseVitalityPercent<0 then
				t.Description = t.Description .. "\n" .. "활력: " .. StrColor(255,0,0, increaseVitalityPercent .. "%")
			elseif increaseVitalityPercent>0 then
				t.Description = t.Description .. "\n" .. "활력: " .. StrColor(0,255,0,"+" .. increaseVitalityPercent .. "%")
			end
			--restore item
			it.BodyLocation=itemBackup["BodyLocation"]
			it.Bonus=itemBackup["Bonus"]
			it.Bonus2=itemBackup["Bonus2"]
			it.BonusExpireTime=itemBackup["BonusExpireTime"]
			it.BonusStrength=itemBackup["BonusStrength"]
			it.Broken=itemBackup["Broken"]
			it.Charges=itemBackup["Charges"]
			it.Condition=itemBackup["Condition"]
			it.Hardened=itemBackup["Hardened"]
			it.Identified=itemBackup["Identified"]
			it.MaxCharges=itemBackup["MaxCharges"]
			it.Number=itemBackup["Number"]
			it.Owner=itemBackup["Owner"]
			it.Refundable=itemBackup["Refundable"]
			it.Stolen=itemBackup["Stolen"]
			it.TemporaryBonus=itemBackup["TemporaryBonus"]
			mawRefresh(playerIndex)
			mawRefresh(playerIndex)
			--restore hp
			pl.HP=hp
			pl.SP=sp
			if GetLegendaryAffix(t.Item)==32 then
				buffManaLock()
			end
			vars.currentHPPool[i]=maxHP
			vars.currentManaPool[i]=maxSP
		end
	end
end

-- was zzMaw-Items.lua
local function tooltipLevelRequirement(t)
	if IsEnchantableItem(t.Item) then 
		if t.Description then
			
			local levelRequired=GetLevelRquirement(t.Item)
			local txt="\n\n요구 레벨: " .. levelRequired 
			local id=Game.CurrentPlayer
			if id<0 or id>Party.High then
				id=0
			end
			local plLvl=Party[id].LevelBase
			if plLvl<levelRequired then
				txt=StrColor(255,0,0,txt)
			end
			if IsCelestialItem(t.Item) then
				txt=StrColor(120, 240, 255,"\n\n천상 아이템은 제작용 보석이나 큐브로 강화할 수 없지만, 플레이어 레벨에 따라 성장하며 최대 600레벨까지 적용됩니다.")
				if vars.madnessMode then
					txt=StrColor(120, 240, 255,"\n\n천상 아이템은 제작용 보석이나 큐브로 강화할 수 없지만, 플레이어 레벨에 따라 성장하며 최대 1000레벨까지 적용됩니다.")
				end
			end
			t.Description = t.Description .. txt
			
		end	
		
		--attack speed tooltip
		local skill=t.Item:T().Skill
		if table.find(twoHandedAxes, t.Item.Number) or table.find(oneHandedAxes, t.Item.Number) then
			skill=3
		end
		if t.Type and baseRecovery[skill] then
			t.Type = t.Type .. "\n공격 속도: " .. getItemRecovery(t.Item, 0)/100
		end
	end
end

-- was zzMaw-Items.lua
local function tooltipFireAura(t)
	if t.Item:T().EquipStat==0 or t.Item:T().EquipStat==1 or t.Item:T().EquipStat==2 then 
		if t.Description then
			if vars.MAWSETTINGS.buffRework=="ON" and vars.mawbuff[4] then --fire aura
				if Game.CurrentPlayer>=0 and Game.CurrentPlayer<=Party.High then
					local pl=Party[Game.CurrentPlayer]
					local s, m, level=getBuffSkill(4)
					if m>=1 then
						local name={"Fire","Flame","Inferno","Hell",[0]=""}
						local damage=calcFireAuraDamage(pl, t.Item, 0, false, false, "tooltip")
						if damage then
							local txt=string.format(name[m] .. " 오라: 모든 공격에 " .. damage .. " 화염 피해 추가\n\n")
							t.Description=StrColor(255,255,153,txt) .. t.Description
						end
					end
				end
			end
			if vars.MAWSETTINGS.buffRework=="ON" and vars.mawbuff[91] then --vampiric aura
				local s, m, level=getBuffSkill(91)
				if m>=1 then
					t.Description=StrColor(255,255,153,"흡혈 오라: 가한 피해에 따라 플레이어의 생명력이 회복됩니다.\n\n") .. t.Description
				end
			end
		end
	end
end

-- was zzMaw-Maps.lua
local function tooltipMapLevel(t)
	local it=t.Item
	if it.Number==290 and t.Enchantment then
		local baseMap=mapLevels[Game.MapStats[it.BonusStrength].Name]
		local baseLevel=round((baseMap.Low+baseMap.Mid+baseMap.High)/3)
		t.Enchantment="지도 레벨: " .. it.MaxCharges*10+20+baseLevel
		local power=0
		if it.Bonus==0 then
			if it.BonusExpireTime>0 then
				power=power+1
			end
			if it.Bonus2>0 then
				power=power+1
			end
			if it.Charges>0 then
				power=power+1
				if it.Charges>=1000 then
					power=power+1
				end
			end
		else
			power=it.Bonus
		end
		t.Enchantment=t.Enchantment .. StrColor(0, 127, 255,"\n+" .. round((it.MaxCharges*power+power*20)/8*1.5) .. "% 제작 재료 드롭 확률 "  .. "\n+" .. round((it.MaxCharges*power+power*20)/4) .. "% 아이템 품질 " .. "%\n+" .. round((it.MaxCharges*power+power*20)/3) .. "% 몬스터 밀도")	
	end
	if it.Number==290 and t.Name then
		t.Name=Game.MapStats[it.BonusStrength].Name .. " 지도"
	end
	
	if it.Number==290 and t.Description then
		local power=it.MaxCharges
		local mapAffixes={
			[0]="",
			[1]="몬스터가 " .. getMapAffixPower(1, power) .. "% 증가한 피해를 줌",
			[2]="몬스터: " .. getMapAffixPower(2, power) .. "% 치명타 확률",
			[3]="몬스터: " .. getMapAffixPower(3, power) .. "% 확률로 화염구 시전",
			[4]="몬스터: " .. getMapAffixPower(4, power) .. "% 확률로 드래곤 브레스 시전",
			[5]="몬스터가 " .. getMapAffixPower(5, power) .. "%의 물리 피해를 반사",
			[6]="몬스터가 " .. getMapAffixPower(6, power) .. "%의 마법 피해를 반사",
			[7]="몬스터가 초당 " .. getMapAffixPower(7, power) .. "% 생명력 재생",
			[8]="몬스터: " .. getMapAffixPower(8, power) .. "% 확률로 상태 저항 무시",
			[9]="몬스터: " .. getMapAffixPower(9, power) .. "% 확률로 사망 시 몬스터 소환",
			[10]="몬스터가 " .. getMapAffixPower(10, power) .. "%의 플레이어 생명력을 피해로 줌",
			[11]="몬스터: " .. getMapAffixPower(11, power) .. "% 이동 속도 증가",
			[12]="몬스터 저항 증가: " .. getMapAffixPower(12, power),
			[13]="몬스터: " .. getMapAffixPower(13, power) .. "% 추가 제어 효과 저항 확률",
			[14]="몬스터: " .. getMapAffixPower(14, power) .. "% 확률로 에너지 피해를 줌",
			[15]="몬스터: " .. getMapAffixPower(15, power) .. "% 생명력 증가",
			[16]="보스 밀도 증가: " .. getMapAffixPower(16, power) .. "%",
			[17]="몬스터: " .. getMapAffixPower(17, power) .. "% 확률로 더 높은 등급이 됨",
			[18]="보스: " .. getMapAffixPower(18, power) .. "% 생명력 및 피해 증가",
			[19]="몬스터: " .. getMapAffixPower(19, power) .. "% 확률로 보스가 됨",
			[20]="플레이어 치명타 확률 감소: " .. getMapAffixPower(20, power) .. "%",
			[21]="플레이어 치명타 피해 감소: " .. getMapAffixPower(21, power) .. "%",
			[22]="플레이어 생명력/주문력 재생 감소: " .. getMapAffixPower(22, power) .. "%",
			[23]="플레이어 물리 피해 감소: " .. getMapAffixPower(23, power) .. "%",
			[24]="플레이어 마법 피해 감소: " .. getMapAffixPower(24, power) .. "%",
			[25]="플레이어 이동 속도 감소: " .. getMapAffixPower(25, power) .. "%",
			[26]="플레이어 공격 속도 감소: " .. getMapAffixPower(26, power) .. "%",
			[27]="플레이어 주문 회복 속도 증가: " .. getMapAffixPower(27, power) .. "%",
			[28]="플레이어 방어력 감소: " .. getMapAffixPower(28, power) .. "%",
			[29]="플레이어 저항 감소: " .. getMapAffixPower(29, power) .. "%",
			[30]="플레이어는 " .. getMapAffixPower(30, power) .. "% 확률로 공격이 빗나감",
			[31]="치유량 감소: " .. getMapAffixPower(31, power) .. "%",
			[32]="흡수량 감소: " .. getMapAffixPower(32, power) .. "%",
			[33]="버프 효과 감소: " .. getMapAffixPower(33, power) .. "%",
		}
		
		local txt=""
		local bonus=it.Bonus
		if bonus==0 then
			bonus=4
		end
		if it.Charges>0 then
			if it.Charges>=1000 then
				if bonus>=4 then
					txt=StrColor(255,255,153,"- " .. mapAffixes[math.floor(it.Charges/1000)]) .. "\n\n" .. txt
				else
					txt=StrColor(100,100,100,"- " .. mapAffixes[math.floor(it.Charges/1000)]) .. "\n\n" .. txt
				end
			end
			if it.Charges%1000>0 then
				if bonus>=3 then
					txt=StrColor(255,255,153,"- " .. mapAffixes[it.Charges%1000]) .. "\n\n" .. txt
				else
					txt=StrColor(100,100,100,"- " .. mapAffixes[it.Charges%1000]) .. "\n\n" .. txt
				end
			end
		end
		if it.Bonus2>0 then
			if bonus>=2 then
				txt=StrColor(255,255,153,"- " .. mapAffixes[it.Bonus2]) .. "\n\n" .. txt
			else
				txt=StrColor(100,100,100,"- " .. mapAffixes[it.Bonus2]) .. "\n\n" .. txt
			end
		end
		if it.BonusExpireTime>0 then
			txt=StrColor(255,255,153,"- " .. mapAffixes[it.BonusExpireTime]) .. "\n\n" .. txt
		end
		t.Description="\n" .. txt .. "창조자의 모래시계와 공허의 눈으로 새 속성을 해금하고, 제작 큐브로 지도를 변경하며, 힘의 에메랄드로 지도 레벨을 높일 수 있습니다.\n이 지도를 사용하면 입구로 순간이동합니다."
	end
end

-- was zzMaw-MultiBag.lua, removes bag buttons
local function tooltipMultibagButtons(t)
	for i=1,5 do
		multibagButton[i].Active=false
		RunNextTick(function()
			multibagButton[i].Active=true
		end)
	end
end

-- was zzMaw-Spells.lua
local mastery={"Novice","Expert","Master","Grandmaster"}
local function tooltipSkillBooks(t)
	local it=t.Item
	if it.Number>=971 and it.Number<980 then
		local identify=Game.ItemsTxt[it.BonusStrength].IdRepSt
		local m=1
		if identify>=15 then
			m=4
		elseif identify>=10 then
			m=3
		elseif identify>=5 then
			m=2
		end
		local id=Game.CurrentPlayer
		if id<0 or id>Party.High then return end
		local pl=Party[Game.CurrentPlayer]
		local s2,m2=SplitSkill(pl.Skills[t.Item.Number-959])
		if m2>=m then
			it.Number=it.BonusStrength
		end
		if t.Description then
			local name=Skillz.getName(t.Item.Number-959)
			t.Description=t.Description .. StrColor(255,0,0, "\n\n이 책을 열려면 최소 " .. mastery[m] .. " 단계 이상의 " ..  name .. " 기술이 필요합니다")
		end
	end
end

Tooltip.addSection("alchemy-potions", 100, tooltipPotions)
Tooltip.addSection("alchemy-reagent-power", 110, tooltipReagentPower)
Tooltip.addSection("alchemy-orbs-gems", 120, tooltipOrbsGems)
Tooltip.addSection("alchemy-craft-with-held-item", 130, tooltipCraftWithHeldItem)
Tooltip.addSection("items-enchant-stats", 200, tooltipEnchantStats)
Tooltip.addSection("items-artifact-scaling", 210, tooltipArtifactScaling)
Tooltip.addSection("items-artifact-base-stats", 220, tooltipArtifactBaseStats)
Tooltip.addSection("items-stat-compare", 230, tooltipStatCompare)
Tooltip.addSection("items-level-requirement", 240, tooltipLevelRequirement)
Tooltip.addSection("items-fire-aura", 250, tooltipFireAura)
Tooltip.addSection("maps-map-level", 300, tooltipMapLevel)
Tooltip.addSection("multibag-buttons", 310, tooltipMultibagButtons)
Tooltip.addSection("spells-skill-books", 320, tooltipSkillBooks)