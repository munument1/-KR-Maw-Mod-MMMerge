--code to share promotions
--game ordered from mm6 to mm8, first promotion then honorary promotion qbits, mm7 has 4 qbits total
promotionList={
--Archer
[1]=		{1657,1658,		1586,1587,1588,1589,	1537,20},--dark elf 
--Cleric
[2]=		{1649,1650,		1609,1610,1611,1612,	1546,31},
--Dark Elf
[3]=	{1657,1658,		1586,1587,1588,1589,	1537,20},--archer
--Dragon
[4]=		{1645,1646,		1568,1569,1570,1571,	1543,1544},--knight 
--Druid
[5]= 		{1653,1654,		1615,1616,1617,1618,	1546,31},--cleric
--Knight
[6]=		{1645,1646,		1568,1569,1570,1571,	1540,1541},
--Minotaur
[7]=	{1637,1638,		1592,1593,1594,1595,	1545,29},--paladin
--Monk
[8]=		{1645,1646,		1574,1575,1576,1577,	1538,1539},--knight and troll
--Paladin
[9]=	{1637,1638,		1592,1593,1594,1595,	1545,29},--minotaur
--Ranger
[10]=		{1657,1658,		1580,1581,1582,1583,	1537,20},--archer, dark elf
--Thief
[11]=		{1657,1658,		1562,1563,1564,1565,	1547,33},--archer, vampire
--Troll
[12]=		{1645,1646,		1568,1569,1570,1571,	1538,1539},--knight and monk
--Vampire
[13]=	{1657,1658,		1562,1563,1564,1565,	1547,33},--archer, thief
--Sorcerer
[14]=	{1641,1642,		1621,1622,1623,1624,	1548,35},--necromancer
--Necromancer
[15]=	{1641,1642,		1621,1622,1623,1624,	1548,35},--sorcerer
--Peasant
[16]=	{0,0,		0,0,0,0,	0,0},
--Seraphim
[17]=	{1649,1650,		1609,1610,1611,1612,	1546,31},--cleric
--DK
[18]=	{1645,1646,		1568,1569,1570,1571,	1540,1541},--same as knight
--SHAMAN
[19]=	{1653,1654,		1615,1616,1617,1618,	1546,31}, --same as druid
--ELEMENTALIST
[20]=	{1641,1642,		1621,1622,1623,1624,	1548,35},--same as mage
}

--mid promotionlist
midPromo={
--Seraphim
[17]=	{1647,1648,		1607,1608},--cleric
--DK
[18]=	{1643,1644,		1566,1567},--same as knight
--SHAMAN
[19]=	{1651,1652,		1613,1614}, --same as druid
--ELEMENTALIST
[20]=	{1639,1640,		1619,1620},--same as mage
}

function events.GameInitialized2()
	oldNames={}
	oldHP={}
	oldSP={}
	for i=0,Game.ClassNames.High do
		oldNames[i]=Game.ClassNames[i]
		oldHP[i]=Game.Classes.HPFactor[i]
		oldSP[i]=Game.Classes.SPFactor[i]
	end
end

