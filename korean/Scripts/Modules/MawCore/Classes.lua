-- Classes.lua -- the custom class registry: which class ids belong to each
-- Maw class, and how a class swaps its presentation (skill names, spell
-- texts, mana costs) when a character is selected.
--
-- The class id lists are published as the legacy globals the rest of the mod
-- reads (seraphClass, dkClass, ...), so this table is their one source.
-- See NOTES.md.

local Classes = {}
MawCore.Classes = Classes

------------------------------------------------------------------------
-- Death Knight data
-- spRegen and DKDamageMult are read by the damage pipeline too.
------------------------------------------------------------------------

spRegen={
	[56]=10,
	[57]=15,
	[58]=20,
}

DKDamageMult={
	[26]={1,1,1.2,1.2,["Skill"]=14},
	[29]={1.5,1.5,1.5,2,["Skill"]=14},
	[32]={0.75,0.75,0.75,0.75,["Skill"]=14},
	[76]={1.1,1.1,1.1,1.4,["Skill"]=18},
	[90]={1,1,1,1.2,["Skill"]=20},
	[97]={0.6,0.6,0.6,0.6,["Skill"]=20},
}

DKSpellList={
	[const.Skills.Water]={26, 27, 29, 32},
	[const.Skills.Body]={68, 71, 76, 74},
	[const.Skills.Dark]={91, 90, 96, 97},
}

------------------------------------------------------------------------
-- Elementalist data
-- spellRequirements is read by the damage pipeline and SkillTooltip.
------------------------------------------------------------------------

spellRequirements={0,0,500,1500,5000,10000,20000,40000,80000,160000,320000}

eleOffSpellsOut={2,6,7,9,11,
				15,18,20,22,
				24,26,29,32,
				37,39,41,43,44}

eleOffSpellsIn={2,6,7,10,11,
				15,18,20,
				24,26,29,32,
				37,39,41,44}

singleTarget={2,11,20,26,29,37,39}

shotGun={2,15,24,37}

aoeIn={6,10,18,32,41}

aoeOut={6,9,18,22,32,41,43}

------------------------------------------------------------------------
-- Assassin data
-- assassinSpellList is read by zzMaw-Spells' tooltip pass.
------------------------------------------------------------------------

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

assassinSpellList={
	[const.Skills.Fire]={1, 4, 5, 6, 7},
	[const.Skills.Air]={12, 17, 16, 18, 21, 19},
	[const.Skills.Water]={24, 27, 29, 31, 33},
	[const.Skills.Earth]={34, 38, 39, 42, 44},
}

------------------------------------------------------------------------
-- Presentation swaps, verbatim from zzClasses. dkSkills/assassinSkills
-- stay global: zzMaw-Spells' ascension() calls them directly.
------------------------------------------------------------------------

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
Classes.DKManaCost = DKManaCost	--the damage pipeline charges the per-hit ones

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
		
		local FHP=pl:GetFullHP()
		local leech=MawCore.Formulas.bloodLeech
		Game.SpellsTxt[68].Name="피 흡수"
		Game.SpellsTxt[68].Description="이 주문을 활성화하면 기사의 몸에 피의 힘을 부여하여 공격할 때마다 생명력을 흡수합니다. 주문력 6을 소모합니다."
		Game.SpellsTxt[68].Normal="생명력 흡수: " .. round(leech(FHP, bloodS, 1)) .. " 생명력"
		Game.SpellsTxt[68].Expert="생명력 흡수: " .. round(leech(FHP, bloodS, 2)) .. " 생명력"
		Game.SpellsTxt[68].Master="생명력 흡수: " .. round(leech(FHP, bloodS, 3)) .. " 생명력"
		Game.SpellsTxt[68].GM="생명력 흡수: " .. round(leech(FHP, bloodS, 4)) .. " 생명력"
		
		-- Spell 74: Superior Blood Leech
		Game.SpellsTxt[74].Name="상급 피 흡수"
		Game.SpellsTxt[74].Description="이 주문을 활성화하면 기사의 본질에 피의 힘을 부여하여 공격할 때 더 많은 생명력을 흡수합니다. 주문력 12를 소모합니다."
		Game.SpellsTxt[74].Master="n/a"
		Game.SpellsTxt[74].GM="생명력 흡수: " .. round(leech(FHP, bloodS, 4) * 2) .. " 생명력"
		
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
		Game.SpellsTxt[96].Description=string.format("이 주문을 활성화하면 기사의 몸에 어둠의 힘이 깃듭니다. 근접 공격이 명중할 때마다 주문력을 %d 소모하며, 대상이 주는 피해를 %d%% 감소시킵니다. 효과는 %g초 동안 지속되며 명중할 때마다 갱신됩니다.",
			DKManaCost[96],
			round((1 - MawCore.Damage.monsterDamageDebuff[const.MonsterBuff.DamageHalved])*100),
			MawCore.Damage.dkGraspDuration/const.Minute*MawCore.Formulas.gameMinuteSeconds)
		Game.SpellsTxt[96].Expert="n/a"
		Game.SpellsTxt[96].Master="추가 효과 없음"
		Game.SpellsTxt[96].GM="대상은 원거리 공격도 할 수 없게 됩니다"
		
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
	else
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

