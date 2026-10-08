--Per-class data, runtime and handler bodies live in
--Scripts/Modules/MawCore/Classes.lua (see MawCore/NOTES.md).
--What stays here: promotions, seraph, dragon, shaman, and the one-line
--registration stubs that must keep their position in the handler chain.
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
--class id lists + the presentation dispatcher: MawCore/Classes.lua

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
				local s=SplitSkill(pl.Skills[const.Skills.Sword])
				if txt.EquipStat==1 and txt.Skill==1 then
					txt.EquipStat=0
--Novice for this action only: the now-one-handed sword must not go offhand
					tempSkillForEquip(pl, const.Skills.Sword, s, 1)
					RunNextTick(function()
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

--base school texts for the tooltip builders, captured before the later
--init handlers append to them (SKILL_TOOLTIPS.md)
MawSchoolDescBase={}
function events.GameInitialized2()
	for id=12,20 do
		MawSchoolDescBase[id]=Skillz.getDesc(id,1)
	end
end


----------------------------------
-- DRAGON REWORK
----------------------------------
--data and formulas live in MawCore/Classes.lua, with the handlers that use them

function events.GameInitialized2()
	local dragonFang, dragonBreath, dragonScales =
		MawCore.Classes.dragonFang, MawCore.Classes.dragonBreath, MawCore.Classes.dragonScales
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
	--skill text: one row per mastery from the dragonFang/dragonScales tables
	local function fangRow(m)
		return string.format("      %s|     %s|",dragonFang.Attack[m],dragonFang.Damage[m])
	end
	local function scaleRow(m)
		return string.format("  %s|    %s",dragonScales.AC[m],dragonScales.Resistances[m])
	end
	fangsNormal,fangsExpert,fangsMaster,fangsGM=fangRow(1),fangRow(2),fangRow(3),fangRow(4)
	scalesNormal,scalesExpert,scalesMaster,scalesGM=scaleRow(1),scaleRow(2),scaleRow(3),scaleRow(4)

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

function mawTick_DragonCharScreen()
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
		Skillz.setName(32,"비늘")
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
		Skillz.setName(32,"회피")
	end
end

function events.GameInitialized2()
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

function mawTick_MonsterPush()
	local push=MawCore.DamageState.getPushes()
	for i=1, #push do
		if push[i].duration>0 then
			push[i].duration=push[i].duration-1
			if MawCore.Sync.drivesMonster(push[i].id) then
				mon=Map.Monsters[push[i].id]
				mon.VelocityX=push[i].directionX * push[i].currentForce
				mon.VelocityY=push[i].directionY * push[i].currentForce
				mon.VelocityZ=push[i].currentForce/2 - push[i].totalForce/4
			end
			push[i].currentForce=push[i].currentForce - push[i].totalForce / push[i].totalDuration
		end
	end
end


---------------------------------------
--SHAMAN
---------------------------------------
function events.GameInitialized2()
	Game.ClassDescriptions[59] = "주술사는 마법 지식으로 무예를 강화하는 신비한 전사입니다.\n기술 메뉴의 마법 계열 설명에서 다음 수치를 확인할 수 있습니다.\n - 각 마법 계열은 고유한 보너스를 제공합니다. 여러 계열에 분산 투자하는 것과 한 계열에 집중하는 것 모두 장점이 있습니다.\n - 공기 기술 포인트마다 받는 피해를 일정 비율 감소시키며, 효과는 레벨에 따라 감소합니다.\n - 물 기술 포인트마다 받는 피해를 고정 수치로 감소시킵니다. 따라서 약한 적을 상대하거나 이미 방어력이 높은 경우 물이 더 효과적입니다.\n - 영혼 기술 포인트마다 치유량과 주문 피해가 일정 비율 증가합니다.\n - 화염은 몬스터의 현재 생명력에 비례한 화염 피해를 주며 저항을 일부 관통합니다. 보스 처치에 특화됩니다.\n - 대지 기술 포인트마다 근접 피해가 고정 수치로 증가합니다.\n - 육체 기술 포인트마다 고정 수치만큼 치유합니다.\n - 정신 기술 포인트마다 고정 수치만큼 마나를 회복합니다."
end


function events.GameInitialized2()
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


---------------------------------------
--DEATH KNIGHT
---------------------------------------
function events.GameInitialized2()
	Game.ClassDescriptions[56] = "이 직업은 사악한 힘과 강인한 육체를 결합해 강력하면서도 다재다능합니다.\n 냉기/혈기/부정 기술을 전문가/마스터/그랜드마스터로 올리면 새로운 주문을 자동으로 해금합니다. 단, 죽음의 기사는 주문서로 주문을 배울 수 없습니다.\n\n냉기:\n\n초보/마스터/그랜드마스터 단계에서 피해가 각각 1/2/3 증가하며, 투자한 기술 포인트마다 공격 속도가 1% 증가합니다.\n\n혈기:\n\n생존력을 강화해 기술 포인트당 받는 물리 피해를 1% 감소시킵니다. 또한 공격에 생명력 흡수 효과를 부여해 준 피해의 일부를 생명력으로 회복합니다.\n\n부정:\n\n초보/마스터/그랜드마스터 단계에서 피해가 각각 1/2/3 증가하며, 투자한 기술 포인트마다 받는 마법 피해가 1% 감소합니다."
end
--skills
--death grip

--runic power

--change spell cost to personalized value:

--spells

--body: MawCore/Classes.lua; registration kept here for handler order
function events.Action(t)
	MawCore.Classes.dkSpellbook(t)
end

--body: MawCore/Classes.lua; registration kept here for handler order
function events.CanLearnSpell(t)
	MawCore.Classes.dkLearnSpell(t)
end


--tooltips
function events.GameInitialized2()
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


function events.GameInitialized2()
	Game.ClassDescriptions[62] = "원소술사는 마나가 가장 많은 마법사이며, 책 대신 같은 원소 계열의 주문을 시전하여 주문을 배웁니다. 승천 기술은 배울 수 없으며, 승천 레벨은 원소 마법 기술 레벨 합계의 4분의 1입니다. 기본 주문 회복 시간이 50% 길지만, 마법을 시전하면 중첩을 얻어 다음 효과가 증가합니다:\n\n주문 피해: 중첩당 10%\n주문 회복 속도: 중첩당 5%\n마나 비용: 승천 보정을 적용하기 전 기본 비용에 +1, 총비용에 +7.5%.\n\n몇 초 동안 시전하지 않으면 중첩이 50% 감소합니다. 활이나 근접 무기로 피해를 가하거나 주문서에서 시전하면 집중이 깨져 모든 중첩이 즉시 초기화됩니다.\n\n주문은 무작위로 시전되지만 단일 대상, 범위, 산탄의 세 유형으로 나뉩니다. 선택한 빠른 시전 주문에 따라 순환이 조정됩니다. 예를 들어 화염구를 빠른 시전 주문으로 지정하면 범위 주문을 우선합니다."
	Game.Classes.HPFactor[63]=2.5
end

--body: MawCore/Classes.lua; registration kept here for handler order
function events.CanLearnSpell(t)
	MawCore.Classes.eleLearnSpell(t)
end

--body: MawCore/Classes.lua; registration kept here for handler order
function events.Action(t)
	MawCore.Classes.eleSpellbook(t)
end


--body: MawCore/Classes.lua; registration kept here for handler order
function events.PlayerCastSpell(t)
	MawCore.Classes.eleCastRotation(t)
end


--reset stacks when casting from spellbook
--body: MawCore/Classes.lua; registration kept here for handler order
function events.Action(t)
	MawCore.Classes.eleBindQuick(t)
end

--set current keybind by keybindrotation
--body: MawCore/Classes.lua; registration kept here for handler order
function events.Action(t)
	MawCore.Classes.eleBindScreen(t)
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


function checkSkills(id)
	MawCore.Classes.present(id)
end
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


function events.GameInitialized2()
	
end

--body: MawCore/Classes.lua; registration kept here for handler order
function events.CanLearnSpell(t)
	MawCore.Classes.assassinLearnSpell(t)
end


--body: MawCore/Classes.lua; registration kept here for handler order
function events.Action(t)
	MawCore.Classes.assassinSpellbook(t)
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

--body: MawCore/Classes.lua; registration kept here for handler order
function events.PlayerCastSpell(t)
	MawCore.Classes.assassinCastStacks(t)
end
--spells speed depends on weapon
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

--Tick handlers above run as MawCore scheduler tasks (ms; 0=frame, -1=poke only)
function events.GameInitialized2()
	local every=MawCore.Scheduler.every
	every("classes/dragon-charscreen", 100, mawTick_DragonCharScreen)
	every("classes/monster-push", 0, mawTick_MonsterPush)
	every("classes/elementalist-stacks", 100, mawTick_ElementalistStacks)
	every("classes/assassin-stacks", 100, mawTick_AssassinStacks)
end