promotionCount={}
function checkPromo()
	for i= 0,Game.Classes.HPFactor.High do
		--extablish which class needs upgrade
		if Game.ClassesExtra[i].Step==2 then
			totalPromotions=0
			prom=promotionList[Game.ClassesExtra[i].Kind]
			if Party.QBits[prom[1]] or Party.QBits[prom[2]] then
				totalPromotions=totalPromotions+1
			end
			if Party.QBits[prom[3]] or Party.QBits[prom[4]] or Party.QBits[prom[5]] or Party.QBits[prom[6]] then
				totalPromotions=totalPromotions+1
			end
			if prom[8]<105 then
				check=Party[0].Awards[prom[8]]
			else
				check=Party.QBits[prom[8]]
			end
			if Party.QBits[prom[7]] or check then
				totalPromotions=totalPromotions+1
			end
			promotionCount[Game.ClassesExtra[i].Kind]=totalPromotions
			--upgrade class
			if totalPromotions>1 then
				Game.Classes.HPFactor[i]=oldHP[i]*(0.75+0.25*totalPromotions)
				Game.Classes.SPFactor[i]=oldSP[i]*(0.75+0.25*totalPromotions)
				if totalPromotions==2 then
					Game.ClassNames[i]=string.format("원로 " .. oldNames[i])
				else
					Game.ClassNames[i]=string.format("궁극의 " .. oldNames[i])
				end
			else
				Game.Classes.HPFactor[i]=oldHP[i]
				Game.Classes.SPFactor[i]=oldSP[i]
				Game.ClassNames[i]=oldNames[i]
			end
		end
	end
	--check promotion
	for i=0,Party.High do
		class=Party[i].Class
		kind=Game.ClassesExtra[class].Kind
		if promotionCount[kind] and promotionCount[kind]>=1 and Game.ClassesExtra[class].Step<2 then --check if promotion
			--search for available promotions
			promotionCount={}
			for v=0,#Game.ClassesExtra do
				if Game.ClassesExtra[v].Kind==kind and Game.ClassesExtra[v].Step==2 then
					table.insert(promotionCount, v)
				end
			end
			if #promotionCount==1 then
				Party[i].Class=promotionCount[1]
			elseif #promotionCount>1 then
				Party[i].Class=promotionCount[math.random(1,#promotionCount)]
			end
		end
	end 
	
	--mid promo
	for i=0,Party.High do
		class=Party[i].Class
		kind=Game.ClassesExtra[class].Kind
		if Game.ClassesExtra[class].Step==0 and midPromo[Game.ClassesExtra[class].Kind] then
			prom=midPromo[Game.ClassesExtra[class].Kind]
			for v=1,4 do
				if Party.QBits[prom[v]] then
					Party[i].Class=Party[i].Class+1
					goto continue
				end
			end
			::continue::
		end
	end
end


function events.LoadMap()
	checkPromo()
end

function events.EvtGlobal(i)
	checkPromo()
end


----------------------------------------------------------------------
--SERAPHIM
----------------------------------------------------------------------


function events.GameInitialized2()
	Game.ClassDescriptions[53]="세라핌은 신들의 축복을 받아 범인과는 다른 초월적인 힘을 지닌 신성한 전사입니다. 그의 기원은 수수께끼에 싸여 있지만, 인간계에서 신들의 뜻을 수행하도록 선택받았다고 전해집니다. 어떤 이는 인간과 천사의 사이에서 태어났다고 수군거리고, 또 어떤 이는 신들이 직접 창조했다고 믿습니다. 기원이 무엇이든 세라핌이 휘두르는 힘은 부정할 수 없으며, 전장에서 그의 존재는 신의 의지를 증명합니다.\n\n판금 갑옷, 검, 철퇴, 방패에 능숙함 (쌍수 사용 불가)\n레벨당 생명력 3, 마나 1 획득\n\n능력:\n\n신의 분노: 공격 시 빛 기술에 따라 추가 마법 피해를 줍니다 (빛과 정신 기술 포인트당 피해 +2)\n\n신성한 일격: 공격 시 육체 기술에 따라 파티에서 가장 부상당한 아군을 치유합니다 (육체와 영혼 기술 포인트당 2)\n\n신성한 보호: 치명적인 공격을 받을 때 최대 생명력의 25%를 회복합니다. 재사용 대기시간 5분."
end

--class ID
seraphClass={53,54,55}

--2h swords in 1h
function events.GameInitialized2()
	twoHandedSwords={}
	for i=1,Game.ItemsTxt.High do
		local it=Game.ItemsTxt[i]
		if it.Skill==1 and it.EquipStat==1 then
			table.insert(twoHandedSwords, i)
		end
	end
end
function events.Action(t)
	if t.Action==133 then
		local id=Game.CurrentPlayer
		if id<0 or id>Party.High then
			Game.CurrentPlayer=0
			id=0
		end
		local pl=Party[id]
		if table.find(seraphClass, pl.Class) then
			local it=Mouse.Item
			if it then
				local txt=it:T()
				local s,m=SplitSkill(pl.Skills[const.Skills.Sword])
				if txt.EquipStat==1 and txt.Skill==1 then
					txt.EquipStat=0
					pl.Skills[const.Skills.Sword]=JoinSkill(s,1)
					RunNextTick(function()
						pl.Skills[const.Skills.Sword]=JoinSkill(s,m)
						txt.EquipStat=1
					end)
				elseif txt.EquipStat==4 and txt.Skill==8 then
					local weapon=pl:GetActiveItem(1,true)
					if weapon then
						local txt=weapon:T()
						if txt.EquipStat==1 and txt.Skill==1 then
							txt.EquipStat=0
							RunNextTick(function()
								txt.EquipStat=1
							end)
						end
					end
				end
			end
			local weapon=pl:GetActiveItem(1,true)
			local shield=pl:GetActiveItem(0,true)
			if weapon and shield then
				local txt=weapon:T()
				if txt.EquipStat==1 and txt.Skill==1 then
					txt.EquipStat=0
					RunNextTick(function()
						txt.EquipStat=1
					end)
				end
			end
		end
	end
end
--body magic will increase healing done on attack
--bunch of code for healing most injured player
function indexof(table, value)
	for i, v in ipairs(table) do
			if v == value then
				return i
			end
		end
	return nil
end
		
function pickLowestPartyMember()
	-- Define the variables
	local a={}
	a[0]=2
	a[1]=2
	a[2]=2
	a[3]=2
	a[4]=2
	for i=0,Party.High do
		if Party[i].Dead==0 and Party[i].Eradicated==0 then
			a[i] = Party[i].HP/GetMaxHP(Party[i])
		end
	end
	local a, b, c, d, e= a[0], a[1], a[2], a[3], a[4] 
	-- Find the maximum value and its position
	local min_value = math.min(a, b, c, d, e)
	local min_index = indexof({a, b, c, d, e}, min_value)
	min_index = min_index - 1
	return min_index, min_value
end

function events.CalcDamageToMonster(t)
	if t.Result==0 then return end
	local data = WhoHitMonster()
		if data and data.Player and (data.Player.Class==55 or data.Player.Class==54 or data.Player.Class==53) and t.DamageKind==4 and data.Object==nil then
		local pl=data.Player
		local partyHP=0
		for i=0,Party.High do
			if Party[i].Dead==0 and Party[i].Eradicated==0 then
				partyHP=partyHP+Party[i].HP
			end
		end
		
		--get body
		bodyS,bodyM=SplitSkill(pl.Skills[const.Skills.Body])
		
		if bodyS==0 and spiritS==0 then return end
		
		--Calculate heal value and apply
		healValue=(bodyS^1.3*bodyM*2)*damageMultiplier[t.PlayerIndex]["Melee"]
		personality=pl:GetPersonality()
		healValue=round(healValue*(1+personality/1000))

		local healTarget, lowestHealthPercentage=pickLowestPartyMember()
		
		local percent, partyId, playerId=OnlineLowestHealthPercentage()
		
		if lowestHealthPercentage>0.25 and percent<lowestHealthPercentage then
			SendHeal(partyId, playerId, healValue, pl.Name)
			
			local hp=vars.online.partyHealthMana.Parties[partyId][playerId].HP
			local fhp=vars.online.partyHealthMana.Parties[partyId][playerId].FHP
			
			local healing=math.min(healValue, fhp-hp)
			
			local id=t.PlayerIndex
			vars.healingDone=vars.healingDone or {}
			vars.healingDone[id]=vars.healingDone[id] or 0
			vars.healingDone[id]=vars.healingDone[id] + healing
			mapvars.healingDone=mapvars.healingDone or {}
			mapvars.healingDone[id]=mapvars.healingDone[id] or 0
			mapvars.healingDone[id]=mapvars.healingDone[id] + healing
			return
		end
		
		--apply heal
		evt[healTarget].Add("HP",healValue)		
		--bug fix
		if Party[healTarget].HP>0 then
			Party[healTarget].Unconscious=0
		end
		local partyHP2=0
		for i=0,Party.High do
			if Party[i].Dead==0 and Party[i].Eradicated==0 then
				partyHP2=partyHP2+Party[i].HP
			end
		end
		if partyHP2>partyHP and (Party.EnemyDetectorRed or Party.EnemyDetectorYellow) then	
			local healing=partyHP2-partyHP
			local id=t.PlayerIndex
			vars.healingDone=vars.healingDone or {}
			vars.healingDone[id]=vars.healingDone[id] or 0
			vars.healingDone[id]=vars.healingDone[id] + healing
			mapvars.healingDone=mapvars.healingDone or {}
			mapvars.healingDone[id]=mapvars.healingDone[id] or 0
			mapvars.healingDone[id]=mapvars.healingDone[id] + healing
		end
	end
end

--[[mind light increases melee damage

function events.GameInitialized2()
	--damage from skills
	function events.CalcStatBonusByItems(t)
		if t.Stat==const.Stats.MeleeDamageMax or t.Stat==const.Stats.MeleeDamageMin then
			if t.Player.Class==55 or t.Player.Class==54 or t.Player.Class==53 then
				light=t.Player:GetSkill(const.Skills.Light)
				lightS,lightM=SplitSkill(light)
				--get mind
				mind=t.Player:GetSkill(const.Skills.Mind)
				mindS,mindM=SplitSkill(mind)
				levelBonus1=mindM+math.floor(t.Player.LevelBase/100)
				levelBonus2=lightM+math.floor(t.Player.LevelBase/100)
				damage=mindS*levelBonus1 + lightS*levelBonus2
				t.Result=t.Result+damage
			end
		end	
	end
end
MOVED IN MAW ITEMS, DUE TO WEAPON SCALING]]

--AUTORESS SKILL

function events.LoadMap(wasInGame)
	vars.divineProtectionCooldown=vars.divineProtectionCooldown or {}
	for i=0,Party.High do
		local index=Party[i]:GetIndex()
		vars.divineProtectionCooldown[index]=vars.divineProtectionCooldown[index] or 0
	end
end

---deactivate offhand weapon
function events.CalcDamageToMonster(t)
	if t.Player and (t.Player.Class==55 or t.Player.Class==54 or t.Player.Class==53) then
		data=WhoHitMonster()
		if data and data.Player then
			item=data.Player:GetActiveItem(0)
		end
		if item~=nil then
			if item:T().Skill==1 then
				t.Result=0
				Message("세라핌은 쌍수 무기를 사용할 수 없습니다")
			end
		end
	end
end

--skill tooltips
--tooltips
function events.GameInitialized2()
	baseSchoolsTxtSERAPH={
		[16]=Skillz.getDesc(16,1),
		[17]=Skillz.getDesc(17,1),
		[18]=Skillz.getDesc(18,1),
		[19]=Skillz.getDesc(19,1),
	}
end

local function seraphSkills(isSeraph, id)
	if isSeraph then
		pl=Party[id]
		
		local spiritS, spiritM=SplitSkill(pl.Skills[const.Skills.Spirit])
		local mindS, mindM=SplitSkill(pl.Skills[const.Skills.Mind])
		local bodyS, bodyM=SplitSkill(pl.Skills[const.Skills.Body])
		local lightS, lightM=SplitSkill(pl.Skills[const.Skills.Light])
				
		--heal tooltips
		local pers=pl:GetPersonality()
		local healMult=1+pers/1000
		
		local lvl=getTotalLevel()
		--local spiritReduction=round(getMonsterDamage(false,(lvl+1)^0.325*spiritS)^0.7)
		
		local _,_,_,avgRed=getPlayerEstimatedVitality(lvl+1)
		local spiritReduction=round(getMonsterDamage(false,(lvl+1))*(spiritS/lvl^0.65)/avgRed/2*0.99^(lvl^0.65)) --on average 1/2 of a B monster
		local txt = baseSchoolsTxtSERAPH[16] .. "\n\n세라프의 영혼은 세라프의 결의를 강화하여 가벼운 공격은 흘려내고 강한 공격의 피해를 줄입니다.\n" .. "피해 감소: " .. StrColor(0,255,0,spiritReduction) .. " (저항 적용 후 계산)\n"
		Skillz.setDesc(16,1,txt)
		
		local bodyHeal=0
		if damageMultiplier[pl:GetIndex()] then
			bodyHeal=round(bodyS^1.3*bodyM*damageMultiplier[pl:GetIndex()]["Melee"]*healMult*2)
		end
		local txt=baseSchoolsTxtSERAPH[18] .. "\n\n세라핌의 공격 시 회복량은 육체 마법에 따라 증가하고 인격에 비례합니다(무기 속도 배율이 적용됩니다).\n\n" .. "육체 마법으로 얻는 현재 회복량: " .. StrColor(0,255,0,bodyHeal) .. "\n"
		Skillz.setDesc(18,1,txt)
		
		--damage tooltip
		local mindDMG=mindS*mindM
		local lightDMG=lightS*lightM
		local txt=baseSchoolsTxtSERAPH[17] .. "\n\n세라핌의 공격 시 피해는 정신 마법에 따라 증가하고 힘에 비례합니다(무기 속도와 무기 피해 배율이 적용됩니다).\n\n" .. "정신 마법으로 얻는 현재 피해: " .. StrColor(255,0,0,mindDMG) .. "\n"
		Skillz.setDesc(17,1,txt)
		local txt = baseSchoolsTxtSERAPH[19]
		.. StrColor(255,255,30,"\n\n빛 마법은 세라핌의 공격을 가속하여 공격 속도를 높입니다.\n\n그 빛은 칼날을 매우 가볍게 만들어 양손검도 한 손으로 사용할 수 있게 하며, 다른 손에는 방패를 들 수 있습니다.\n")
		Skillz.setDesc(19,1,txt)
		
		--tooltips
		--Skillz.setDesc(16,2,"Melee attacks heal on hit")
		--Skillz.setDesc(16,3,"Double healing effect")
		--Skillz.setDesc(16,4,"Triple healing effect")
		--Skillz.setDesc(16,5,"n/a")
		
		Skillz.setDesc(17,2,"기술 포인트당 피해량이 2 증가합니다")
		Skillz.setDesc(17,3,"기술 포인트당 피해량이 3 증가합니다")
		Skillz.setDesc(17,4,"기술 포인트당 피해량이 4 증가합니다")
		Skillz.setDesc(17,5,"n/a")
		
		Skillz.setDesc(18,2,"근접 공격 적중 시 생명력을 회복합니다")
		Skillz.setDesc(18,3,"회복 효과가 2배가 됩니다")
		Skillz.setDesc(18,4,"회복 효과가 3배가 됩니다")
		Skillz.setDesc(18,5,"n/a")
		
		Skillz.setDesc(19,2,"기술 포인트당 공격 속도가 1% 증가합니다")
		Skillz.setDesc(19,3,"기술 포인트당 공격 속도가 2% 증가합니다")
		Skillz.setDesc(19,4,"기술 포인트당 공격 속도가 3% 증가합니다")
		Skillz.setDesc(19,5,"기술 포인트당 공격 속도가 4% 증가합니다")
	else
		for key, value in pairs(baseSchoolsTxtSERAPH) do
			Skillz.setDesc(key,1,value .. "\n")
			Skillz.setDesc(key,2,"효과는 주문마다 다릅니다")
			Skillz.setDesc(key,3,"효과는 주문마다 다릅니다")
			Skillz.setDesc(key,4,"효과는 주문마다 다릅니다")
		end
		Skillz.setDesc(19,5,"효과는 주문마다 다릅니다")
	end
end







----------------------------------
-- DRAGON REWORK
----------------------------------
local dragonFang={
	["Attack"]={2,3,4,5,[0]=0},
	["Damage"]={4,6,8,10,[0]=0},
	--["Speed"]={0,0,1,2,[0]=0},
}
local dragonBreath={
	--["Attack"]={0,0,0,0,[0]=0},
	["Damage"]={3,4,5,6,[0]=0},
	--["Speed"]={0,0,1,1,[0]=0},
}
local dragonScales={
	["AC"]={2,3,3,4,[0]=0},
	["Resistances"]={1,1,2,3,[0]=0},
}

function events.GameInitialized2()
	--fire blast tooltip
	Game.SpellsTxt[123].Description="이 능력은 일반적인 용의 숨결 공격의 강화 버전입니다. 화염구와 비슷하게 작동하여 대상을 타격하고 폭발하여 근처의 모든 것을 공격하지만, 폭발 피해량은 대부분의 화염구보다 훨씬 강력합니다."
	Game.SpellsTxt[123].Expert="숨결 피해의 70%만큼 피해"
	Game.SpellsTxt[123].Master="숨결 피해의 85%만큼 피해"
	Game.SpellsTxt[123].GM="숨결 피해의 100%만큼 피해"
	--mana cost
	Game.Spells[123].SpellPointsNormal=25
	Game.Spells[123].SpellPointsExpert=40
	Game.Spells[123].SpellPointsMaster=50
	Game.Spells[123].SpellPointsGM=60
	
	Game.Classes.SPBase[10]=60
	Game.Classes.SPFactor[10]=0
	Game.Classes.SPStats[10]=3
	Game.Classes.SPBase[11]=120
	Game.Classes.SPFactor[11]=0
	Game.Classes.SPStats[11]=3
	
	Skillz.setDesc(23,1,"드래곤은 타고난 능력을 지닌 강력한 생물입니다.\n다크 엘프와 뱀파이어의 종족 능력처럼 드래곤 능력은 주문처럼 사용하지만 기술처럼 습득합니다. 드래곤은 처음부터 공포를 사용할 수 있고, 전문가·마스터·그랜드마스터 단계에서 두 번째 브레스 무기, 비행, 윙 버핏을 차례로 얻습니다.\n\n브레스 피해는 레벨당 20 + 2이며(최대 600레벨, 광기에서는 900레벨), 총 피해 증가율은 " .. dragonBreath.Damage[1] .. "-" .. dragonBreath.Damage[2] .. "-" .. dragonBreath.Damage[3] .. "-" .. dragonBreath.Damage[4] .. "%씩 증가합니다(드래곤 능력 기술의 초보, 전문가, 마스터, 그랜드마스터 단계에서 기술 포인트당).\n기술 포인트마다 피해가 증가하고 회복 시간이 3% 증가합니다."  )
	
	function events.CalcStatBonusByItems(t)
		if Game.CharacterPortraits[t.Player.Face].Race~=const.Race.Dragon then return end
		--melee
		if t.Stat==27 then --min damage
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.Unarmed)) 
			local might=t.Player:GetMight()
			if might>=25 then
				mightEffect=math.floor(might/5)
			else
				mightEffect=math.floor((might-13)/2)
			end
			local bolster=getPartyLevel(4)+1
			local lvl=pl.LevelBase
			if pl.LevelBase/bolster>1.2 then
				lvl=math.min(pl.LevelBase/2,bolster)
			end
			local cap=600
			if vars.madnessMode then
				cap=900
			end
			local speedDelay=0.015
			local bonus= (1 + (dragonFang.Damage[m]) * s / 100)  * (math.min(lvl,cap) * 2 +30) 
			t.Result=round((bonus*(1+might/1000)+(mightEffect*might/1000))*0.75*(1+s*speedDelay))
			
		elseif t.Stat==28 then --max damage
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.Unarmed)) 
			local might=t.Player:GetMight()
			if might>=25 then
				mightEffect=math.floor(might/5)
			else
				mightEffect=math.floor((might-13)/2)
			end
			
			
			local bolster=getPartyLevel(4)+1
			local lvl=pl.LevelBase
			if pl.LevelBase/bolster>1.2 then
				lvl=math.min(pl.LevelBase/2,bolster)
			end
			local cap=600
			if vars.madnessMode then
				cap=900
			end
			local bonus= (1 + (dragonFang.Damage[m]) * s / 100)  * (math.min(lvl,cap) * 2 +30)
			
			local speedDelay=0.015
			t.Result=round((bonus*(1+might/1000)+(mightEffect*might/1000))*1.25*(1+s*speedDelay))
			
		elseif t.Stat==25 then --attack
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.Unarmed))
			local bonus= (dragonFang.Attack[m]) * s +10
			t.Result=t.Result+bonus 
			
		end
		--breath
		if t.Stat==31 then --min damage
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.DragonAbility))
			local might=t.Player:GetMight()
			local mightEffect
			if might>=25 then
				mightEffect=math.floor(might/5)
			else
				mightEffect=math.floor((might-13)/2)
			end
			
			local bolster=getPartyLevel(4)+1
			local lvl=pl.LevelBase
			if pl.LevelBase/bolster>1.2 then
				lvl=math.min(pl.LevelBase/2,bolster)
			end
			local cap=600
			if vars.madnessMode then
				cap=900
			end
			local speedDelay=0.015
			local baseDamage=(1 + dragonBreath.Damage[m] * s / 100) * (20 + 2 * math.min(lvl,cap)) + mightEffect
			local damage=round(baseDamage*(1+might/1000)*0.75*(1+s*speedDelay))
			
			t.Result=damage
			
		elseif t.Stat==32 then --max damage
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.DragonAbility))
			local might=t.Player:GetMight()
			local mightEffect
			if might>=25 then
				mightEffect=math.floor(might/5)
			else
				mightEffect=math.floor((might-13)/2)
			end
			
			local bolster=getPartyLevel(4)+1
			local lvl=pl.LevelBase
			if pl.LevelBase/bolster>1.2 then
				lvl=math.min(pl.LevelBase/2,bolster)
			end
			
			local cap=600
			if vars.madnessMode then
				cap=900
			end
			local speedDelay=0.015
			local baseDamage=(1 + dragonBreath.Damage[m] * s / 100) * (20 + 2 * math.min(lvl,cap)) + mightEffect
			local damage=round(baseDamage*(1+might/1000)*1.25*(1+s*speedDelay))
			
			t.Result=damage
		
		--AC
		elseif t.Stat==9 then
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.Dodging))
			local oldDodge=skillAC[const.Skills.Dodging][m] or 0
			
			local bolster=getPartyLevel(4)+1
			local lvl=pl.LevelBase
			if pl.LevelBase/bolster>1.2 then
				lvl=math.min(pl.LevelBase/2,bolster)
			end
			local cap=600
			if vars.madnessMode then
				cap=900
			end
			local bonus= (1 + dragonScales.AC[m]/100 * s) * (math.min(lvl,cap)+40) - (s * oldDodge)
			t.Result=t.Result+bonus
		elseif t.Stat>=10 and t.Stat<=15 then
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.Dodging))
			local oldDodge=skillAC[const.Skills.Dodging][m] or 0
			
			local bolster=getPartyLevel(4)+1
			local lvl=pl.LevelBase
			if pl.LevelBase/bolster>1.2 then
				lvl=math.min(pl.LevelBase/2,bolster)
			end
			local cap=600
			if vars.madnessMode then
				cap=900
			end
			local bonus= (dragonScales.AC[m]/100 * s) * (math.min(lvl,cap)+40)
			t.Result=t.Result+bonus
		end
		
		--no mana from items
		if t.Stat==const.Stats.SpellPoints then
			t.Result=0
		end
	end
	
	function events.GetAttackDelay(t)
		if Game.CharacterPortraits[t.Player.Face].Race==const.Race.Dragon then
			if useBreathCooldown or t.Ranged then
				local s, m = SplitSkill(t.Player:GetSkill(const.Skills.DragonAbility))
				t.Result=t.Result * (1+0.015*s)
				useBreathCooldown=false
			else
				local s, m = SplitSkill(t.Player:GetSkill(const.Skills.Unarmed))
				t.Result=t.Result * (1+0.015*s)
			end
		end	
	end
	function events.PlaySound(t)
		if t.Sound==18080 then
			useBreathCooldown=true
		end
	end
	--skill text
	normal=""
	normal=string.format("%s      %s|",normal,dragonFang.Attack[1])
	--normal=string.format("%s      %s|",normal,dragonFang.Speed[1])
	normal=string.format("%s     %s|",normal,dragonFang.Damage[1])
	fangsNormal=normal
	normal=""
	normal=string.format("%s  %s|",normal,dragonScales.AC[1])
	normal=string.format("%s    %s",normal,dragonScales.Resistances[1])
	scalesNormal=normal
	
	expert=""
	expert=string.format("%s      %s|",expert,dragonFang.Attack[2])
	--expert=string.format("%s      %s|",expert,dragonFang.Speed[2])
	expert=string.format("%s     %s|",expert,dragonFang.Damage[2])
	fangsExpert=expert
	expert=""
	expert=string.format("%s  %s|",expert,dragonScales.AC[2])
	expert=string.format("%s    %s",expert,dragonScales.Resistances[2])
	scalesExpert=expert
	
	master=""
	master=string.format("%s      %s|",master,dragonFang.Attack[3])
	--master=string.format("%s      %s|",master,dragonFang.Speed[3])
	master=string.format("%s     %s|",master,dragonFang.Damage[3])
	fangsMaster=master
	master=""
	master=string.format("%s  %s|",master,dragonScales.AC[3])
	master=string.format("%s    %s",master,dragonScales.Resistances[3])
	scalesMaster=master
	
	gm=""
	gm=string.format("%s      %s|",gm,dragonFang.Attack[4])
	--gm=string.format("%s      %s|",gm,dragonFang.Speed[4])
	gm=string.format("%s     %s|",gm,dragonFang.Damage[4])
	fangsGM=gm
	gm=""
	gm=string.format("%s  %s|",gm,dragonScales.AC[4])
	gm=string.format("%s    %s",gm,dragonScales.Resistances[4])
	scalesGM=gm
	
	--make fangs and scales learnable
	Game.Classes.Skills[10][32]=3
	Game.Classes.Skills[10][33]=3
	Game.Classes.Skills[11][32]=4
	Game.Classes.Skills[11][33]=4