local function elementalistSkills(isElementalist, id)
	if isElementalist then
		local pl=Party[id]
		vars.elementalistSpells=vars.elementalistSpells or {}
		vars.elementalistSpells[pl:GetIndex()]=vars.elementalistSpells[pl:GetIndex()] or {}
		for i=12,15 do
			vars.elementalistSpells[pl:GetIndex()][i]=vars.elementalistSpells[pl:GetIndex()][i] or 0
		end
	end
	-- school progression tooltips (12-15 part 5) moved to SkillTooltip builders (SKILL_TOOLTIPS.md)
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

------------------------------------------------------------------------
-- Per-class runtime. Globals: the damage pipeline calls
-- assassinationDamage, zzMaw-Stats calls GetAssassinSpellDelay, and
-- zzClasses' own handlers + scheduler registrations call the rest.
------------------------------------------------------------------------

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

function mawTick_ElementalistStacks()
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

function mawTick_AssassinStacks()
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

function GetAssassinSpellDelay(pl,spell)
	return pl:GetAttackDelay()*2
end

------------------------------------------------------------------------
-- Per-class UI/spell handlers. Bodies verbatim; the events.X
-- registrations STAY in zzClasses as one-line stubs so the handler
-- order within each event chain is untouched (NOTES.md).
------------------------------------------------------------------------

function Classes.dkSpellbook(t)
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

function Classes.dkLearnSpell(t)
	if table.find(dkClass, t.Player.Class) then
		t.NeedMastery = 5
	end
end

function Classes.eleLearnSpell(t)
	if table.find(elementalistClass, t.Player.Class) then
		t.NeedMastery = 5
		Game.ShowStatusText("원소술사는 실전을 통해 주문을 익힙니다")
	end
end

function Classes.eleSpellbook(t)
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

function Classes.eleCastRotation(t)
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

function Classes.eleBindQuick(t)
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

function Classes.eleBindScreen(t)
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

function Classes.assassinLearnSpell(t)
	if table.find(assassinClass, t.Player.Class) then
		t.NeedMastery = 5
	end
end

function Classes.assassinSpellbook(t)
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

function Classes.assassinCastStacks(t)
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

-- Registration order is the reset order in present() -- same order the
-- legacy checkSkills used. `present` is nil for classes whose presentation
-- is handled elsewhere (seraph/shaman tooltips are builders now; dragons
-- swap from their own Tick because they are a RACE, not a class group).
Classes.List = {
	{name = "seraph",       global = "seraphClass",       ids = {53, 54, 55}},
	{name = "shaman",       global = "shamanClass",       ids = {59, 60, 61}},
	{name = "dk",           global = "dkClass",           ids = {56, 57, 58},
		present = function(on, id) dkSkills(on, id) end},
	{name = "elementalist", global = "elementalistClass", ids = {62, 63, 64},
		present = function(on, id) elementalistSkills(on, id) end},
	{name = "assassin",     global = "assassinClass",
		ids = {const.Class.Thief, const.Class.Rogue, const.Class.Assassin, const.Class.Spy},
		present = function(on, id) assassinSkills(on, on and Party[id] or nil) end},
}

local byName = {}
for _, c in ipairs(Classes.List) do
	byName[c.name] = c
	_G[c.global] = c.ids		-- the 60+ legacy table.find(xxxClass, ...) readers
end

-- MawCore.Classes.is(pl, "dk")
function Classes.is(pl, name)
	local c = byName[name]
	return c ~= nil and table.find(c.ids, pl.Class) ~= nil
end

-- the registered class a player belongs to, or nil
function Classes.of(pl)
	for _, c in ipairs(Classes.List) do
		if table.find(c.ids, pl.Class) then
			return c
		end
	end
end

-- Reset every class presentation, then apply the one this character needs.
-- The legacy contract, kept: reset all -> adjustSpellTooltips -> apply one.
function Classes.present(id)
	for _, c in ipairs(Classes.List) do
		if c.present then
			c.present(false, id)
		end
	end
	adjustSpellTooltips()
	if id >= 0 and id <= Party.High then
		local c = Classes.of(Party[id])
		if c and c.present then
			c.present(true, id)
		end
	end
end