end


function events.LoadMap()
	if not vars.dragonMeditationRemoved then
		for i=0,Party.High do
			local pl=Party[i]
			if Game.CharacterPortraits[pl.Face].Race==const.Race.Dragon and (pl.Class==10 or pl.Class==11) then
				local s,m = SplitSkill(pl.Skills[const.Skills.Meditation])
				while s>1 do
					pl.SkillPoints=pl.SkillPoints+s
					s=s-1
				end
				pl.Skills[const.Skills.Meditation]=0
			end
		end
		vars.dragonMeditationRemoved=true
	end
	if not unarmedText then
		unarmedText=Skillz.getDesc(33,1)
		unarmedTextN=Game.SkillDesNormal[33]
		unarmedTextE=Game.SkillDesExpert[33]
		unarmedTextM=Game.SkillDesMaster[33]
		unarmedTextGM=Game.SkillDesGM[33]
		dodgeText=Skillz.getDesc(32,1)
		dodgeTextN=Game.SkillDesNormal[32]
		dodgeTextE=Game.SkillDesExpert[32]
		dodgeTextM=Game.SkillDesMaster[32]
		dodgeTextGM=Game.SkillDesGM[32]
	end
end

function events.Action(t)
	if t.Action==114 then
		local race=Game.CharacterPortraits[Party[Game.CurrentPlayer].Face].Race
		if race==const.Race.Dragon then
			dragonSkill(true, Game.CurrentPlayer)
		else
			dragonSkill(false)
		end
	end
	if t.Action==110 then
		local race=Game.CharacterPortraits[Party[t.Param-1].Face].Race
		if race==const.Race.Dragon then
			dragonSkill(true, t.Param-1)
		else
			dragonSkill(false)
		end
	elseif t.Action==176 then
		local current=Game.CurrentPlayer
		local maxParty=Game.Party.High
		for i=1,Party.Count do
			newSelected=current+i+1
			while newSelected>maxParty do
				newSelected=newSelected-Party.Count
			end
			local pl=Party[newSelected]
			if pl.Dead==0 and pl.Stoned==0 and pl.Paralyzed==0 and pl.Eradicated==0 and pl.Asleep==0 and pl.Unconscious==0 then
				local race=Game.CharacterPortraits[pl.Face].Race
				if race==const.Race.Dragon then
					dragonSkill(true, newSelected)
				else
					dragonSkill(false, newSelected)
				end
			end
		end
	end
end

function events.Tick()
	if Game.CurrentScreen==7 then
		local current=Game.CurrentPlayer
		if current>=0 and current<=Party.High then
			local race=Game.CharacterPortraits[Party[Game.CurrentPlayer].Face].Race
			if race==const.Race.Dragon then
				dragonSkill(true, Game.CurrentPlayer)
			else
				dragonSkill(false)
			end
		end
	end
end

function dragonSkill(dragon, index)	
	if dragon then
		if index==-1 then return end
		pl=Party[index]
		Skillz.setName(33, "송곳니")

		local txt="드래곤은 송곳니로 적에게 끔찍한 피해를 줄 수 있습니다. 피해량은 30 + 레벨당 2입니다(최대 600레벨). 송곳니 기술은 숙련도와 기술 레벨에 따라 이 피해를 일정 비율만큼 증가시킵니다.\n\n송곳니 기술이 드래곤 기술보다 낮으면 공격 시 몬스터를 밀쳐냅니다.\n기술 포인트마다 피해가 증가하고 회복 시간이 1.5% 증가합니다.\n" .. "\n------------------------------------------------------------\n            공격| 피해|"
		Skillz.setDesc(33,1,txt)
		Game.SkillDesNormal[33]=fangsNormal
		Game.SkillDesExpert[33]=fangsExpert
		Game.SkillDesMaster[33]=fangsMaster
		Game.SkillDesGM[33]=fangsGM
		Skillz.setName(32,"비늘")
		txt="드래곤의 비늘은 천연 갑옷 역할을 할 만큼 단단하며, 레벨당 40 + 1의 방어력을 얻습니다(최대 600레벨).\n비늘 기술은 강인함과 마법 피해 저항을 더욱 높여 방어력을 일정 비율만큼 증가시킵니다.\n\n------------------------------------------------------------\n          방어%| 저항%"
		Skillz.setDesc(32,1,txt)
		Game.SkillDesNormal[32]=scalesNormal
		Game.SkillDesExpert[32]=scalesExpert
		Game.SkillDesMaster[32]=scalesMaster
		Game.SkillDesGM[32]=scalesGM
		if index==-1 then return end
		if dragon then
			if pl.Skills[33]==0 then
				pl.Skills[33]=1
			end
			if pl.Skills[32]==0 then
				pl.Skills[32]=1
			end
			if pl.Skills[23]==0 then
				pl.Skills[23]=1
			end
			
		end
		if Game.CurrentCharScreen==100 and Game.CurrentScreen==7 then
			Game.GlobalTxt[53] = "피해\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
			Game.GlobalTxt[18] = "근접         +" .. pl:GetMeleeAttack() .. "\n                 " .. shortenNumber(pl:GetMeleeDamageMin(), 4, false) .. "-" .. shortenNumber(pl:GetMeleeDamageMax(), 4, false) .. "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
			Game.GlobalTxt[203]="원거리         +" .. pl:GetRangedAttack() .. "\n                 " .. shortenNumber(pl:GetRangedDamageMin(), 4, false) .. "-" .. shortenNumber(pl:GetRangedDamageMax(), 4, false) .. "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
		else
			Game.GlobalTxt[18]="근접"
			Game.GlobalTxt[53]="피해량"
			Game.GlobalTxt[203]="원거리"
		end
	else
		Game.GlobalTxt[18]="근접"
		Game.GlobalTxt[53]="피해량"
		Game.GlobalTxt[203]="원거리"
		Skillz.setName(33,"맨손 전투")
		Skillz.setDesc(33,1,unarmedText)
		Game.SkillDesNormal[33]=unarmedTextN
		Game.SkillDesExpert[33]=unarmedTextE
		Game.SkillDesMaster[33]=unarmedTextM
		Game.SkillDesGM[33]=unarmedTextGM
		Skillz.setName(32,"회피")
		Skillz.setDesc(32,1,dodgeText)
		Game.SkillDesNormal[32]=dodgeTextN
		Game.SkillDesExpert[32]=dodgeTextE
		Game.SkillDesMaster[32]=dodgeTextM
		Game.SkillDesGM[32]=dodgeTextGM
	end
end

function events.GameInitialized2()
	function events.CalcDamageToMonster(t)
		data=WhoHitMonster()
		if data and data.Player and Game.CharacterPortraits[data.Player.Face].Race==const.Race.Dragon then
			local pl=data.Player
			if data.Object==nil then
				local breath = SplitSkill(data.Player:GetSkill(const.Skills.DragonAbility))
				local fang, fangM = SplitSkill(data.Player:GetSkill(const.Skills.Unarmed))
				if breath>=fang then
					local x, y = directionToUnitVector(Party.Direction)
					push=push or {}
					mult=fang/t.Monster.Level^0.75
					table.insert(push,{["directionX"]=x, ["directionY"]=y, ["duration"]=60*mult^0.5, ["totalDuration"]=60*mult^0.5, ["totalForce"]=800*mult, ["currentForce"]=800*mult, ["id"]=t.MonsterIndex})
				end
				
				local low=pl:GetMeleeDamageMin()
				local high=pl:GetMeleeDamageMax()
				local randomDamage=math.random(low, high) + math.random(low, high)
				local damage=round(randomDamage/2)
				
				--check by damage type
				index=table.find(damageKindMap,t.DamageKind)
				res=t.Monster.Resistances[index]
				if not res then return end
				critChance, critMult, crit=getCritInfo(pl,false,getMonsterLevel(t.Monster))
				if crit then
					damage=damage*critMult
				end
				if pl.Class==10 then
					pl.SP=math.min(pl.SP+10, 60)
				elseif pl.Class==11 then
					pl.SP=math.min(pl.SP+20, 120)
				end
				--apply Damage
				t.Result = damage /2^(res%1000/100)
			elseif t.DamageKind==50 or data.Spell==123 then
				local low=pl:GetRangedDamageMin()
				local high=pl:GetRangedDamageMax()
				local randomDamage=math.random(low, high) + math.random(low, high)
				local damage=round(randomDamage/2)
				
				critChance, critMult, crit=getCritInfo(pl,false,getMonsterLevel(t.Monster))
				if crit then
					damage=damage*critMult
				end
				if data.Spell==123 then
					local s,m=SplitSkill(t.Player.Skills[const.Skills.DragonAbility])
					local mult=0.85
					if m<=2 then
						mult=0.7
					elseif m==4 then
						mult=1
					end
					damage=damage*mult
				end
				--randomize
				damage=damage*0.75+(damage*math.random()*0.25)+(damage*math.random()*0.25)
				--resistance
				if t.Monster then
					local res=10000
					local mon=t.Monster
					for i=0,10 do
						if mon.Resistances[i] and mon.Resistances[i]%1000<res then
							res=mon.Resistances[i]%1000
						end
					end
					damage = damage/2^(res/100)
				end
				--apply Damage
				t.Result = damage
			end
		end
	end
end

-- Function to convert party direction to radians
function directionToRadians(direction)
    -- Convert the direction from 0-2048 scale to 0-2π scale
    return (direction / 2048) * 2 * math.pi
end

-- Function to calculate the unit vector based on the direction
function directionToUnitVector(direction)
    local radians = directionToRadians(direction)
    local x = math.cos(radians)
    local y = math.sin(radians)
	asdd=direction
	asdx=x
	asdy=y
    return x, y
end

function events.Tick()
	if push and push[1] then
		for i=1, #push do
			if push[i].duration>0 then
				push[i].duration=push[i].duration-1
				mon=Map.Monsters[push[i].id]
				mon.VelocityX=push[i].directionX * push[i].currentForce
				mon.VelocityY=push[i].directionY * push[i].currentForce
				mon.VelocityZ=push[i].currentForce/2 - push[i].totalForce/4
				push[i].currentForce=push[i].currentForce - push[i].totalForce / push[i].totalDuration
			end
		end
	end
end


---------------------------------------
--SHAMAN
---------------------------------------
function events.GameInitialized2()
	Game.ClassDescriptions[59] = "주술사는 마법 지식으로 무예를 강화하는 신비한 전사입니다.\n기술 메뉴의 마법 계열 설명에서 다음 수치를 확인할 수 있습니다.\n - 각 마법 계열은 고유한 보너스를 제공합니다. 여러 계열에 분산 투자하는 것과 한 계열에 집중하는 것 모두 장점이 있습니다.\n - 공기 기술 포인트마다 받는 피해를 일정 비율 감소시키며, 효과는 레벨에 따라 감소합니다.\n - 물 기술 포인트마다 받는 피해를 고정 수치로 감소시킵니다. 따라서 약한 적을 상대하거나 이미 방어력이 높은 경우 물이 더 효과적입니다.\n - 영혼 기술 포인트마다 치유량과 주문 피해가 일정 비율 증가합니다.\n - 화염은 몬스터의 현재 생명력에 비례한 화염 피해를 주며 저항을 일부 관통합니다. 보스 처치에 특화됩니다.\n - 대지 기술 포인트마다 근접 피해가 고정 수치로 증가합니다.\n - 육체 기술 포인트마다 고정 수치만큼 치유합니다.\n - 정신 기술 포인트마다 고정 수치만큼 마나를 회복합니다."
end

shamanClass={59, 60, 61}

function events.GameInitialized2()
	function events.CalcDamageToMonster(t)	
		local data = WhoHitMonster()
		if data and data.Player and table.find(shamanClass, data.Player.Class) and t.DamageKind==4 and data.Object==nil and t.Result>0 then	
			m6=SplitSkill(data.Player.Skills[const.Skills.Mind])
			m7,bM=SplitSkill(data.Player.Skills[const.Skills.Body])
			
			local FHP=data.Player:GetFullHP()
			local leech=math.max(round(FHP^0.5* m7^1.5/70 * (0.5+bM/2)), m7)
			local maxSP=data.Player:GetFullSP()
			data.Player.SP=math.min(data.Player.SP+m6^1.25, getMaxMana(data.Player))
			
			local id=data.Player:GetIndex()
			
			local healing=math.min(data.Player:GetFullHP()-data.Player.HP, leech)
			if healing>0 then
				vars.leechDone=vars.leechDone or {}
				vars.leechDone[id]=vars.leechDone[id] or 0
				vars.leechDone[id]=vars.leechDone[id] + healing
				mapvars.leechDone=mapvars.leechDone or {}
				mapvars.leechDone[id]=mapvars.leechDone[id] or 0
				mapvars.leechDone[id]=mapvars.leechDone[id] + healing
			end
			data.Player.HP=math.min(data.Player.HP+leech, data.Player:GetFullHP())
		end
	end
	--[[
	function events.CalcStatBonusByItems(t)
		if t.Stat==const.Stats.MeleeDamageMax or t.Stat==const.Stats.MeleeDamageMin then
			if table.find(shamanClass, t.Player.Class) then	
				--mastery=SplitSkill(t.Player.Skills[const.Skills.Thievery))
				m1=SplitSkill(t.Player.Skills[const.Skills.Fire])
				m2=SplitSkill(t.Player.Skills[const.Skills.Air])
				m3=SplitSkill(t.Player.Skills[const.Skills.Water])
				m4=SplitSkill(t.Player.Skills[const.Skills.Earth])
				m5=SplitSkill(t.Player.Skills[const.Skills.Spirit])
				m6=SplitSkill(t.Player.Skills[const.Skills.Mind])
				m7=SplitSkill(t.Player.Skills[const.Skills.Body])
				m8=m2+m3+m4+m5+m1+m6+m7
				t.Result=(t.Result+m8)*(1+m5/100) --*(0.5+mastery/10)+mastery*2
			end
		end
	end
	MOVED IN MAW ITEMS, DUE TO WEAPON SCALING]]
end

local baseSchoolsTxt={}
function events.GameInitialized2()
	for i=12,18 do
		baseSchoolsTxt[i]=Skillz.getDesc(i,1)
	end
end

local function shamanSkills(isShaman, id)
	if isShaman then
		pl=Party[id]
		local m1=SplitSkill(pl.Skills[const.Skills.Fire])
		local m2=SplitSkill(pl.Skills[const.Skills.Air])
		local m3=SplitSkill(pl.Skills[const.Skills.Water])
		local m4, earthMastery=SplitSkill(pl.Skills[const.Skills.Earth])
		local m5=SplitSkill(pl.Skills[const.Skills.Spirit])
		local m6=SplitSkill(pl.Skills[const.Skills.Mind])
		local m7, bodyMastery=SplitSkill(pl.Skills[const.Skills.Body])
		local txt
		local fireDamage=m1/10
		txt=baseSchoolsTxt[12] .. "\n\n기술 레벨이 7 오를 때마다 승천 레벨이 1 증가합니다.\n근접 공격은 몬스터 생명력의 " .. fireDamage .. "%만큼 추가 화염 피해를 줍니다."
		Skillz.setDesc(12,1,txt)
		local airReduction=round((1-1/(m2/100+1))*1000)/10
		txt=baseSchoolsTxt[13] .. "\n\n기술 레벨이 7 오를 때마다 승천 레벨이 1 증가합니다.\n받는 모든 피해 감소: " .. airReduction .. "%\n"
		Skillz.setDesc(13,1,txt)
		local lvl=getPartyLevel(4)
		
		local _,_,_,avgRed=getPlayerEstimatedVitality(lvl+1)
		local waterReduction=round(getMonsterDamage(false,(lvl+1))*(m3/lvl^0.65)/avgRed*0.99^(lvl^0.65)/2) --on average 1/2 of a B monster
		 --waterReduction=round(getMonsterDamage(false,(lvl+1)^0.325*m3)^0.7)
		txt=baseSchoolsTxt[14] .. "\n\n기술 레벨이 7 오를 때마다 승천 레벨이 1 증가합니다.\n받는 모든 피해 감소: " .. waterReduction .. "(저항 적용 후 계산)\n"
		Skillz.setDesc(14,1,txt)
		local armsmasterDamage=earthMastery*m4
		txt=baseSchoolsTxt[15] .. "\n\n기술 레벨이 7 오를 때마다 승천 레벨이 1 증가합니다.\n대지 마법 레벨당 근접 피해가 1-2-3-4(초보-전문가-마스터-그랜드마스터) 증가합니다.\n"
		Skillz.setDesc(15,1,txt)
		local spelldh=m5
		txt=baseSchoolsTxt[16] .. "\n\n기술 레벨이 7 오를 때마다 승천 레벨이 1 증가합니다.\n근접 피해 증가: " .. spelldh .. "%\n"
		Skillz.setDesc(16,1,txt)
		SPLEECH=round(m6^1.25)
		txt=baseSchoolsTxt[17] .. "\n\n기술 레벨이 7 오를 때마다 승천 레벨이 1 증가합니다.\n근접 공격 시 회복: " .. SPLEECH .. " 주문력\n"
		Skillz.setDesc(17,1,txt)
		local FHP=pl:GetFullHP()
		local leech=math.max(round(FHP^0.5* m7^1.5/70 * (1+bodyMastery/2)),m7)
		txt=baseSchoolsTxt[18] .. "\n\n기술 레벨이 7 오를 때마다 승천 레벨이 1 증가합니다.\n근접 공격 시 회복: " .. leech .. " 생명력\n"
		Skillz.setDesc(18,1,txt)
	else
		for i=12,18 do
			Skillz.setDesc(i,1,baseSchoolsTxt[i])
		end
	end
end


---------------------------------------
--DEATH KNIGHT
---------------------------------------
function events.GameInitialized2()
	Game.ClassDescriptions[56] = "이 직업은 사악한 힘과 강인한 육체를 결합해 강력하면서도 다재다능합니다.\n 냉기/혈기/부정 기술을 전문가/마스터/그랜드마스터로 올리면 새로운 주문을 자동으로 해금합니다. 단, 죽음의 기사는 주문서로 주문을 배울 수 없습니다.\n\n냉기:\n\n초보/마스터/그랜드마스터 단계에서 피해가 각각 1/2/3 증가하며, 투자한 기술 포인트마다 공격 속도가 1% 증가합니다.\n\n혈기:\n\n생존력을 강화해 기술 포인트당 받는 물리 피해를 1% 감소시킵니다. 또한 공격에 생명력 흡수 효과를 부여해 준 피해의 일부를 생명력으로 회복합니다.\n\n부정:\n\n초보/마스터/그랜드마스터 단계에서 피해가 각각 1/2/3 증가하며, 투자한 기술 포인트마다 받는 마법 피해가 1% 감소합니다."
end
--skills
--death grip

--runic power
dkClass={56,57,58}
spRegen={
	[56]=10,
	[57]=15,
	[58]=20,
}

--change spell cost to personalized value:
local DKManaCost={
	[26]=15,
	[27]=0,
	[29]=30,
	[32]=50,
	[68]=6,
	[71]=0,
	[76]=70,
	[74]=12,
	[91]=0,
	[90]=30,
	[96]=15,
	[97]=100,
}

local DKDamageMult={
	[26]={1,1,1.2,1.2,["Skill"]=14},
	[29]={1.5,1.5,1.5,2,["Skill"]=14},
	[32]={0.75,0.75,0.75,0.75,["Skill"]=14},
	[76]={1.1,1.1,1.1,1.4,["Skill"]=18},
	[90]={1,1,1,1.2,["Skill"]=20},
	[97]={0.6,0.6,0.6,0.6,["Skill"]=20},
}