function Classes.describe()
	local out = {"classes:"}
	for _, c in ipairs(Classes.List) do
		out[#out + 1] = ("  %-13s %-18s ids %s%s"):format(
			c.name, c.global, table.concat(c.ids, ","),
			c.present and "" or "   (no presentation swap)")
	end
	return table.concat(out, "\n")
end


------------------------------------------------------------------------
-- Dragon data and formulas. These moved here with the dragon handlers in
-- Classes.start(): they were file-scope LOCALS of zzClasses, so the handlers
-- lost the binding when they moved and every dragon row read nil. The three
-- tables are published on Classes because zzClasses' skill-description
-- builder still prints them.
------------------------------------------------------------------------

local dragonFang={
	["Attack"]={2,3,4,5,[0]=0},
	["Damage"]={4,6,8,10,[0]=0},
}
local dragonBreath={
	["Damage"]={3,4,5,6,[0]=0},
}
local dragonScales={
	["AC"]={2,3,3,4,[0]=0},
	["Resistances"]={1,1,2,3,[0]=0},
}
Classes.dragonFang, Classes.dragonBreath, Classes.dragonScales = dragonFang, dragonBreath, dragonScales

--shared dragon formulas (min/max rows differ only by the spread mult)
local dragonRecoveryPerSkill=0.015
local function dragonEffLevel(pl)
	local bolster=getPartyLevel(4)+1
	local lvl=pl.LevelBase
	if pl.LevelBase/bolster>1.2 then
		lvl=math.min(pl.LevelBase/2,bolster)
	end
	local cap=600
	if vars.madnessMode then
		cap=900
	end
	return math.min(lvl,cap)
end
local function dragonFangDamage(pl, mult)
	local s, m = SplitSkill(pl:GetSkill(const.Skills.Unarmed))
	local might=pl:GetMight()
	local mightEffect=Game.GetStatisticEffect(might)
	local bonus= (1 + (dragonFang.Damage[m]) * s / 100)  * (dragonEffLevel(pl) * 2 +30)
	return round((bonus*(1+might/1000)+(mightEffect*might/1000))*mult*(1+s*dragonRecoveryPerSkill))
end
local function dragonBreathDamage(pl, mult)
	local s, m = SplitSkill(pl:GetSkill(const.Skills.DragonAbility))
	local might=pl:GetMight()
	local mightEffect=Game.GetStatisticEffect(might)
	local baseDamage=(1 + dragonBreath.Damage[m] * s / 100) * (20 + 2 * dragonEffLevel(pl)) + mightEffect
	return round(baseDamage*(1+might/1000)*mult*(1+s*dragonRecoveryPerSkill))
end

function Classes.start()
	--the dragon/DK engine-event handlers. Legacy nested these in
	--zzClasses' GameInitialized2 to register them after all the
	--file-scope handlers; registering from here keeps that intent
	--and lands them later still. Order among them preserved; all
	--tier-3 peers are disjoint by class/race gates (NOTES.md).
	function events.GameInitialized2()
	function events.CalcStatBonusByItems(t)
		if Game.CharacterPortraits[t.Player.Face].Race~=const.Race.Dragon then return end
		--melee
		if t.Stat==27 then --min damage
			t.Result=dragonFangDamage(t.Player, 0.75)
		elseif t.Stat==28 then --max damage
			t.Result=dragonFangDamage(t.Player, 1.25)
		elseif t.Stat==25 then --attack
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.Unarmed))
			local bonus= (dragonFang.Attack[m]) * s +10
			t.Result=t.Result+bonus 
			
		end
		--breath
		if t.Stat==31 then --min damage
			t.Result=dragonBreathDamage(t.Player, 0.75)
		elseif t.Stat==32 then --max damage
			t.Result=dragonBreathDamage(t.Player, 1.25)

		--AC
		elseif t.Stat==9 then
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.Dodging))
			local oldDodge=skillAC[const.Skills.Dodging][m] or 0
			local bonus= (1 + dragonScales.AC[m]/100 * s) * (dragonEffLevel(pl)+40) - (s * oldDodge)
			t.Result=t.Result+bonus
		elseif t.Stat>=10 and t.Stat<=15 then
			local pl=t.Player
			local s, m = SplitSkill(pl:GetSkill(const.Skills.Dodging))
			local bonus= (dragonScales.Resistances[m]/100 * s) * (dragonEffLevel(pl)+40)
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
				t.Result=t.Result * (1+dragonRecoveryPerSkill*s)
				useBreathCooldown=false
			else
				local s, m = SplitSkill(t.Player:GetSkill(const.Skills.Unarmed))
				t.Result=t.Result * (1+dragonRecoveryPerSkill*s)
			end
		end	
	end

	function events.PlaySound(t)
		if t.Sound==18080 then
			useBreathCooldown=true
		end
	end

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
end