--spells
function events.GameInitialized2()
	function events.CalcStatBonusByItems(t)
		--[[damage from skills 
		if t.Stat==const.Stats.MeleeDamageMax or t.Stat==const.Stats.MeleeDamageMin then
			if table.find(dkClass, t.Player.Class) then	
				local s1, m1=SplitSkill(t.Player.Skills[const.Skills.Water])
				--local s2, m2=SplitSkill(t.Player.Skills[const.Skills.Body])
				local s3, m3=SplitSkill(t.Player.Skills[const.Skills.Dark])
				local might=t.Player:GetMight()
				local bonus=s1*math.min(m1, 3)+s3*math.min(m3, 3)
				bonus=bonus*(1+might/1000)
				t.Result=t.Result+s1*math.min(m1, 3)+s3*math.min(m3, 3)
			end
		end
		MOVED IN MAW ITEMS, DUE TO WEAPON SCALING]]
			
		if t.Stat==const.Stats.SpellPoints and table.find(dkClass, t.Player.Class) then
			t.Result=0
		end
	end	
	--body leech damage
	function events.CalcDamageToMonster(t)
		local data = WhoHitMonster()
		if data and data.Player and table.find(dkClass, data.Player.Class) then
			local pl=data.Player
			local spell=0
			if data and data.Object and data.Object.Spell then
				spell=data.Object.Spell
			end
			if DKDamageMult[spell] then
				--add physical damage to spells
				baseDamage=pl:GetMeleeDamageMin()
				maxDamage=pl:GetMeleeDamageMax()
				randomDamage=math.random(baseDamage, maxDamage) + math.random(baseDamage, maxDamage)
				damage=round(randomDamage/2)
				
				critChance, critMult, success=getCritInfo(pl,false,getMonsterLevel(t.Monster))
				if success then
					damage=damage*critMult
					crit=true
				end
				for i=0,1 do
					local it=pl:GetActiveItem(i)
					if it then
						local damage1=calcFireAuraDamage(pl, it, 0, false, false, "damage")
						local damage2=calcEnchantDamage(pl, it, 0, false, false, "damage")
						damage=damage+damage1+damage2
					end
				end
				
				local res=t.Monster.Resistances[t.DamageKind] or t.Monster.Resistances[4]
				damage=damage/2^(res%1000/100)
				local mult=damageMultiplier[t.PlayerIndex]["Melee"]
				t.Result=damage*mult
				
				if pl.Weak>0 then
					t.Result=t.Result*0.5
				end
				
				--add spell modifier
				if DKDamageMult[spell] then
					local s,m=SplitSkill(pl.Skills[DKDamageMult[spell].Skill])
					t.Result=t.Result*DKDamageMult[spell][m]
				end
			end
			--life leech
			if t.DamageKind==4 and table.find(dkClass, data.Player.Class) then
				local pl=data.Player
				local bloodS, bloodM=SplitSkill(pl.Skills[const.Skills.Body])
				local FHP=pl:GetFullHP()
				local monLvl=getMonsterLevel(t.Monster)
				local heal=FHP*(bloodS/round(monLvl^0.7))*0.05
				--current active leech spell
				vars.dkActiveAttackSpell=vars.dkActiveAttackSpell or {}
				local id=pl:GetIndex()
				leech=0
				if vars.dkActiveAttackSpell and (vars.dkActiveAttackSpell[id]==68 or vars.dkActiveAttackSpell[id]==74) then
					local FHP=pl:GetFullHP()
					local leech=math.max(FHP^0.5* bloodS^1.5/70* (1+bloodM/4), bloodS*2)
					pl.SP=pl.SP-6
					if vars.dkActiveAttackSpell[id]==74 then
						leech=leech * 2
						pl.SP=pl.SP-6
					end
				end
				
				local id=pl:GetIndex()
			
				local healing=math.min(pl:GetFullHP()-pl.HP, round(leech+heal))
				if healing>0 then
					vars.leechDone=vars.leechDone or {}
					vars.leechDone[id]=vars.leechDone[id] or 0
					vars.leechDone[id]=vars.leechDone[id] + healing
					mapvars.leechDone=mapvars.leechDone or {}
					mapvars.leechDone[id]=mapvars.leechDone[id] or 0
					mapvars.leechDone[id]=mapvars.leechDone[id] + healing
				end
				
				pl.HP=math.min(pl:GetFullHP(), pl.HP+heal+leech)
				
				--dark grasp
				if vars.dkActiveAttackSpell and vars.dkActiveAttackSpell[id]==96 then
					pl.SP=pl.SP-15
					local darkGraspCC = {Debuff = const.MonsterBuff.DamageHalved}
					local graspDuration = calcDebuffDuration(t.Monster, darkGraspCC, const.Minute)
					if graspDuration > 0 then
						t.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].ExpireTime=math.max(t.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].ExpireTime, Game.Time+graspDuration)
						local s, m=SplitSkill(pl.Skills[const.Skills.Dark])
						if m==4 then
							t.Monster.SpellBuffs[const.MonsterBuff.MeleeOnly].ExpireTime=math.max(t.Monster.SpellBuffs[const.MonsterBuff.MeleeOnly].ExpireTime, Game.Time+graspDuration)
						end
					end
				end
				--restore SP
				if t.DamageKind==4 then
					local regen=spRegen[pl.Class]
					if t.Result>t.Monster.HP then
						regen=regen*1.5
					end
					pl.SP=math.min(getMaxMana(pl), pl.SP+regen)
				end
			end
			
			--spell effect
			if data and data.Object then
				if data.Object.Spell==26 then
					local s,m=SplitSkill(pl.Skills[const.Skills.Water])
					if m>=2 then
						local power=math.floor(m/2)*2
						local slowCC = {Debuff = const.MonsterBuff.Slow}
						local slowDuration = calcDebuffDuration(t.Monster, slowCC, const.Minute)
						if slowDuration > 0 then
							t.Monster.SpellBuffs[const.MonsterBuff.Slow].ExpireTime=math.max(t.Monster.SpellBuffs[const.MonsterBuff.Slow].ExpireTime, Game.Time+slowDuration)
							t.Monster.SpellBuffs[const.MonsterBuff.Slow].Power=power
						end
					end
				elseif data.Object.Spell==76 then
					local paraCC = {Debuff = const.MonsterBuff.Paralyze}
					local paraDuration = calcDebuffDuration(t.Monster, paraCC, const.Minute*2)
					if paraDuration > 0 then
						t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime=math.max(t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime, Game.Time+paraDuration)
					end
				end
			end
		end
	end
	
	function events.Action(t)
		if (t.Action==142 and t.Param==68) or (t.Action==142 and t.Param==74) or (t.Action==142 and t.Param==96) then
			if table.find(dkClass, Party[Game.CurrentPlayer].Class) then
				t.Handled=true
				vars.dkActiveAttackSpell=vars.dkActiveAttackSpell or {}
				local id=Party[Game.CurrentPlayer]:GetIndex()
				if vars.dkActiveAttackSpell[id]==t.Param then
					vars.dkActiveAttackSpell[id]=false
					Game.ShowStatusText(Game.SpellsTxt[t.Param].Name .. " 공격 시 발동 비활성화")
				else
					Game.ShowStatusText(Game.SpellsTxt[t.Param].Name .. " 공격 시 발동 활성화")
					vars.dkActiveAttackSpell[id]=t.Param
				end
			end
		end
		--same for quickcast
		if t.Action==25 and Game.CurrentPlayer>=0 and Game.CurrentPlayer<=Party.High and table.find(dkClass, Party[Game.CurrentPlayer].Class) then
			local pl=Party[Game.CurrentPlayer]
			local id=pl:GetIndex()
			if pl.QuickSpell==68 or pl.QuickSpell==74 or pl.QuickSpell==96 then
				t.Handled=true
				vars.dkActiveAttackSpell=vars.dkActiveAttackSpell or {}
				local id=Party[Game.CurrentPlayer]:GetIndex()
				if vars.dkActiveAttackSpell[id]==t.Param then
					vars.dkActiveAttackSpell[id]=false
					Game.ShowStatusText(Game.SpellsTxt[pl.QuickSpell].Name .. " 공격 시 발동 비활성화")
				else
					Game.ShowStatusText(Game.SpellsTxt[pl.QuickSpell].Name .. " 공격 시 발동 활성화")
					vars.dkActiveAttackSpell[id]=t.Param
				end
			end
		end
	end
	
	--spells speed depends on weapon
	function events.PlayerCastSpell(t)
		if table.find(dkClass, t.Player.Class) then
			local spell=t.SpellId
			local m=t.Mastery
			Game.Spells[spell]["Delay" .. masteryName[m]]=t.Player:GetAttackDelay()
			if t.SpellId==68 or t.SpellId==74 then
				t.Handled=true
			end
		end
	end
end

DKSpellList={
	[const.Skills.Water]={26, 27, 29, 32},
	[const.Skills.Body]={68, 71, 76, 74},
	[const.Skills.Dark]={91, 90, 96, 97},
}

function events.Action(t)
	if t.Action==105 and Game.CurrentPlayer>=0 and Game.CurrentPlayer<=Party.High then
		
		pl=Party[Game.CurrentPlayer]
		if table.find(dkClass, pl.Class) then
			for i=1,99 do
				pl.Spells[i]=false
			end
			local s1, m1=SplitSkill(pl.Skills[const.Skills.Water])
			local s2, m2=SplitSkill(pl.Skills[const.Skills.Body])
			local s3, m3=SplitSkill(pl.Skills[const.Skills.Dark])
			for i=1, m1 do
				pl.Spells[DKSpellList[const.Skills.Water][i]]=true
			end
			for i=1, m2 do
				pl.Spells[DKSpellList[const.Skills.Body][i]]=true
			end
			for i=1, m3 do
				pl.Spells[DKSpellList[const.Skills.Dark][i]]=true
			end
		end
	end
end

function events.CanLearnSpell(t)
	if table.find(dkClass, t.Player.Class) then
		t.NeedMastery = 5
	end
end


--tooltips
local baseSchoolsTxtDK={}
function events.GameInitialized2()
	baseSchoolsTxtDK={[14]=Skillz.getDesc(14,1), [18]=Skillz.getDesc(18,1), [20]=Skillz.getDesc(20,1)}
	spellDesc={}
	for key, value in pairs(DKSpellList) do
		for i=1,#DKSpellList[key] do
			local spellID=DKSpellList[key][i]
			if spellID~=71 then
				spellDesc[spellID]={}
				spellDesc[spellID]["Name"]=Game.SpellsTxt[value[i]].Name
				spellDesc[spellID]["Description"]=Game.SpellsTxt[value[i]].Description
				spellDesc[spellID]["Normal"]=Game.SpellsTxt[value[i]].Normal
				spellDesc[spellID]["Expert"]=Game.SpellsTxt[value[i]].Expert
				spellDesc[spellID]["Master"]=Game.SpellsTxt[value[i]].Master
				spellDesc[spellID]["GM"]=Game.SpellsTxt[value[i]].GM
			end
		end
	end
end

function dkSkills(isDK, id)
	if isDK then
		local pl=Party[id]
		for key, value in pairs(DKManaCost) do
			for i=1,4 do
				Game.Spells[key]["SpellPoints" .. masteryName[i]]=value
			end
		end
		
		-- Spell 26: Icy Touch
		local mult26 = DKDamageMult[26]
		Game.SpellsTxt[26].Name="얼음의 손길"
		Game.SpellsTxt[26].Description="죽음의 기사 전용 주문입니다. 피해량: " .. (mult26[1]*100) .. "% (현재 무기 피해 기준)."
		Game.SpellsTxt[26].Normal="피해량: " .. (mult26[1]*100) .. "% (근접 공격 피해 기준)"
		Game.SpellsTxt[26].Expert="몬스터의 속도가 50% 감소합니다"
		Game.SpellsTxt[26].Master="피해량: " .. (mult26[3]*100) .. "%"
		Game.SpellsTxt[26].GM="몬스터의 속도가 25% 감소합니다"
		
		-- Spell 29: Frostbite
		local mult29 = DKDamageMult[29]
		Game.SpellsTxt[29].Name="동상"
		Game.SpellsTxt[29].Description="죽음의 기사가 사용할 수 있는 가장 강력한 단일 대상 피해 주문입니다. 피해량: " .. (mult29[1]*100) .. "% (현재 무기 피해 기준)."
		Game.SpellsTxt[29].Expert="n/a"
		Game.SpellsTxt[29].Master="피해량: " .. (mult29[3]*100) .. "% (근접 공격 피해 기준)"
		Game.SpellsTxt[29].GM="피해량: " .. (mult29[4]*100) .. "% (근접 공격 피해 기준)"
		
		-- Spell 32: Ice Bomb
		local mult32 = DKDamageMult[32]
		Game.SpellsTxt[32].Name="얼음 폭탄"
		Game.SpellsTxt[32].Description="충돌하면 산산이 부서지는 얼음 폭탄을 던집니다. 큰 적이나 여러 적을 상대할 때 특히 효과적입니다.\n피해량은 현재 무기 피해의 " .. (mult32[1]*100) .. "% (현재 무기 피해 기준)."
		Game.SpellsTxt[32].Expert="n/a"
		Game.SpellsTxt[32].Master="n/a"
		Game.SpellsTxt[32].GM="타격당 피해량: " .. (mult32[4]*100) .. "% (근접 공격 피해 기준)"
		
		
		
		local bloodS, bloodM=SplitSkill(pl.Skills[const.Skills.Body])
		local unholyS, unholyM=SplitSkill(pl.Skills[const.Skills.Dark])
		
		local FHP=pl:GetFullHP()
		local leech=math.max(FHP^0.5* bloodS^1.5/70, bloodS*2)
		Game.SpellsTxt[68].Name="피 흡수"
		Game.SpellsTxt[68].Description="이 주문을 활성화하면 기사의 몸에 피의 힘을 부여하여 공격할 때마다 생명력을 흡수합니다. 주문력 6을 소모합니다."
		Game.SpellsTxt[68].Normal="생명력 흡수: " .. round(leech * 1.25) .. " 생명력"
		Game.SpellsTxt[68].Expert="생명력 흡수: " .. round(leech * 1.5) .. " 생명력"
		Game.SpellsTxt[68].Master="생명력 흡수: " .. round(leech * 1.75) .. " 생명력"
		Game.SpellsTxt[68].GM="생명력 흡수: " .. round(leech * 2) .. " 생명력"
		
		-- Spell 74: Superior Blood Leech
		Game.SpellsTxt[74].Name="상급 피 흡수"
		Game.SpellsTxt[74].Description="이 주문을 활성화하면 기사의 본질에 피의 힘을 부여하여 공격할 때 더 많은 생명력을 흡수합니다. 주문력 12를 소모합니다."
		Game.SpellsTxt[74].Master="n/a"
		Game.SpellsTxt[74].GM="생명력 흡수: " .. round(leech * 4) .. " 생명력"
		
		-- Spell 76: Asphyxiate (no entry in DKDamageMult, but description mentions 110% and 140%)
		local mult76= DKDamageMult[76]
		Game.SpellsTxt[76].Name="질식"
		Game.SpellsTxt[76].Description="대상을 질식시킵니다. 피해량: " .. (mult76[3]*100) .. "%의 피해를 주고 4초 동안 행동할 수 없게 합니다."
		Game.SpellsTxt[76].Master="추가 효과 없음"
		Game.SpellsTxt[76].GM="피해량: " .. (mult76[4]*100) .. "%"
		
		-- Spell 90: Death Coil
		local mult90 = DKDamageMult[90]
		Game.SpellsTxt[90].Name="죽음의 고리"
		Game.SpellsTxt[90].Description="대상을 적중하면 생명력 흡수 마법 부여 효과의 두 배만큼 시전자의 생명력을 회복시키는 치명적인 주문입니다. 피해량: " .. (mult90[1]*100) .. "% (기본 무기 피해 기준)"
		Game.SpellsTxt[90].Normal="N/A"
		Game.SpellsTxt[90].Expert="피해량: " .. (mult90[2]*100) .. "%"
		Game.SpellsTxt[90].Master="흡수량 50% 증가"
		Game.SpellsTxt[90].GM="피해량: " .. (mult90[4]*100) .. "%"
		
		Game.SpellsTxt[96].Name="죽음의 손아귀"
		Game.SpellsTxt[96].Description="이 주문을 활성화하면 기사의 몸에 어둠의 힘을 부여하여 공격할 때 적의 힘을 약화시킵니다(피해량 절반). 주문력 15를 소모합니다."
		Game.SpellsTxt[96].Expert="n/a"
		Game.SpellsTxt[96].Master="추가 효과 없음"
		Game.SpellsTxt[96].GM="몬스터가 원거리 공격 능력을 잃습니다"
		
		-- Spell 97: Death Breath
		local mult97 = DKDamageMult[97]
		Game.SpellsTxt[97].Name="죽음의 숨결"
		Game.SpellsTxt[97].Description="치명적인 폭발을 일으켜 범위 내 모든 몬스터에게 막대한 피해를 줍니다. 근접전에서도 안전하게 사용할 수 있습니다.\n피해량은 무기 피해의 " .. (mult97[1]*100) .. "% (무기 피해 기준)"
		Game.SpellsTxt[97].Expert="n/a"
		Game.SpellsTxt[97].Master="n/a"
		Game.SpellsTxt[97].GM="이 주문은 이미 최고의 성능을 발휘하고 있습니다!"
		
		--skill names and desc
		
		Skillz.setName(14, "냉기")
		Skillz.setName(18, "혈마법")
		Skillz.setName(20, "사악함")
		local txt
		txt="죽음의 기사만 사용할 수 있는 기술입니다. 피해가 0.5-1-1.5(초보-전문가-마스터) 증가하고 기술 포인트당 공격 속도가 2% 증가합니다.\n"
		Skillz.setDesc(14,1,txt)
		local leech=round(bloodS/round(pl.LevelBase^0.7)*5*100)/100
		txt="죽음의 기사만 사용할 수 있는 기술입니다. 받는 물리 피해가 감소합니다.\n" .. "현재 피해 감소: " .. round((1-1/(bloodS/100+1))*1000)/10 .."%\n\n추가로 총 생명력에 비례하여 공격 시 생명력을 흡수합니다.\n\n동일 레벨 몬스터 대상 현재 흡혈량: " .. leech .. "%\n"            
		Skillz.setDesc(18,1,txt)
		txt="죽음의 기사만 사용할 수 있는 기술입니다. 피해가 0.5-1-1.5(초보-전문가-마스터) 증가하고 받는 마법 피해가 감소합니다.\n" .. "현재 피해 감소: " .. round((1-1/(unholyS/100+1))*1000)/10 .."%\n"
		Skillz.setDesc(20,1,txt)
		Skillz.setDesc(14,5,"효과는 주문마다 다릅니다")
		Skillz.setDesc(18,5,"효과는 주문마다 다릅니다")
	else
		for key, value in pairs(baseSchoolsTxtDK) do
			Skillz.setDesc(key,1,value)
		end
		for key, value in pairs(spellDesc) do
			for key2, value2 in pairs(value) do
				Game.SpellsTxt[key][key2]=value2
			end
		end
		Skillz.setName(14, "물 마법")
		Skillz.setName(18, "육체 마법")
		Skillz.setName(20, "어둠 마법")
	end
end


--[[add tooltips
function events.Action(t)
	function events.Tick() 
		local id=Game.CurrentPlayer
		if id>=0 and id<=Party.High then
			events.Remove("Tick", 1)
			checkSkills(id)
		end
	end
end
moved into ascension tick event, as it was causing some mana cost issues]]

function events.Action(t)
	if t.Action==114 then
		checkSkills(Game.CurrentPlayer)
	end
	if t.Action==110 then
		checkSkills(t.Param-1)
	elseif t.Action==176 then
		local current=Game.CurrentPlayer
		local maxParty=Game.Party.High
		for i=1,Party.Count do
			newSelected=current+i+1
			while newSelected>maxParty do
				newSelected=newSelected-Party.Count
			end
			local pl=Party[newSelected]
			if pl.Dead==0 and pl.Stoned==0 and pl.Paralyzed==0 and pl.Eradicated==0 and pl.Asleep==0 and pl.Unconscious==0 then
				checkSkills(newSelected)
			end
		end
	end
end


----------------
--ELEMENTALIST--
----------------

elementalistClass={62,63,64}

function events.GameInitialized2()
	Game.ClassDescriptions[62] = "원소술사는 가장 큰 마나량을 지닌 주문 시전자이며, 책이 아니라 같은 원소 계열의 주문을 직접 시전하면서 주문을 익힙니다. 승천을 직접 배울 수는 없지만 승천 레벨은 네 원소 계열 기술 레벨 합계를 4로 나눈 값에 따라 결정됩니다. 기본 주문 회복 시간은 50% 더 길지만, 마법을 시전하면 중첩을 얻어 다음 효과가 증가합니다:\n\n주문 피해: 중첩당 10%\n주문 회복 속도: 중첩당 5%\n마나 소모: 1 + 총량의 7.5%\n\n몇 초 동안 주문을 시전하지 않으면 중첩이 50%씩 감소합니다. 활이나 근접 무기로 피해를 주거나 주문서를 사용하면 집중이 깨져 모든 중첩이 즉시 초기화됩니다.\n\n주문은 무작위로 시전되지만 단일 대상, 광역 효과, 산탄형의 세 범주로 나뉩니다. 지정한 빠른 시전 주문에 따라 로테이션이 조정됩니다. 예를 들어 화염구를 빠른 시전 주문으로 설정하면 광역 주문을 자동으로 우선합니다."
	Game.Classes.HPFactor[63]=2.5
end

function events.CanLearnSpell(t)
	if table.find(elementalistClass, t.Player.Class) then
		t.NeedMastery = 5
		Game.ShowStatusText("원소술사는 실전을 통해 주문을 익힙니다")
	end
end

spellRequirements={0,0,500,1500,5000,10000,20000,40000,80000,160000,320000}
local masteryRequired={1,1,1,1,2,2,2,3,3,3,4}
function events.CalcDamageToMonster(t)
	if t.Monster.Hostile==false and t.Monster.ShowAsHostile==false then
		return
	end
	local data=WhoHitMonster()
	if data and data.Player and data.Object and table.find(elementalistClass, data.Player.Class) and data.Object.Spell<45 and data.Object.Spell>0 then
		local pl=data.Player
		local spell=data.Object.Spell
		local school=math.ceil(spell/11)+11
		vars.elementalistSpells=vars.elementalistSpells or {}
		vars.elementalistSpells[pl:GetIndex()]=vars.elementalistSpells[pl:GetIndex()] or {}
		vars.elementalistSpells[pl:GetIndex()][school]=vars.elementalistSpells[pl:GetIndex()][school] or 0
		
		local tier=spell%11==0 and 11 or spell%11
		local learningBonus=tier^1.5 * t.Monster.Level^0.5
		if not vars.insanityMode then
			learningBonus = learningBonus * Party.Count^0.5
		end
		if table.find(aoespells,spell) and spell~=15 and spell~=24 then
			learningBonus=learningBonus/3
		end
		vars.elementalistSpells[pl:GetIndex()][school]=vars.elementalistSpells[pl:GetIndex()][school] + learningBonus
		school2=(school-12)*11
		for i=1,11 do
			local spell2= school2+i
			if pl.Spells[spell2]==false then
				local tier=spell2%11==0 and 11 or spell2%11
				local s,m=SplitSkill(pl:GetSkill(school))
				if vars.elementalistSpells[pl:GetIndex()][school]>=spellRequirements[tier] and m>=masteryRequired[tier] then
					if vars.insanityMode and spell2==19 and m<4 then
						pl.Spells[spell2]=false
					else
						pl.Spells[spell2]=true
						Message("습득: " .. Game.SpellsTxt[spell2].Name)
					end
				end
			end
		end		
	end
end

eleOffSpellsOut={2,6,7,9,11,
				15,18,20,22,
				24,26,29,32,
				37,39,41,43,44}
eleOffSpellsIn={2,6,7,10,11,
				15,18,20,
				24,26,29,32,
				37,39,41,44}

function events.Action(t)
	if t.Action==105 then
		if Game.CurrentPlayer>=0 and Game.CurrentPlayer<=Party.High then
			local pl=Party[Game.CurrentPlayer]
			if table.find(elementalistClass, pl.Class) then
				pl.Spells[2]=true
				pl.Spells[15]=true
				pl.Spells[24]=true
				pl.Spells[37]=true
			end
		end
	end
end


function events.PlayerCastSpell(t)
	if vars.disableRotation and vars.disableRotation[t.PlayerIndex] then
		return
	end
	if table.find(elementalistClass, t.Player.Class) and (table.find(eleOffSpellsOut, t.SpellId) or table.find(eleOffSpellsIn, t.SpellId)) and vars.elementalistSpellBinds then
		local pl=t.Player
		local index=t.PlayerIndex
		local spell=t.SpellId
		for i=1,6 do
			if i<=4 and ExtraQuickSpells.SpellSlots then
				if ExtraQuickSpells.SpellSlots[index][i]==spell then
					ExtraQuickSpells.SpellSlots[index][i]=elementalistRandomizer(pl, vars.elementalistSpellBinds[index][i])
				end
			elseif i==5 then
				if pl.AttackSpell==spell then
					pl.AttackSpell=elementalistRandomizer(pl, vars.elementalistSpellBinds[index][i])
				end
			elseif i==6 then
				if pl.QuickSpell==spell then
					pl.QuickSpell=elementalistRandomizer(pl, vars.elementalistSpellBinds[index][i])
				end
			end
		end
		vars.eleTimer=vars.eleTimer or {}
		vars.eleTimer[index]=Game.Time+math.max(getSpellDelay(pl,spell)*4, 128)
		vars.eleStacks=vars.eleStacks or {}
		vars.eleStacks[index]=vars.eleStacks[index] or 0
		vars.eleStacks[index]=vars.eleStacks[index]+1
		vars.eleTimer=vars.eleTimer or {}
	end
end

function elementalistStacksDecay()
	for i=0,Party.High do
		local pl=Party[i]
		if table.find(elementalistClass, pl.Class) then
			local id=pl:GetIndex()
			vars.eleStacks=vars.eleStacks or {}
			vars.eleStacks[id]=vars.eleStacks[id] or 0
			vars.eleTimer=vars.eleTimer or {}
			vars.eleTimer[id]=vars.eleTimer[id] or Game.Time
			if Game.Time>vars.eleTimer[id] then
				vars.eleTimer[id]=Game.Time+const.Minute/2
				vars.eleStacks[id]=math.max(math.floor(vars.eleStacks[id]*0.5),0)
			end
		end	
	end
end


function events.CalcDamageToMonster(t)
	local data=WhoHitMonster()
	if data and data.Player and (not data.Object or data.Object.Spell==133) then
		local pl=data.Player
		if table.find(elementalistClass, pl.Class) then
			local id=pl:GetIndex()
			vars.eleStacks=vars.eleStacks or {}
			vars.eleStacks[id]=0
		end
	end
end

singleTarget={2,11,20,26,29,37,39}
shotGun={2,15,24,37}
aoeIn={6,10,18,32,41}
aoeOut={6,9,18,22,32,41,43}

function elementalistRandomizer(pl, spellType)
	local possibleSpells={}
	if spellType=="single" then
		for i=1,#singleTarget do
			if pl.Spells[singleTarget[i]] then
				table.insert(possibleSpells, singleTarget[i])
			end
		end
	elseif spellType=="shotgun" then
		for i=1,#shotGun do
			if pl.Spells[shotGun[i]] then
				table.insert(possibleSpells, shotGun[i])
			end
		end
	elseif spellType=="aoe" and Map.IsIndoor() then
		for i=1,#aoeIn do
			if pl.Spells[aoeIn[i]] then
				table.insert(possibleSpells, aoeIn[i])
			end
		end
	elseif spellType=="aoe" then
		for i=1,#aoeOut do
			if pl.Spells[aoeOut[i]] then
				table.insert(possibleSpells, aoeOut[i])
			end
		end
	end
	if #possibleSpells>=1 then
		return possibleSpells[math.random(1,#possibleSpells)]
	else
		return false
	end
end

--reset stacks when casting from spellbook
function events.Action(t)
	if t.Action==142 then
		local id=Game.CurrentPlayer
		if id>=0 and id<=Party.High then
			if table.find(elementalistClass,Party[id].Class) then
				if table.find(eleOffSpellsOut,t.Param) or table.find(eleOffSpellsIn,t.Param) then
					vars.eleStacks=vars.eleStacks or {}
					vars.eleStacks[Party[id]:GetIndex()]=0
				end
			end
		end
	end
end

--set current keybind by keybindrotation
function events.Action(t)
	if Game.CurrentScreen==8 and t.Action==113 then
		local id=Game.CurrentPlayer
		if id>=0 and id<=Party.High then
			local pl=Party[id]
			local index=pl:GetIndex()
			if table.find(elementalistClass,pl.Class) then
				for i=1,6 do
					local spell=0
					if i<=4 and ExtraQuickSpells.SpellSlots then
						spell=ExtraQuickSpells.SpellSlots[index][i]
					elseif i==5 then
						spell=pl.AttackSpell
					elseif i==6 then
						spell=pl.QuickSpell
					end
					
					vars.elementalistSpellBinds=vars.elementalistSpellBinds or {}
					vars.elementalistSpellBinds[index]=vars.elementalistSpellBinds[index] or {}
					if table.find(singleTarget,spell) then
						vars.elementalistSpellBinds[index][i]="single"
					elseif table.find(shotGun,spell) then
						vars.elementalistSpellBinds[index][i]="shotgun"
					elseif table.find(aoeIn,spell) or table.find(aoeOut,spell) then
						vars.elementalistSpellBinds[index][i]="aoe"
					else
						vars.elementalistSpellBinds[index][i]=false					
					end
				end
			end
		end
	end
end

--show stacks
function events.GameInitialized2()
	elementalistStacks={}
	for i=0,4 do
		elementalistStacks[i]=CustomUI.CreateText{
			Text = "",
			Layer 	= 1,
			Screen 	= 0,
			X = 5+i*96, Y = 387
		}
	end
end

function events.Tick()
	for i=0,Party.High do
		local pl=Party[i]
		if table.find(elementalistClass,pl.Class) then
			local id=pl:GetIndex()
			vars.eleStacks=vars.eleStacks or {}
			vars.eleStacks[id]=vars.eleStacks[id] or 0
			elementalistStacks[i].Text=string.format(vars.eleStacks[id])
		else
			elementalistStacks[i].Text=""
		end
	end
end

local function elementalistSkills(isElementalist, id)
	if isElementalist then
		local pl=Party[id]
		vars.elementalistSpells=vars.elementalistSpells or {}
		vars.elementalistSpells[pl:GetIndex()]=vars.elementalistSpells[pl:GetIndex()] or {}
		for i=12,15 do
			vars.elementalistSpells[pl:GetIndex()][i]=vars.elementalistSpells[pl:GetIndex()][i] or 0
		end
	
		local list = vars.elementalistSpells[pl:GetIndex()]
		local enableDisableText = StrColor(0,255,0, "활성화")
		if vars.disableRotation and vars.disableRotation[pl:GetIndex()] then
			enableDisableText = StrColor(255,0,0, "비활성화")
		end
		local rotationText = StrColor(0,0,0,"원소술사의 공격 주문을 무작위로 시전하면 원소술사 중첩을 얻으며, 중첩에 따라 주문 피해, 속도, 비용이 증가합니다.\nR키로 무작위 로테이션을 활성화/비활성화합니다.\n현재 ") .. enableDisableText .. "\n\n"
		for i=12,15 do
			local progression=list[i]
			local currentTier=0
			for j=1,#spellRequirements do
				if progression>=spellRequirements[j] then
					currentTier=j
				end
			end
			if currentTier<11 then
				local low=spellRequirements[currentTier]
				local high=spellRequirements[currentTier+1]
				local percentageProgression=math.floor((progression-low)/(high-low)*10000)/100
				Skillz.setDesc(i,5, "효과는 주문마다 다릅니다.\n\n" .. rotationText .. "원소술사는 책 대신 실전을 통해 새로운 주문을 익힙니다.\n\n다음 주문 습득 진행도: " .. Game.SpellsTxt[(i-12)*11+currentTier+1].Name .. ": " .. percentageProgression .."%")
			else
				Skillz.setDesc(i,5, "효과는 주문마다 다릅니다.\n\n" .. rotationText .. "원소술사는 책 대신 실전을 통해 새로운 주문을 익힙니다.\n\n이 계통에서 배울 수 있는 주문을 모두 습득했습니다.")
			end
		end
	else
		for i=12,15 do
			Skillz.setDesc(i,5,"효과는 주문마다 다릅니다")		
		end
	end
end


function checkSkills(id)
	shamanSkills(false, id)
	dkSkills(false, id)
	seraphSkills(false, id)
	elementalistSkills(false, id)
	assassinSkills(false)
	adjustSpellTooltips()
	if id>=0 and id<=Party.High then
		local class=Party[id].Class
		if table.find(shamanClass, class) then
			shamanSkills(true, id)
			return
		end
		if table.find(dkClass, class) then
			dkSkills(true, id)
			return
		end
		if table.find(seraphClass, class) then
			seraphSkills(true, id)
			return
		end
		if table.find(elementalistClass, class) then
			elementalistSkills(true, id)
			return
		end
		if table.find(assassinClass, class) then
			assassinSkills(true, Party[id])
			return			
		end
	end
end
--[[test code
function events.PlayerCastSpell(t)
	if t.SpellId==2 then
		BeginGrabObjects()
		RunNextTick(function()
			obj1=GrabObjects()
			
			--calculate velocity
			-- Define math constants
			local pi = math.pi
			local sqrt = math.sqrt
			local atan2 = math.atan2
			local cos = math.cos
			local sin = math.sin

			-- Original velocity components
			local V_x = obj1.VelocityX
			local V_y = obj1.VelocityY

			-- Number of projectiles and spread angle
			local n = 5
			local delta_theta = pi / 12

			-- Calculate the speed
			local speed = sqrt(V_x * V_x + V_y * V_y)

			-- Original direction angle
			local theta_0 = atan2(V_y, V_x)

			-- Calculate new velocities for each projectile
			new_velocities = {}

			for i = -math.floor(n / 2), math.floor(n / 2) do
				local theta_i = theta_0 + (delta_theta * i)
				local V_x_i = speed * cos(theta_i)
				local V_y_i = speed * sin(theta_i)
				table.insert(new_velocities, {V_x_i, V_y_i})
			end
			
			--manually change it
			for i=1,n do
			
				BeginGrabObjects()
				Game.SummonObjects(obj1.Type, obj1.X, obj1.Y, obj1.Z, 100,1)
				obj2=GrabObjects()
				
				obj2.Age=obj1.Age
				obj2.AttachToHead=obj1.AttachToHead
				obj2.AttackType=obj1.AttackType
				obj2.Bits=obj1.Bits
				obj2.Direction=obj2.Direction
				obj2.DroppedByPlayer=obj1.DroppedByPlayer
				obj2.HaltTurnBased=obj1.HaltTurnBased
				obj2.IgnoreRange=obj1.IgnoreRange
				obj2.LightMultiplier=obj1.LightMultiplier
				obj2.LookAngle=obj1.LookAngle
				obj2.MaxAge=obj1.MaxAge
				obj2.Missile=obj1.Missile
				obj2.NoZBuffer=obj1.NoZBuffer
				obj2.Owner=obj1.Owner
				obj2.Range=obj1.Range
				obj2.Removed=obj1.Removed
				obj2.Room=obj1.Room
				obj2.SkipAFrame=obj1.SkipAFrame
				obj2.Spell=obj1.Spell
				obj2.SpellLevel=obj1.SpellLevel
				obj2.SpellMastery=obj1.SpellMastery
				obj2.SpellSkill=obj1.SpellSkill
				obj2.SpellType=obj1.SpellType
				obj2.StartX=obj1.StartX
				obj2.StartY=obj1.StartY
				obj2.StartZ=obj1.StartZ
				obj2.Target=obj1.Target
				obj2.Temporary=obj1.Temporary
				obj2.Type=obj1.Type
				obj2.TypeIndex=obj1.TypeIndex
				obj2.VelocityX=new_velocities[i][1]
				obj2.VelocityY=new_velocities[i][2]
				obj2.VelocityZ=obj1.VelocityZ
				obj2.Visible=obj1.Visible
				obj2.X=obj1.X
				obj2.Y=obj1.Y
				obj2.Z=obj1.Z
			end
		end)
	end
end
--getDistance(obj1.X,obj1.Y,obj1.Z,obj2.X,obj2.Y,obj2.Z,)
]]
--starts at +50% recovery time
--each spell cast grants a stack
--each stack increases attack speed by 10%, up to 10 stacks (making spell cast half as a normal caster would have)
--each stack increase ascension skill by 1
--base ascension skill increased by 1 every 8 elemental school level
--no ascension cap
--can't learn ascension
--attacking or shooting an arrow will reset stacks
--not casting for more than 5 seconds will reset stacks
--each spell is categorized between single, AoE or shotgun.
--each spell can have multiple categories

--minotaur hp fix
function events.GameInitialized2()
	Game.Classes.HPFactor[const.Class.Minotaur]=6
	Game.Classes.HPFactor[const.Class.MinotaurLord]=12
end

------------
--ASSASSIN--
------------

assassinClass={const.Class.Thief,const.Class.Rogue,const.Class.Assassin,const.Class.Spy}

function events.GameInitialized2()
	function events.CalcDamageToMonster(t)
		local data = WhoHitMonster()
		if data and data.Player and table.find(assassinClass, data.Player.Class) then
			local pl=data.Player
			local spell=0
			if data and data.Object and data.Object.Spell then
				spell=data.Object.Spell
			end
			if assassinSpells[spell] then
				local baseDamage=pl:GetMeleeDamageMin()
				local maxDamage=pl:GetMeleeDamageMax()
				local randomDamage=math.random(baseDamage, maxDamage) + math.random(baseDamage, maxDamage)
				local damage=round(randomDamage/2)
				
				local isolatedDamageReduction=assassinationDamage(pl,t.Monster,data.Object) --must be subtracted
				damage=damage-isolatedDamageReduction
				
				critChance, critMult, success=getCritInfo(pl,false,getMonsterLevel(t.Monster))
				if success then
					damage=damage*critMult
					crit=true
				end
				
				for i=0,1 do
					local it=pl:GetActiveItem(i)
					if it then
						local damage1=calcFireAuraDamage(pl, it, 0, false, false, "damage")
						local damage2=calcEnchantDamage(pl, it, 0, false, false, "damage")
						damage=damage+damage1+damage2
					end
				end
				
				local res=t.Monster.Resistances[t.DamageKind] or t.Monster.Resistances[4]
				damage=damage/2^(res%1000/100)
				local mult=damageMultiplier[t.PlayerIndex]["Melee"]
				t.Result=damage*mult
				
				if pl.Weak>0 then
					t.Result=t.Result*0.5
				end
				
				if assassinSpells[spell].DamageMult then
					t.Result=t.Result*assassinSpells[data.Object.Spell].DamageMult
					if spell==44 then
						local res=t.Monster.Resistances[3]%1000
						t.Result=t.Result/2^(res/100)
					end
				end
			end
		end
	end
	
end


function assassinationDamage(pl,mon,obj)
	local id=pl:GetIndex()
	vars.assassinDamage=vars.assassinDamage or {}
	vars.assassinDamage[id]=vars.assassinDamage[id] or 0
	vars.assassinStacks=vars.assassinStacks or {}
	vars.assassinStacks[id]=vars.assassinStacks[id] or 0
	
	local s,m=SplitSkill(pl:GetSkill(const.Skills.Fire))
	local restoreChance=0.1+s*0.01
	local manaCost=50-m*5
	
	if obj and obj.Spell>0 and obj.Spell<100 then
		restoreChance=0
		manaCost=0
	end
	
	if obj then
		restoreChance=restoreChance/2
		manaCost=manaCost/2
	end
	if restoreChance>math.random() then
		pl.SP=math.min(pl:GetFullSP(),pl.SP+15)
	end
	RunNextTick(function()
		if mon.HP<=0 then
			s,m=SplitSkill(pl:GetSkill(const.Skills.Air))
			local fullSP=pl:GetFullSP()
			pl.SP=math.min(fullSP, pl.SP+(1+m)*5)
			vars.assassinStacks[id]=math.min(vars.assassinStacks[id]+1,5)
		end
	end)
	if pl.SP>=manaCost and mon.ShowAsHostile then
		if obj and obj.Spell>100 then
			vars.assassinStacks[id]=math.min(vars.assassinStacks[id]+0.5,5)--arrow nerf
			vars.AttackSpeedStack=vars.AttackSpeedStack or {}
			vars.AttackSpeedStack[id]=vars.AttackSpeedStack[id] or 0
			vars.AttackSpeedStack[id]=math.min(vars.AttackSpeedStack[id] + 0.5, 5)
			vars.AttackSpeedStackDecay=vars.AttackSpeedStackDecay or {}
			vars.AttackSpeedStackDecay[id]=vars.AttackSpeedStackDecay[id] or {}
			vars.AttackSpeedStackDecay[id]=Game.Time+const.Minute*4
		elseif not obj then
			vars.assassinStacks[id]=math.min(vars.assassinStacks[id]+1,5)
			vars.AttackSpeedStack=vars.AttackSpeedStack or {}
			vars.AttackSpeedStack[id]=vars.AttackSpeedStack[id] or 0
			vars.AttackSpeedStack[id]=math.min(vars.AttackSpeedStack[id] + 1, 5)
			vars.AttackSpeedStackDecay=vars.AttackSpeedStackDecay or {}
			vars.AttackSpeedStackDecay[id]=vars.AttackSpeedStackDecay[id] or {}
			vars.AttackSpeedStackDecay[id]=Game.Time+const.Minute*4
		end
		local damage=vars.assassinDamage[id]
		local monsters=0
		for i=0,Map.Monsters.High do
			local mapMon=Map.Monsters[i]
			if mapMon.AIState~=11 and mapMon.AIState~=5 and getDistances(mon,mapMon)<384 then
				monsters=monsters+1
			end
		end
		local damageMult=math.min(0.8,(monsters-1)*0.2)
		if obj then
			damage=damage/2
		end
		pl.SP=pl.SP-manaCost
		
		damage=damage*damageMult
		return damage
	end
	return vars.assassinDamage[id]	
end

function assassinSkills(isAssassin, pl)
	if isAssassin then
		if pl then
			for key, value in pairs(assassinSpells) do
				local id=pl:GetIndex()
				if vars.assassinStacks[id]<assassinSpells[key].StackCost then
					for i=1,4 do
						Game.Spells[key]["SpellPoints" .. masteryName[i]]=1000
					end
				else
					for i=1,4 do
						Game.Spells[key]["SpellPoints" .. masteryName[i]]=assassinSpells[key].Cost
					end
				end
			end
		end
		--skill names and desc
		
		Skillz.setName(12, "전투")
		Skillz.setName(13, "기민함")
		Skillz.setName(14, "독")
		Skillz.setName(15, "암살")
		
		Skillz.setDesc(12,1,"전투 기술은 에너지 회복을 강화하여 장기전에 버틸 수 있게 합니다.\n\n공격할 때마다 기본 10%에 기술 포인트당 1%를 더한 확률로 에너지 15를 회복합니다.\n\n");
		Skillz.setDesc(13,1,"교묘함은 삶과 죽음의 경계를 다루어 적을 처치할 때 에너지를 얻고 속도를 높입니다.\n\n에너지를 소모하는 공격은 중첩 1회를 부여하며, 중첩당 교묘함 기술 포인트마다 공격 속도가 1% 증가합니다. 최대 5회 중첩됩니다.\n\n");
		Skillz.setDesc(14,1,"독은 스스로 독을 시험하며 독성을 다루는 법을 익혀 고통을 활력으로 바꾸는 기술입니다. 기술 레벨이 높을수록 에너지 재생이 증가합니다.\n\n공격할 때마다 기술 포인트당 대상 생명력의 0.1%에 해당하는 추가 물 피해를 줍니다.\n\n");
		Skillz.setDesc(15,1,"암살은 고립된 대상을 반응하기 전에 제거하는 데 특화된 기술입니다. 에너지를 소모하는 공격이나 주문은 기술 포인트당 피해가 4-6-8-10 증가하지만, 대상 주변의 적 하나당 효과가 20% 감소합니다(최대 4명).\n이런 공격은 콤보 포인트 1을 부여하여 암살자가 공격 주문을 사용할 수 있게 합니다.\n활 공격은 50% 확률로 적용되며 에너지를 소모합니다.\n\n기술 레벨이 높을수록 시작 에너지도 증가하여 짧은 전투에서 강력한 순간 화력을 내기 좋습니다.\n\n");

		
		Skillz.setDesc(12,2,"근접 공격에 에너지 45를 소모합니다")
		Skillz.setDesc(13,2,"몬스터 처치 시 에너지 10을 회복합니다")
		Skillz.setDesc(14,2,"초당 에너지 8을 회복합니다")
		Skillz.setDesc(15,2,"최대 에너지가 10 증가합니다")
		
		Skillz.setDesc(12,3,"근접 공격에 에너지 40을 소모합니다")
		Skillz.setDesc(13,3,"몬스터 처치 시 에너지 15를 회복합니다")
		Skillz.setDesc(14,3,"초당 에너지 10을 회복합니다")
		Skillz.setDesc(15,3,"최대 에너지가 20 증가합니다")
		
		Skillz.setDesc(12,4,"근접 공격에 에너지 35를 소모합니다")
		Skillz.setDesc(13,4,"몬스터 처치 시 에너지 20을 회복합니다")
		Skillz.setDesc(14,4,"초당 에너지 12를 회복합니다")
		Skillz.setDesc(15,4,"최대 에너지가 30 증가합니다")
		
		Skillz.setDesc(12,5,"근접 공격에 에너지 30을 소모합니다")
		Skillz.setDesc(13,5,"몬스터 처치 시 에너지 25를 회복합니다")
		Skillz.setDesc(14,5,"초당 에너지 14를 회복합니다")
		Skillz.setDesc(15,5,"최대 에너지가 40 증가합니다")
		
		Game.SpellsTxt[6].Description=string.format("단일 대상에게 화염구를 발사합니다. 명중하면 폭발하여 주변 모두에게 피해를 주며, 너무 가까우면 파티원도 피해를 받습니다. 화염구는 근접 공격 피해의 %s%%만큼 피해를 줍니다.",assassinSpells[6].DamageMult*100)
		Game.SpellsTxt[7].Description=string.format("지면에 화염 가시를 설치합니다. 근처에 적이 다가오면 폭발하며, 맵을 떠나거나 발동할 때까지 유지됩니다. 화염 가시는 근접 공격 피해의 %s%%만큼 피해를 줍니다.",assassinSpells[7].DamageMult*100)
		Game.SpellsTxt[18].Description=string.format("번개 화살은 시전자의 손에서 대상 하나에게 전기를 방출합니다. 항상 명중하며 근접 공격 피해의 %s%%만큼 피해를 줍니다.\n\n그 후 번개가 두 번째 대상으로 튀어 추가로 명중합니다.",assassinSpells[18].DamageMult*100)
		Game.SpellsTxt[24].Description=string.format("파티 바로 앞의 몬스터에게 독을 분사합니다. 피해량은 낮지만 물 마법 저항을 가진 몬스터가 적어 대체로 효과적입니다. 각 분사는 근접 공격 피해의 %s%%만큼 피해를 줍니다.",assassinSpells[24].DamageMult*100)
		Game.SpellsTxt[29].Description=string.format("단일 대상에게 강한 부식성 산을 분사합니다. 항상 명중하며 근접 공격 피해의 %s%%만큼 피해를 줍니다.",assassinSpells[29].DamageMult*100)
		Game.SpellsTxt[34].Description=string.format("마법의 힘으로 괴물을 강타하여 기절에서 회복할 때까지 다른 행동을 하지 못하게 합니다. 또한 괴물을 조금 뒤로 밀쳐 도망칠 기회를 줍니다. 대지 마법 숙련도가 높을수록 효과가 강해집니다. 기절은 근접 공격 피해의 %s%%만큼 피해를 줍니다.",assassinSpells[34].DamageMult*100)
		Game.SpellsTxt[39].Description=string.format("회전하는 면도날처럼 얇은 금속 칼날을 몬스터 하나에게 발사합니다. 칼날은 근접 공격 피해의 %s%%만큼 피해를 줍니다.\n\n칼날은 물리 피해를 줄 수 있는 유일한 주문입니다.",assassinSpells[39].DamageMult*100)
		Game.SpellsTxt[44].Description=string.format("순간적으로 단일 대상의 무게를 엄청나게 늘려 내부 피해를 줍니다. 근접 공격 피해의 %s%%만큼 피해를 줍니다.",assassinSpells[44].DamageMult*100)
		
		Game.SpellsTxt[18].Expert="최대 2회 적중합니다"
		Game.SpellsTxt[18].Master="최대 3회 적중합니다"
		Game.SpellsTxt[18].GM="최대 4회 적중합니다"
		
		for key, value in pairs(assassinSpells) do
			if assassinSpells[key].StackCost>0 then
				Game.SpellsTxt[key].Description=Game.SpellsTxt[key].Description .. "\n\n이 능력을 사용하려면 " .. assassinSpells[key].StackCost .. " 콤보 포인트가 필요합니다."
			end
		end
		
	else
		for i=1,5 do
			for key, value in pairs(baseSchoolsTxtAssassin[i]) do
				Skillz.setDesc(key,i,value)
			end
		end
		for key, value in pairs(spellDesc2) do
			for key2, value2 in pairs(value) do
				Game.SpellsTxt[key][key2]=value2
			end
		end
		Skillz.setName(12, "화염 마법")
		Skillz.setName(13, "공기 마법")
		Skillz.setName(14, "물 마법")
		Skillz.setName(15, "대지 마법")
	end
end
function events.CanLearnSpell(t)
	if table.find(assassinClass, t.Player.Class) then
		t.NeedMastery = 5
	end
end

function events.GameInitialized2()
	local sp=const.Spells
	assassinSpells={
		[sp.TorchLight]={["Cost"]=1,["StackCost"]=0,["DamageMult"]=0,},
		[sp.FireAura]={["Cost"]=0,["StackCost"]=0,["DamageMult"]=0,},
		[sp.Haste]={["Cost"]=0,["StackCost"]=0,["DamageMult"]=0,},
		[sp.Fireball]={["Cost"]=0,["StackCost"]=5,["DamageMult"]=1,},
		[sp.FireSpike]={["Cost"]=0,["StackCost"]=3,["DamageMult"]=2.5,},
		
		[sp.WizardEye]={["Cost"]=1,["StackCost"]=0,["DamageMult"]=0,},
		[sp.Jump]={["Cost"]=5,["StackCost"]=0,["DamageMult"]=0,},
		[sp.Shield]={["Cost"]=0,["StackCost"]=0,["DamageMult"]=0,},
		[sp.LightningBolt]={["Cost"]=0,["StackCost"]=5,["DamageMult"]=1.5,},
		[sp.Invisibility]={["Cost"]=15,["StackCost"]=0,["DamageMult"]=0,},
		[sp.Fly]={["Cost"]=25,["StackCost"]=0,["DamageMult"]=0,},
		
		[sp.PoisonSpray]={["Cost"]=0,["StackCost"]=3,["DamageMult"]=0.75,},
		[sp.WaterWalk]={["Cost"]=0,["StackCost"]=0,["DamageMult"]=0,},
		[sp.AcidBurst]={["Cost"]=0,["StackCost"]=3,["DamageMult"]=3,},
		[sp.TownPortal]={["Cost"]=20,["StackCost"]=0,["DamageMult"]=0,},
		[sp.LloydsBeacon]={["Cost"]=30,["StackCost"]=0,["DamageMult"]=0,},
		
		[sp.Stun]={["Cost"]=0,["StackCost"]=3,["DamageMult"]=1.5,},
		[sp.StoneSkin]={["Cost"]=0,["StackCost"]=0,["DamageMult"]=0,},
		[sp.Blades]={["Cost"]=0,["StackCost"]=3,["DamageMult"]=3},
		[sp.Telekinesis]={["Cost"]=0,["StackCost"]=0,["DamageMult"]=0,},
		[sp.MassDistortion]={["Cost"]=0,["StackCost"]=4,["DamageMult"]=4,},
	}				
end

assassinSpellList={
	[const.Skills.Fire]={1, 4, 5, 6, 7},
	[const.Skills.Air]={12, 17, 16, 18, 21, 19},
	[const.Skills.Water]={24, 27, 29, 31, 33},
	[const.Skills.Earth]={34, 38, 39, 42, 44},
}

function events.Action(t)
	if t.Action==105 and Game.CurrentPlayer>=0 and Game.CurrentPlayer<=Party.High then
		
		pl=Party[Game.CurrentPlayer]
		if table.find(assassinClass, pl.Class) then
			for i=1,99 do
				pl.Spells[i]=false
			end
			local s1, m1=SplitSkill(pl.Skills[const.Skills.Fire])
			local s2, m2=SplitSkill(pl.Skills[const.Skills.Air])
			local s3, m3=SplitSkill(pl.Skills[const.Skills.Water])
			local s4, m4=SplitSkill(pl.Skills[const.Skills.Earth])
			m1=m1+1
			m2=m2+2
			m3=m3+1
			m4=m4+1
			for i=1, m1 do
				pl.Spells[assassinSpellList[const.Skills.Fire][i]]=true
			end
			for i=1, m2 do
				pl.Spells[assassinSpellList[const.Skills.Air][i]]=true
			end
			for i=1, m3 do
				pl.Spells[assassinSpellList[const.Skills.Water][i]]=true
			end
			for i=1, m4 do
				pl.Spells[assassinSpellList[const.Skills.Earth][i]]=true
			end
		end
	end
end

--show stacks
function events.GameInitialized2()
	assassinStacks={}
	for i=0,4 do
		assassinStacks[i]=CustomUI.CreateText{
			Text = "",
			Layer 	= 1,
			Screen 	= 0,
			X = 5+i*96, Y = 387
		}
	end
end

function events.Tick()
	for i=0,Party.High do
		local pl=Party[i]
		if table.find(assassinClass,pl.Class) then
			local id=pl:GetIndex()
			vars.assassinStacks=vars.assassinStacks or {}
			vars.assassinStacks[id]=vars.assassinStacks[id] or 0
			assassinStacks[i].Text=string.format(math.floor(vars.assassinStacks[id]))
		else
			assassinStacks[i].Text=""
		end
	end
end

function events.PlayerCastSpell(t)
	local pl=t.Player
	if table.find(assassinClass,pl.Class) then
		if assassinSpells[t.SpellId] and assassinSpells[t.SpellId].StackCost>0 then 
			local id=pl:GetIndex()
			if vars.assassinStacks[id]<assassinSpells[t.SpellId].StackCost then
				t.Handled=true
				DoGameAction(23,0,0)
			else
				vars.assassinStacks[id]=vars.assassinStacks[id]-assassinSpells[t.SpellId].StackCost
			end
		end
	end
end
--spells speed depends on weapon
function GetAssassinSpellDelay(pl,spell)
	return pl:GetAttackDelay()*2
end
--CastQuickSpell(0,6)
--[[spells
fire spike fire aura fireball haste
invisibility chain lightning jump shield
poison spray, town portal, lloyd, acid burst
stun stoneskin blades mass distorsion

combat - attack speed on skill
subtlety - i0.5% chance to dodge an incoming attack
poison - %HP water damage on energy attack
assassination - adds flat damage (scaling with weapon skill) on isolated targets on skill (damage decreases depending on the number of targets in the nearby)
]]
function events.BeforeLoadMap()
	if not vars.LichFix then
		for i=0, Party.High do
			local pl=Party[i]
			if pl.Class==const.Class.Lich and pl.LevelBase==1 then
				pl.Class=const.Class.Necromancer
			end
		end
		vars.LichFix=true
	end
end
