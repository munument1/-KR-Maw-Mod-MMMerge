-- ne pas créer de globales ni de tables à l'avance
map_data_reset_confirmation = map_data_reset_confirmation or 0

-- --- SAFETY SHIM: ne change pas l'équilibrage
if not rawget(_G, "safeGetMonsterLevel") then
  function safeGetMonsterLevel(mon)
    if type(getMonsterLevel) == "function" then
      return getMonsterLevel(mon)  -- logique d'origine
    end
    return (mon and mon.Level) or 0  -- fallback neutre
  end
end

local function ensureDamageTrackIfMapvars()
  if not mapvars then return false end
  mapvars.damageTrack       = mapvars.damageTrack       or {}
  mapvars.damageTrackRanged = mapvars.damageTrackRanged or {}
  return true
end

function events.KeyDown(t)
  if Game.CurrentScreen == 7 and Game.CurrentCharScreen == 100 then
    if t.Key == 82 then -- "R"
      Game.ShowStatusText("맵 데이터 초기화 완료. 계속하려면 Y를 누르세요...")
      map_data_reset_confirmation = 1
    end

    if (t.Key ~= 89) and (t.Key ~= 82) and (map_data_reset_confirmation == 1) then
      map_data_reset_confirmation = 0
    end

    if t.Key == 89 and (map_data_reset_confirmation == 1) then -- "Y"
      map_data_reset_confirmation = 0
      pcall(function()
        if ensureDamageTrackIfMapvars() and Party and Party.High then
          for i = 0, Party.High do
            local p = Party[i]
            if p and p.GetIndex then
              local idx = p:GetIndex()
              mapvars.damageTrack[idx] = 0
              mapvars.damageTrackRanged[idx] = 0
            end
          end
        end
      end)
      Game.ShowStatusText("현재 맵 데이터를 초기화했습니다.")
    end
  end
end


AXE_CRIT_DAMAGE_PER_SKILL = 0.01

function MawReferenceLevel()
	if not vars.MMLVL then
		return 0
	end
	return round(getTotalLevel())
end

function getCritInfo(pl, dmgType, monLvl)
	if not pl then return 0, 1, false end
	monLvl = monLvl or MawReferenceLevel()

	local F = MawCore.Formulas
	local luck = pl.GetLuck and pl:GetLuck() or 0
	local totalCrit = F.critChance(luck, monLvl)
	local critDamageMultiplier = 1

	if dmgType == "spell" then
		local intellect = pl.GetIntellect and pl:GetIntellect() or 0
		critDamageMultiplier = F.critDamageMult(intellect, monLvl, vars.madnessMode, true)
	elseif dmgType == "heal" then
		--local intellect = pl.GetIntellect and pl:GetIntellect() or 0
		--critDamageMultiplier = intellect*3/4000 + 1.25
		return 0, 0, false
	else
		local accuracy = pl.GetAccuracy and pl:GetAccuracy() or 0
		critDamageMultiplier = F.critDamageMult(accuracy, monLvl, vars.madnessMode)
	end
	critDamageMultiplier=round(critDamageMultiplier*100)/100
	-- dagger bonus
	if not dmgType then
		for i = 0, 1 do
			local it = pl:GetActiveItem(i)
			if it then
				local itSkill = it:T().Skill
				if itSkill == 2 then
					local s, m = SplitSkill(pl:GetSkill(const.Skills.Dagger))
					if m > 2 then
						totalCrit = totalCrit + 0.05 + 0.01*s / math.min(1 + monLvl/200, 4)
					end
				end
			end
		end
	end

	-- axe bonus: either hand grants it, a second axe does not grant it again
	-- (unlike the dagger crit chance above, which is per hand on purpose)
	if not dmgType then
		for i = 0, 1 do
			local it = pl:GetActiveItem(i)
			if it and (table.find(twoHandedAxes, it.Number) or table.find(oneHandedAxes, it.Number)) then
				local s, m = SplitSkill(pl:GetSkill(const.Skills.Axe))
				if m >= 4 then
					critDamageMultiplier = critDamageMultiplier + AXE_CRIT_DAMAGE_PER_SKILL*s
				end
				break
			end
		end
	end

	-- Fate / HoP (buff rework)
	if vars.MAWSETTINGS == nil or vars.MAWSETTINGS.buffRework == "ON" then
		if pl.SpellBuffs and pl.SpellBuffs[4] and pl.SpellBuffs[4].ExpireTime >= Game.Time then
			local s, m	= getBuffSkill(47)
			local s2, m2 = getBuffSkill(86)
			s = math.max(s, s2/1.5)
			m = math.max(m, m2)
			totalCrit = totalCrit + GetBuffMultiplier(const.Spells.Fate, s, m)
		end
	end

	if getMapAffixPower then
		if getMapAffixPower(20) then 
			totalCrit = totalCrit - getMapAffixPower(20)/100 
		end
		if getMapAffixPower(21) then
			critDamageMultiplier = (critDamageMultiplier - 1) * (1 - getMapAffixPower(21)/100) + 1
		end
	end

	local id = pl:GetIndex()
	if not (vars.legendaries and table.find(vars.legendaries[id], 14)) then
		totalCrit = math.min(totalCrit, 1)
	else
		totalCrit=totalCrit+0.1
	end

	local success = math.random() < totalCrit
	return totalCrit, critDamageMultiplier, success
end


--speed
--SPEED WILL NOW REDUCE RECOVERY TIME
oldTable={}
function events.GameInitialized2()
	for i=0,132 do 
		oldTable[i]={}
		for v=1,4 do
			oldTable[i][v]=Game.Spells[i]["Delay" .. masteryName[v]]
		end
	end
end
function events.PlayerCastSpell(t)
	local spell=t.SpellId
	local m=math.max(1,t.Mastery)
	Game.Spells[spell]["Delay" .. masteryName[m]]=getSpellDelay(t.Player,spell)
end

function getSpellDelay(pl,spell)
	if table.find(assassinClass, pl.Class) then
		return GetAssassinSpellDelay(pl,spell)
	end

	if spell==122 then return 120 end

	local s,m=SplitSkill(pl.Skills[math.ceil(spell/11)+11])
	if m==0 then return 150 end
	local haste=math.floor(pl:GetSpeed()/SPELL_HASTE_DIVISOR)
	local enchantMult=1
	if HasSpellHasteEnchant(pl) then
		enchantMult=1.1
	end
	local ascensionSkill=0
	local skill=SplitSkill(pl:GetSkill(const.Skills.Learning))
	if table.find(spells, spell) or (healingSpells and healingSpells[spell]) or CCMAP[spell] then
		ascensionSkill=skill
		if table.find(elementalistClass, pl.Class) then
			ascensionSkill=0
			for i=12, 15 do
				local s,m=SplitSkill(pl.Skills[i])
				ascensionSkill=ascensionSkill+s/4
			end
			ascensionSkill=math.floor(ascensionSkill)
		end
	end
	

	--shield/armor impair
	--slow depending on item
	armorDelay=1
	local it=pl:GetActiveItem(0)
	if it then
		local skill=it:T().Skill
		if weaponImpair[skill] then
			local s,m=SplitSkill(pl:GetSkill(skill))
			armorDelay=armorDelay+weaponImpair[skill][m]/100
		end
	end
	local it=pl:GetActiveItem(3)
	if it then
		local skill=it:T().Skill
		if weaponImpair[skill] then
			local s,m=SplitSkill(pl:GetSkill(skill))
			armorDelay=armorDelay+weaponImpair[skill][m]/100
		end
	end

	if CCMAP[spell] then
		local school=math.ceil(spell/11)+11
		local s,m=SplitSkill(pl:GetSkill(school))
		local speedMultiplier=1.015^(ascensionSkill-s)
		local delay=round(oldTable[spell][m]*speedMultiplier)
		return delay
	end
	
	local hasteDiv=1
	if vars.MAWSETTINGS.buffRework=="ON" then
		local hasteMult=1
		if Party.SpellBuffs[8].ExpireTime>=Game.Time or potionBuffActive(pl, const.Spells.Haste) then
			local s, m=bestBuffSource(5, pl, buffValueMult)
			hasteDiv=math.max(1+GetBuffMultiplier(const.Spells.Haste, s, m), hasteDiv)
		end
	end
	local delay=round(oldTable[spell][m]/(1+haste/100)*1.015^ascensionSkill/hasteDiv/enchantMult)*armorDelay
	if table.find(elementalistClass, pl.Class) then
		delay=delay*1.5
		local id=pl:GetIndex()
		vars.eleStacks=vars.eleStacks or {}
		vars.eleStacks[id]=vars.eleStacks[id] or 0
		local stacks=vars.eleStacks[id]
		local speedIncrease=1+stacks*0.05
		delay=delay/speedIncrease
	end
	if spell==123 then
		delay=round(pl:GetAttackDelay(true)*1.5)
	end
	if getMapAffixPower(27) then
		delay=delay/(1-getMapAffixPower(27)/100)
	end
	delay=round(delay)
	return delay
end
function events.PlayerAttacked(t)
	if t.Attacker and t.Attacker.Monster then
		mon=t.Attacker.Monster --don't set local
	end
end


function CalcHitOrMiss(monLvl, speed)
	return MawCore.Formulas.chanceToBeHit(speed, monLvl)>=math.random()
end

--body building description
function events.GameInitialized2()
	txt=Skillz.getDesc(27,1) .. "\n\n생명력 추가 증가량: " .. bodybuildingHP[1] .. "-" .. bodybuildingHP[2] .. "-" .. bodybuildingHP[3] .. "-" .. bodybuildingHP[4] .. "% (기술 포인트당, 숙련도에 따라 달라짐)."
	Skillz.setDesc(27,1,txt)
end

STAT_DAMAGE_DIVISOR = 1000

function GetMightDamageMultiplier(mightAmount, playerLevel)
	return mightAmount/STAT_DAMAGE_DIVISOR
end

--The Leech block at the bottom of the Power tooltip. Reads the same lifeLeech
--table stage_leech spends, so the shown percentages are the ones applied.
function leechAllText(pl)
	local id=pl:GetIndex()
	if not (lifeLeech and lifeLeech[id]) then
		return ""
	end
	local m=lifeLeech[id].Melee or 0
	local r=lifeLeech[id].Ranged or 0
	local s=lifeLeech[id].Spell or 0
	if m==0 and r==0 and s==0 then
		return ""
	end
	--a negative leech (Hades) drains: red, not healing green
	local function pct(v)
		if v<0 then
			return StrColor(255,64,64, round(v*100) .. "%")
		end
		return StrColor(0,255,0, round(v*100) .. "%")
	end
	return string.format("\n\n물리 흡수: %s\n마법 흡수: %s",
			pct(m), pct(s))
		.. "\n활의 흡수 효과는 절반으로 감소합니다. 마법 흡수에는 무기 마법 부여로 가하는 피해도 포함됩니다."
		.. "\n흡수량은 피해 수치가 아닌 체력 비율로 계산합니다. 흡수율 10%로 몬스터 체력의 50%를 깎으면 자신의 체력 5%를 회복합니다."
		.. "\n몬스터의 체력은 같은 계열의 중간 등급을 기준으로 계산합니다. 약한 변종에게서는 적게, 강한 변종과 우두머리에게서는 많이 흡수합니다."
end

function getIntellectDamageMultiplier(intellectAmount, playerLevel)
	return intellectAmount/STAT_DAMAGE_DIVISOR
end

function events.BuildStatInformationBox(t)
	if t.Stat==0 then
		i=Game.CurrentPlayer
		might=Party[i]:GetMight()
		local bonus=round(GetMightDamageMultiplier(might, Party[i].LevelBase)*1000)/10
		t.Text=string.format("%s\n\n근접/활 추가 피해: %s%s",Game.StatsDescriptions[0],bonus,"%")
	end
	if t.Stat==1 then
		i=Game.CurrentPlayer
		intellect=Party[i]:GetIntellect()
		_,critDmg=getCritInfo(Party[i],"spell")
		local baseText="지능은 복잡하고 추상적인 개념을 추론하고 이해하는 능력을 나타냅니다.\n주문 피해와 주문 치명타 피해는 지능을 기반으로 합니다."
		local bonus=round(getIntellectDamageMultiplier(intellect, Party[i].LevelBase)*1000)/10
		t.Text=string.format("%s\n\n추가 마법 피해: %s%s\n\n주문 치명타 피해: %s%s",baseText,bonus,"%",critDmg*100-100,"%")
	end
	if t.Stat==2 then
		i=Game.CurrentPlayer
		personality=Party[i]:GetPersonality()
		_,critDmg=getCritInfo(Party[i],"spell")
		-- Calculate spell cost reduction percentage
		local level = Party[i].LevelBase
		local spellCostReduction = round((1-getPersonalityManaCostReduction(Party[i]))*1000)/10
		local healingBonus = round(personality/math.min(1000+level*3, 4000)*1000)/10
		local baseText="인격은 의지력과 개인적인 매력을 모두 나타냅니다. 최대 주문력, 마나 비용, 회복 위력은 인격을 기반으로 합니다."
		t.Text=string.format("%s\n\n추가 치유량: %s%s\n\n주문 비용 감소: %s%s\n\n인격 5마다 2레벨 분량의 마나 증가",baseText,healingBonus,"%",spellCostReduction,"%")
	end
	if t.Stat==3 then
		i=Game.CurrentPlayer
		endurance=Party[i]:GetEndurance()
		HPScaling=Game.Classes.HPFactor[Party[i].Class]
		level=Party[i]:GetLevel()
		t.Text=string.format("%s\n\n지구력으로 얻는 생명력 보너스: %s%s\n\n지구력으로 얻는 고정 생명력 보너스: %s",Game.StatsDescriptions[3],round(endurance/STAT_DAMAGE_DIVISOR*1000)/10,"%",Game.GetStatisticEffect(endurance)*HPScaling)
	end
	if t.Stat==4 then
		i=Game.CurrentPlayer
		accuracy=Party[i]:GetAccuracy()
		_,critDmg=getCritInfo(Party[i])
		t.Text=string.format("%s\n\n근접 및 활 치명타 피해 보너스: %s%s",Game.StatsDescriptions[4],critDmg*100-100,"%")
	end
	if t.Stat==5 then
		i=Game.CurrentPlayer
		speed=Party[i]:GetSpeed()
		dodging=0
		Skill, Mas = SplitSkill(Party[i]:GetSkill(const.Skills.Dodging))
		if Mas == 4 and Game.CharacterPortraits[Party[i].Face].Race~=const.Race.Dragon then
			dodging=Skill+10
			dodgeChance=1-1/(1+dodging/200)
			t.Text=string.format("%s\n\n회피 확률: %s%%",Game.StatsDescriptions[5],math.floor(dodgeChance*1000)/10)
		end
		--spell haste
		speed=Party[i]:GetSpeed()
		spellSpeedEffect=math.floor(speed/10)
		if HasSpellHasteEnchant(Party[i]) then
			spellSpeedEffect=spellSpeedEffect+20
		end
		--melee haste
		delay=math.max(Party[i]:GetAttackDelay())
		meleeHaste=bonusSpeed
		--bow haste
		delay=Party[i]:GetAttackDelay(true)
		bowHaste=bonusSpeed
		--Speed is what decides whether a swing lands (Formulas.chanceToBeHit),
		--so the block chance is reported here and not under Armor Class
		local refLvl=MawReferenceLevel()
		local blockChance=100-round(MawCore.Formulas.chanceToBeHit(speed, refLvl)*10000)/100
		t.Text=string.format("%s\n\n근접 가속: %s%%\n원거리 가속: %s%%\n주문 가속: %s%%\n\n레벨 %s 상대 물리 공격 회피 확률: %s%%",t.Text,meleeHaste,bowHaste,spellSpeedEffect,refLvl,blockChance)
	end
	if t.Stat==6 then
		local i=Game.CurrentPlayer
		local lvl=MawReferenceLevel()
		local critChance=round(getCritInfo(Party[i], "ranged",lvl)*10000)/100
		local daggerCritBonus=round(getCritInfo(Party[i],false,lvl)*10000)/100
		t.Text=string.format("%s\n\n레벨 %s 상대 치명타 확률: %s%%",Game.StatsDescriptions[6],lvl,critChance)
		daggerBonus=daggerCritBonus~=critChance
		if daggerBonus then
			t.Text=string.format("%s\n\n레벨 %s 상대 치명타 확률: %s%% (단검 사용 시 %s%%)",Game.StatsDescriptions[6],lvl,critChance, daggerCritBonus)
		end
	end
	if t.Stat==7 then
		local i=Game.CurrentPlayer
		local pl=Party[i]
		HPregenItem=HPregenItem
		local rawRegen=getBuffHealthRegen(pl)
		regen=math.round(rawRegen*10)/10
		local maxHP=GetMaxHP(pl)
		local regenPct=maxHP>0 and round(rawRegen/maxHP*1000)/10 or 0

		hpMap=hpStatsMap[i]

		t.Text=string.format("%s\n\n인내력으로 얻는 생명력 보너스: %s\n육체 단련으로 얻는 생명력 보너스: %s\n아이템으로 얻는 생명력 보너스: %s\n기본 생명력: %s\n\n초당 생명력 재생: %s (%s)",t.Text,StrColor(0,255,0,hpMap.totalEnduranceBonus), StrColor(0,255,0,hpMap.totalBBBonus),StrColor(0,255,0,round(hpMap.totalhpFromItems)),StrColor(0,255,0,hpMap.totalBaseHP),StrColor(0,255,0,regen),StrColor(0,255,0,regenPct .. "%"))
	end
	if t.Stat==8 then
		local i=Game.CurrentPlayer
		local medRegen, fullSP = getMeditationRegen(i)
		medRegen = medRegen*10
		--meditation buff
		if vars.MAWSETTINGS.buffRework=="ON" and vars.mawbuff[56] then
			local s, m, level=getBuffSkill(56)
			local level=estimateSkill(level)
			medRegen = medRegen + round((fullSP^0.35*level^1.4*((buffPower[56].Base[m])/100) +10)*(1+buffPower[56].Scaling[m]/100*s))
		end
		
		local SPregenItem=0
		local bonusregen=0
		for it in Party[i]:EnumActiveItems() do
			if it.Bonus2 == 38 or it.Bonus2==47 or it.Bonus2==55 or it.Bonus2==66 then		
				--SPregenItem=SPregenItem+1
				--bonusregen=1
				--such enchants now increase meditation instead
			end
			if table.find(artifactSpRegen, it.Number) then
				SPregenItem=SPregenItem+1
				bonusregen=1
			end
		end
		regen=math.ceil(Party[i]:GetFullSP()*SPregenItem*0.01)+medRegen+bonusregen
		--regen is a float now that medRegen is not pre-rounded: one decimal
		local perSec=round(regen)/10
		t.Text=string.format("%s\n\n초당 주문력 재생: %s",t.Text,StrColor(40,100,255,perSec))
	end
	
	if t.Stat==9 then
		i=Game.CurrentPlayer
		local lvl=MawReferenceLevel()
		local acReduction=round((100-calcMawDamage(Party[i],4,10000,false,lvl,true)/100)*100)/100
		--the block chance itself is reported under Speed, which is what buys it;
		--it is still needed here because the total combines the two
		blockChance= 100-round(MawCore.Formulas.chanceToBeHit(Party[i]:GetSpeed(), lvl)*10000)/100
		totRed= 100-round((100-blockChance)*(100-acReduction))/100
		t.Text=string.format("%s\n\n레벨 %s 상대 물리 피해 감소: %s%s",t.Text,lvl,StrColor(255,255,100,acReduction),StrColor(255,255,100,"%") .. "\n\n평균 총 피해 감소: " .. StrColor(255,255,100,totRed) .. "%")
	end
	
	if t.Stat==5234672 then
		i=Game.CurrentPlayer
		local pl=Party[i]
		--get spell and its damage
		DPS1, DPS2, DPS3, vitality=calcPowerVitality(pl)
		local txt=string.format("근접 위력: %s\n원거리 위력: %s\n주문 위력: %s",StrColor(255,0,0,DPS1),StrColor(200,200,0,DPS2),StrColor(50,50,220,DPS3))

		t.Text=string.format("%s\n%s",t.Text,txt) .. leechAllText(pl)

	end
	
	if t.Stat==11 then
		local i=Game.CurrentPlayer
		local pl=Party[i]
		local id=pl:GetIndex()
		--check and add equipped legendaries
		local legTxt="현재 활성화된 전설 효과:"
		for i=1,LEGENDARY_AFFIX_COUNT do
			local legId=i+LEGENDARY_AFFIX_BASE
			if vars.legendaries and vars.legendaries[id] and table.find(vars.legendaries[id], legId) then
				legTxt= legTxt .. StrColor(255,255,30,"\n\n - " .. legendaryEffects[legId])
			end
		end
		
		t.Text=legTxt
	end
	
	if t.Stat==13 or t.Stat==14 then
		local bolsterLevel8=getPartyLevel(1)
		local bolsterLevel7=getPartyLevel(2)
		local bolsterLevel6=getPartyLevel(3)
		local bolsterLevel8=math.max(bolsterLevel8-4,0)
		local bolsterLevel7=math.max(bolsterLevel7-4,0)
		local bolsterLevel6=math.max(bolsterLevel6-4,0)
		t.Text=t.Text .."\n\n총 획득 레벨: " .. StrColor(255,255,153,round(getTotalLevel())).. "\n\nMM6에서 획득한 레벨: " .. StrColor(255,255,153,round(vars.MMLVL[3]*100)/100) .. "\nMM7에서 획득한 레벨: " .. StrColor(255,255,153,round(vars.MMLVL[2]*100)/100) .. "\nMM8에서 획득한 레벨: " .. StrColor(255,255,153,round(vars.MMLVL[1]*100)/100) .. "\n\nMM6 보정 레벨: " .. StrColor(255,255,153,round(bolsterLevel6)) .."\nMM7 보정 레벨: " .. StrColor(255,255,153,round(bolsterLevel7)) .."\nMM8 보정 레벨: " .. StrColor(255,255,153,round(bolsterLevel8))
	end
	if t.Stat==15 then
		local i=Game.CurrentPlayer
		local atk=Party[i]:GetMeleeAttack()
		local lvl=MawReferenceLevel()
		local bless=MawCore.Formulas.blessHitBonus(Party[i])
		local hitChance= round((MawCore.Formulas.mawHitChance(atk, lvl, bless) or 0)*10000)/100
		local capLvl=MawCore.Formulas.hitCapLevel(atk, bless, lvl)
		if capLvl then
			t.Text=string.format("%s\n\n명중률: %s (몬스터 레벨 %s까지)",t.Text,StrColor(255,255,100,"100%"),StrColor(255,255,100,capLvl))
		else
			t.Text=string.format("%s\n\n레벨 %s 몬스터 상대 명중률: %s%s",t.Text,lvl,StrColor(255,255,100,hitChance),StrColor(255,255,100,"%"))
		end
	end
	
	if t.Stat==16 then
		local i=Game.CurrentPlayer
		--damage tracker
		vars.damageTrack=vars.damageTrack or {}
		vars.damageTrack[Party[i]:GetIndex()]=vars.damageTrack[Party[i]:GetIndex()] or 0

		vars.damageTrack=vars.damageTrack or {}
		vars.damageTrack[Party[i]:GetIndex()]=vars.damageTrack[Party[i]:GetIndex()] or 0
		vars.damageTrackRanged=vars.damageTrackRanged or {}
		vars.damageTrackRanged[Party[i]:GetIndex()]=vars.damageTrackRanged[Party[i]:GetIndex()] or 0
				
		local damage= vars.damageTrack[Party[Game.CurrentPlayer]:GetIndex()] or 0
		t.Text=string.format("%s\n\n전체 피해 집계\n총 피해량: %s",t.Text,StrColor(255,255,100,round(damage)))
		local damage= vars.damageTrackRanged[Party[Game.CurrentPlayer]:GetIndex()] or 0
		t.Text=string.format("%s\n총 원거리 피해량: %s",t.Text,StrColor(255,255,100,round(damage)))

        t.Text = string.format("%s\n\n전체 보정치, 근접/원거리/합계:", t.Text)
		local total_map_damage_m = 0
		local total_map_damage_r = 0                
		local player_damage_m = {}
		local player_damage_r = {}
		for i = 0, Party.High do
			player_damage_m[i] = (vars.damageTrack[Party[i]:GetIndex()] or 0)
			player_damage_r[i] = (vars.damageTrackRanged[Party[i]:GetIndex()] or 0)
			total_map_damage_m = total_map_damage_m + player_damage_m[i]
			total_map_damage_r = total_map_damage_r + player_damage_r[i]
		end
		
		total_map_damage_m=math.max(total_map_damage_m,1)
		total_map_damage_r=math.max(total_map_damage_r,1)
        for i = 0, Party.High do
            t.Text = string.format("%s\n %s\t %29s\t%32s %s\t%37s %s\t%42s", t.Text, Party[i].Name,
			round(100 * player_damage_m[i] / total_map_damage_m),'/', 
			round(100 * player_damage_r[i] / total_map_damage_r),'/',
			round(100 * (player_damage_m[i] + player_damage_r[i]) / (total_map_damage_m + total_map_damage_r)),' %')
        end
		
		--HEALING RECOUNT
		for i=0,Party.High do
			local id=Party[i]:GetIndex()
			--initialize
			vars.regenerationHeal=vars.regenerationHeal or {}
			vars.regenerationHeal[id]=vars.regenerationHeal[id] or 0
			
			vars.healingDone=vars.healingDone or {}
			vars.healingDone[id]=vars.healingDone[id] or 0
			
			vars.leechDone=vars.leechDone or {}
			vars.leechDone[id]=vars.leechDone[id] or 0
		end
		local id=Party[Game.CurrentPlayer]:GetIndex()
		--show
		t.Text = t.Text .. "\n\n전체 회복 집계:\n총 회복량:  " .. StrColor(0,255,0,vars.healingDone[id]) .. "\n총 재생 회복량: " .. StrColor(0,255,0,vars.regenerationHeal[id]) .. "\n총 흡혈 회복량: " .. StrColor(0,255,0,vars.leechDone[id])
		
		--matrix
		t.Text = t.Text .. "\n\n전체 보정치, 치유/재생/흡수/합계:"

		--totals
		local tot1=0
		local tot2=0
		local tot3=0
		for i=0,Party.High do
			local id=Party[i]:GetIndex()
			tot1=tot1+vars.healingDone[id]
			tot2=tot2+vars.regenerationHeal[id]
			tot3=tot3+vars.leechDone[id]
		end
		tot1=math.max(tot1,1)
		tot2=math.max(tot2,1)
		tot3=math.max(tot3,1)
		local tot4=tot1+tot2+tot3
		
        for i = 0, Party.High do
			local id=Party[i]:GetIndex()
            t.Text = string.format("%s\n %s\t %29s\t%32s %s\t%37s %s\t%42s %s\t%47s", t.Text, Party[i].Name,
			round(100 * vars.healingDone[id] / tot1),'/', 
			round(100 * vars.regenerationHeal[id] / tot2),'/',
			round(100 * vars.leechDone[id] / tot3),'/',
			round(100 * (vars.healingDone[id]+vars.regenerationHeal[id]+vars.leechDone[id]) / tot4),' %')
        end
		
		t.Text = t.Text .. "\n\n주변에 몬스터가 있을 때 행한 치유만 집계됩니다" 
		
	end
	
	
	if t.Stat==17 then
		local i=Game.CurrentPlayer
		local atk=Party[i]:GetRangedAttack()
		local lvl=MawReferenceLevel()
		local bless=MawCore.Formulas.blessHitBonus(Party[i])
		local hitChance= round((MawCore.Formulas.mawHitChance(atk, lvl, bless) or 0)*10000)/100
		local capLvl=MawCore.Formulas.hitCapLevel(atk, bless, lvl)
		if capLvl then
			t.Text=string.format("%s\n\n명중률: %s (몬스터 레벨 %s까지)",t.Text,StrColor(255,255,100,"100%"),StrColor(255,255,100,capLvl))
		else
			t.Text=string.format("%s\n\n레벨 %s 몬스터 상대 명중률: %s%s",t.Text,lvl,StrColor(255,255,100,hitChance),StrColor(255,255,100,"%"))
		end
	end
	
	if t.Stat==18 then
		local i=Game.CurrentPlayer
		mapvars.damageTrackRanged=mapvars.damageTrackRanged or {}
		mapvars.damageTrackRanged[Party[i]:GetIndex()]=mapvars.damageTrackRanged[Party[i]:GetIndex()] or 0

		mapvars.damageTrack=mapvars.damageTrack or {}
		mapvars.damageTrack[Party[i]:GetIndex()]=mapvars.damageTrack[Party[i]:GetIndex()] or 0
		mapvars.damageTrackRanged=mapvars.damageTrackRanged or {}
		mapvars.damageTrackRanged[Party[i]:GetIndex()]=mapvars.damageTrackRanged[Party[i]:GetIndex()] or 0

		local damage= mapvars.damageTrack[Party[Game.CurrentPlayer]:GetIndex()] or 0
		t.Text=string.format("%s\n\n현재 맵 피해 집계\n현재 맵 근접 피해량: %s",t.Text,StrColor(255,255,100,round(damage)))
		local damage= mapvars.damageTrackRanged[Party[Game.CurrentPlayer]:GetIndex()] or 0
		t.Text=string.format("%s\n현재 맵 원거리 피해량: %s",t.Text,StrColor(255,255,100,round(damage)))

            	t.Text = string.format("%s\n\n지도 보정치, 근접/원거리/합계:", t.Text)
		local total_map_damage_m = 0
		local total_map_damage_r = 0                
		local player_damage_m = {}
		local player_damage_r = {}
		for i = 0, Party.High do
			player_damage_m[i] = (mapvars.damageTrack[Party[i]:GetIndex()] or 0)
			player_damage_r[i] = (mapvars.damageTrackRanged[Party[i]:GetIndex()] or 0)
			total_map_damage_m = total_map_damage_m + player_damage_m[i]
			total_map_damage_r = total_map_damage_r + player_damage_r[i]
		end
		
		total_map_damage_m=math.max(total_map_damage_m,1)
		total_map_damage_r=math.max(total_map_damage_r,1)
        for i = 0, Party.High do
            t.Text = string.format("%s\n %s\t %29s\t%32s %s\t%37s %s\t%42s", t.Text, Party[i].Name,
			round(100 * player_damage_m[i] / total_map_damage_m),'/', 
			round(100 * player_damage_r[i] / total_map_damage_r),'/',
			round(100 * (player_damage_m[i] + player_damage_r[i]) / (total_map_damage_m + total_map_damage_r)),' %')
        end
		
		
		--HEALING RECOUNT
		for i=0,Party.High do
			local id=Party[i]:GetIndex()
			--initialize
			mapvars.regenerationHeal=mapvars.regenerationHeal or {}
			mapvars.regenerationHeal[id]=mapvars.regenerationHeal[id] or 0
			
			mapvars.healingDone=mapvars.healingDone or {}
			mapvars.healingDone[id]=mapvars.healingDone[id] or 0
			
			mapvars.leechDone=mapvars.leechDone or {}
			mapvars.leechDone[id]=mapvars.leechDone[id] or 0
		end
		local id=Party[Game.CurrentPlayer]:GetIndex()
		--show
		t.Text = t.Text .. "\n\n현재 맵 회복 집계:\n현재 맵 총 회복량:  " .. StrColor(0,255,0,mapvars.healingDone[id]) .. "\n현재 맵 재생 회복량: " .. StrColor(0,255,0,mapvars.regenerationHeal[id]) .. "\n현재 맵 흡혈 회복량: " .. StrColor(0,255,0,mapvars.leechDone[id])
		
		--matrix
		t.Text = t.Text .. "\n\n지도 보정치, 치유/재생/흡수/합계:"

		--totals
		local tot1=0
		local tot2=0
		local tot3=0
		for i=0,Party.High do
			local id=Party[i]:GetIndex()
			tot1=tot1+mapvars.healingDone[id]
			tot2=tot2+mapvars.regenerationHeal[id]
			tot3=tot3+mapvars.leechDone[id]
		end
		tot1=math.max(tot1,1)
		tot2=math.max(tot2,1)
		tot3=math.max(tot3,1)
		local tot4=tot1+tot2+tot3
		
        for i = 0, Party.High do
			local id=Party[i]:GetIndex()
            t.Text = string.format("%s\n %s\t %29s\t%32s %s\t%37s %s\t%42s %s\t%47s", t.Text, Party[i].Name,
			round(100 * mapvars.healingDone[id] / tot1),'/', 
			round(100 * mapvars.regenerationHeal[id] / tot2),'/',
			round(100 * mapvars.leechDone[id] / tot3),'/',
			round(100 * (mapvars.healingDone[id]+mapvars.regenerationHeal[id]+mapvars.leechDone[id]) / tot4),' %')
        end
		t.Text = t.Text .. "\n\n주변에 몬스터가 있을 때 행한 치유만 집계됩니다" 
	end
	
	if t.Stat>=19 and t.Stat<=24 then
		t.Text=t.Text .. "\n\n표시된 % 수치만큼 피해가 감소합니다.\n\n빛 저항은 정신 저항과 육체 저항 중 낮은 값과 같습니다.\n어둠 저항은 원소 저항 중 가장 낮은 값과 같습니다.\n에너지 저항은 모든 저항 중 가장 낮은 값과 같습니다."
	end
end

function events.Regeneration(t)
	--HP
	if t.PlayerIndex<=Party.High then
		totHP=Party[t.PlayerIndex]:GetFullHP()
			for it in Party[t.PlayerIndex]:EnumActiveItems() do
				if it.Bonus2 == 37 or it.Bonus2==44 or it.Bonus2==50 or it.Bonus2==54 then			
					t.HP=t.HP+math.max(totHP*0.01-1,0)
				end
			end
		t.HP=round(t.HP)
		--SP
		totSP=Party[t.PlayerIndex]:GetFullSP()
			for it in Party[t.PlayerIndex]:EnumActiveItems() do
				if it.Bonus2 == 38 or it.Bonus2==47 or it.Bonus2==55 then		
					t.SP=t.SP+math.max(totSP*0.01-1,0)
				end
			end
		t.SP=round(t.SP)
	end
end
--mistform
--
--The engine has its own mist-form rule. The mod replaces it with a flat 0.25
--to physical damage in the damage pipeline, so the buff is zeroed for the
--duration of the hit -- PlayerAttacked fires before the engine resolves it --
--and put back next tick. The pipeline keys the 0.25 off "a restore is
--pending on this character".
--
--That flag used to be a single boolean raised on EVERY attack, mist form or
--not, so the 0.25 applied to every physical hit in the game on every
--character: monsters landed at a quarter of what their tooltip advertised.
--Two things fix it -- the buff has to actually be up, and the flag is per
--character, since one party member in mist form must not quarter the hits
--the other four take. The saved expiry lives in the same table for the same
--reason: as a lone global, two characters hit in one tick overwrote it.
restoringMistformTime = {}
function events.PlayerAttacked(t)
	local pl=t.Player
	local id=pl:GetIndex()
	if restoringMistformTime[id] then return end
	if pl.SpellBuffs[26].ExpireTime<=Game.Time then return end
	restoringMistformTime[id]=pl.SpellBuffs[26].ExpireTime
	pl.SpellBuffs[26].ExpireTime=0
	RunNextTick(function()
		pl.SpellBuffs[26].ExpireTime=restoringMistformTime[id]
		restoringMistformTime[id]=nil
	end)
end

--shaman Air / DK Body-or-Dark damage reduction; the % printed in tooltips
--comes from MawCore.Formulas.reductionPercent

--legendary 22: 3% per active monster within 512, never past half.
local function legendaryCrowdMultiplier(pl)
	local id=pl:GetIndex()
	if not (vars and vars.legendaries and vars.legendaries[id]
			and table.find(vars.legendaries[id], 22)) then
		return 1
	end
	--Global/ owns getDistanceToMonster, so it can be absent outside a game
	if not getDistanceToMonster then
		return 1
	end
	local count=0
	for i=0, Map.Monsters.High do
		if Map.Monsters[i].Active and getDistanceToMonster(Map.Monsters[i])<=512 then
			count=count+1
		end
	end
	return math.max(0.97^count, 0.5)
end

local function flatClassReduction(pl)
	if pl.Unconscious~=0 or pl.Dead~=0 or pl.Eradicated~=0 then
		return 0
	end
	local skill
	if table.find(shamanClass, pl.Class) then
		skill=SplitSkill(pl.Skills[const.Skills.Water])
	elseif table.find(seraphClass, pl.Class) then
		skill=SplitSkill(pl.Skills[const.Skills.Spirit])
	end
	if not skill then
		return 0
	end
	local lvl=getTotalLevel()
	local _,_,_,avgTaken=getPlayerEstimatedVitality(lvl+1)
	return round(getMonsterDamage(false,(lvl+1))*(skill/estimateSkill(lvl))
		*avgTaken/2*0.99^estimateSkill(lvl))
end

local function applyPostMitigation(pl, damage, originalDamage, ratioOnly)
	damage=math.max(damage, originalDamage*MawCore.Formulas.damageFloor)
	local id=pl:GetIndex()
	if vars and vars.legendaries and vars.legendaries[id]
			and table.find(vars.legendaries[id], 18) then
		damage=damage*0.9
	end
	damage=damage*legendaryCrowdMultiplier(pl)
	if not ratioOnly then
		local flat=flatClassReduction(pl)
		if flat>0 then
			damage=math.max(damage-flat, damage*0.25)
		end
	end
	return damage
end

local function classDamageReduction(pl, damage, dkSkill)
	if table.find(shamanClass, pl.Class) then
		local s=SplitSkill(pl.Skills[const.Skills.Air])
		damage=damage/(1+0.01*s)
	elseif table.find(dkClass, pl.Class) then
		local s=SplitSkill(pl.Skills[dkSkill])
		damage=damage/(1+0.01*s)
	end
	return damage
end

--reduce damage by %

--pokes the throttled label tasks whenever something they display changes
--(player, screen, char tab, mouse-held item) -- NOTES.md
local lastLabelPlayer, lastLabelScreen, lastLabelCharScreen, labelPokes = nil, nil, nil, 0
local lmNum, lmBonus, lmStr, lmB2, lmChg, lmMax, lmExp, lmCond
mawTick_LabelWatch=function()
	local mi=Mouse.Item
	local changed = Game.CurrentPlayer~=lastLabelPlayer
		or Game.CurrentScreen~=lastLabelScreen
		or Game.CurrentCharScreen~=lastLabelCharScreen
		or mi.Number~=lmNum or mi.Bonus~=lmBonus or mi.BonusStrength~=lmStr
		or mi.Bonus2~=lmB2 or mi.Charges~=lmChg or mi.MaxCharges~=lmMax
		or mi.BonusExpireTime~=lmExp or mi.Condition~=lmCond
	if changed then
		--two poke frames: the deferred itemStats refresh (mawRefresh via
		--RunNextTick) may land a frame behind the first poke
		labelPokes=2
		lastLabelPlayer, lastLabelScreen = Game.CurrentPlayer, Game.CurrentScreen
		lastLabelCharScreen = Game.CurrentCharScreen
		lmNum, lmBonus, lmStr, lmB2 = mi.Number, mi.Bonus, mi.BonusStrength, mi.Bonus2
		lmChg, lmMax, lmExp, lmCond = mi.Charges, mi.MaxCharges, mi.BonusExpireTime, mi.Condition
	end
	if labelPokes>0 then
		labelPokes=labelPokes-1
		local now=MawCore.Scheduler.now
		now("stats/pool-labels")
		now("stats/power-labels")
		now("classes/dragon-charscreen")
		--poke-only tasks (interval -1): they run ONLY from here, on the same
		--signals -- player, screen, char tab, mouse-held item
		now("skills/misc-skills-ui")
		now("skills/dwarf-axes")
		now("alchemy/reagent-power")
	end
end

--TOOLTIPS
function events.Action(t)
	if vars.MAWSETTINGS.buffRework=="ON" then
		if t.Action==94 and Game.CurrentScreen==0 then
			local i=t.Param-1
			if i>=0 and i<=Party.High and vars.currentManaPool[i] and vars.maxManaPool[i]>0 then
				local manaPool=round(vars.currentManaPool[i]/vars.maxManaPool[i]*1000)/10
				Game.GlobalTxt[212]=StrColor(0,100,255,"Mana " .. manaPool .. "%")
				if manaPool==100 then
					Game.GlobalTxt[212]=StrColor(0,100,255,"Mana")
				end
			end
			if i>=0 and i<=Party.High and vars.currentHPPool[i] and vars.maxHPPool[i]>0 then
				local hpPool=round(vars.currentHPPool[i]/vars.maxHPPool[i]*1000)/10
				Game.GlobalTxt[108]=StrColor(0,255, 0,"HP " .. hpPool .. "%")
				if hpPool==100 then
					Game.GlobalTxt[108]=StrColor(0,255, 0,"생명력")
				end
			end
		end
	end
end
function mawTick_PoolLabels()
	if Game.CurrentCharScreen==100 and Game.CurrentScreen==7 then
		i=Game.CurrentPlayer 
		if i==-1 then return end --prevent bug message
		if vars.MAWSETTINGS.buffRework=="ON" and vars.maxManaPool[i]>0 then
			local manaPool=round(vars.currentManaPool[i]/vars.maxManaPool[i]*1000)/10
			Game.GlobalTxt[212]=StrColor(0,100,255,"Mana " .. manaPool .. "%")
			if manaPool==100 then
				Game.GlobalTxt[212]=StrColor(0,100,255,"Mana")
			end
		end
		
		if vars.MAWSETTINGS.buffRework=="ON" and vars.maxHPPool[i]>0 then
			local hpPool=round(vars.currentHPPool[i]/vars.maxHPPool[i]*1000)/10
			Game.GlobalTxt[108]=StrColor(0,255, 0,"HP " .. hpPool .. "%")
			if hpPool==100 then
				Game.GlobalTxt[108]=StrColor(0,255, 0,"생명력")
			end
		end
		
		pl=Party[i]
		local resistances={}
		local resistances2={}
		local damageList={0,1,2,3,7,8}
		for i=10,15 do
			resistances[i]=pl:GetResistance(i)
			if resistances[i]>=64000 then
				resistances[i]="Immune"
			end
			resistances2[i]=100-math.max(round(calcMawDamage(pl,damageList[i-9],1000,false,MawReferenceLevel(),true))/10, 0)
			resistances2[i]=round(resistances2[i]*100)/100
			if resistances2[i]%1==0 then
				resistances2[i]=resistances2[i] .. ".0"
			end
		end
		local resistanceText={}
		local id=pl:GetIndex()
		for i=1,6 do
			if vars.normalEnchantResistance[id][10+i]>0 then
				resistanceText[i]=StrColor(0,255,0,string.format("%6s", resistances[9+i]))
			else
				resistanceText[i]=string.format("%6s", resistances[9+i])
			end
		end
		Game.GlobalTxt[87]=StrColor(255, 70, 70,    string.format(resListBackup[1] .. "\t            %s%s ",resistances2[10],"%")) .. resistanceText[1] .. "\n\n\n\n\n\n\n\n\n"
		Game.GlobalTxt[6]=StrColor(173, 216, 230,   string.format(resListBackup[2] .. "\t            %s%s ",resistances2[11],"%")) .. resistanceText[2] .. "\n\n\n\n\n\n\n\n\n"
		Game.GlobalTxt[240]=StrColor(100, 180, 255, string.format(resListBackup[3] .. "\t            %s%s ",resistances2[12],"%")) .. resistanceText[3] .. "\n\n\n\n\n\n\n\n\n"
		Game.GlobalTxt[70]=StrColor(153, 76, 0,     string.format(resListBackup[4] .. "\t            %s%s ",resistances2[13],"%")) .. resistanceText[4] .. "\n\n\n\n\n\n\n\n\n"
		Game.GlobalTxt[142]=StrColor(200, 200, 255, string.format(resListBackup[5] .. "\t            %s%s ",resistances2[14],"%")) .. resistanceText[5] .. "\n\n\n\n\n\n\n\n\n"
		Game.GlobalTxt[29]=StrColor(255, 192, 203,  string.format(resListBackup[6] .. "\t            %s%s ",resistances2[15],"%"))	 .. resistanceText[6] .. "\n\n\n\n\n\n\n\n\n"
		statsChanged=true
	elseif statsChanged and (Game.CurrentCharScreen~=100 or Game.CurrentScreen~=7) then
		Game.GlobalTxt[87]=resListBackup[1]
		Game.GlobalTxt[6]=resListBackup[2]
		Game.GlobalTxt[240]=resListBackup[3]
		Game.GlobalTxt[70]=resListBackup[4]
		Game.GlobalTxt[142]=resListBackup[5]
		Game.GlobalTxt[29]=resListBackup[6]
		statsChanged=false
	end
end

function events.BeforeLoadMap()
	if not resListBackup then
		resListBackup={}
		resListBackup[1]=Game.GlobalTxt[87]
		resListBackup[2]=Game.GlobalTxt[6]
		resListBackup[3]=Game.GlobalTxt[240]
		resListBackup[4]=Game.GlobalTxt[70]
		resListBackup[5]=Game.GlobalTxt[142]
		resListBackup[6]=Game.GlobalTxt[29]
	end
end

damageKindMap={
	[0]=const.Damage.Fire,
	[1]=const.Damage.Air,
	[2]=const.Damage.Water,
	[3]=const.Damage.Earth,
	[4]=const.Damage.Phys,
	[6]=const.Damage.Spirit,
	[7]=const.Damage.Mind,
	[8]=const.Damage.Body,
	[9]=const.Damage.Light,
	[10]=const.Damage.Dark,
}

--spear reset stacks after kill
function events.MonsterKilled(mon)
	local id=mon:GetIndex()
	if mapvars.spearDamageIncrease and mapvars.spearDamageIncrease[id] then
		mapvars.spearDamageIncrease[id]=0
	end
	if mapvars.legendaryDamageTaken and mapvars.legendaryDamageTaken[id] then
		mapvars.legendaryDamageTaken[id]=0
	end
end

--stats breakpoints
function events.GetStatisticEffect(t)
	if t.Value >=25 then
		t.Result=math.floor(t.Value/5)
	end
end


--crit message
local hook, autohook, autohook2, asmpatch = mem.hook, mem.autohook, mem.autohook2, mem.asmpatch
local u1, u2, u4, i1, i2, i4 = mem.u1, mem.u2, mem.u4, mem.i1, mem.i2, mem.i4
local critAttackMsg = "" 
local critShootMsg = "" 
local critKillMsg = "" 

autohook(0x4376AC, function(d)
	local addr, result = u4[d.esp + 4]
	if addr == u4[0x6016D8] then -- attack
		result = mem.topointer(critAttackMsg)
	elseif addr == u4[0x60173C] then -- shoot
		result = mem.topointer(critShootMsg)
	elseif addr == u4[0x601704] then -- kill
		result = mem.topointer(critKillMsg)
	else
		error("Unknown attack message type")
	end
	u4[d.esp + 4] = result
	MawCore.DamageState.setCrit(false)
end)

--resistance map
damageKindResistance={
	[0] = {10},
	[1] = {11},
	[2] = {12},
	[3] = {13},
	[6] = {14},
	[7] = {14},
	[8] = {15},
	[9] = {14,15},
	[10] = {10,11,12,13},
	[12] = {10,11,12,13,14,15},
}

buffToResistance={
	[0] = 6,
	[1] = 0,
	[2] = 17,
	[3] = 4,
	[6] = 12,
	[7] = 12,
	[8] = 1,
	[9] = {12,1},
	[10] = {6,0,17,4},
	[12] = {12,1,6,0,17,4},
}

buffToSpell={
	[0] = 3,
	[1] = 14,
	[2] = 25,
	[3] = 36,
	[6] = 58,
	[7] = 58,
	[8] = 69,
	[9] = {58,69},
	[10] = {3,14,25,36},
	[12] = {58,69,3,14,25,36},
}

--[[UNUSED
function compute_damage(x)
    -- Start with the base damage multiplier
    local damage = 1
	x=math.max(x,0)
    -- Loop through each step from 1 to the floor of x
    for i = 1, math.floor(x) do
        -- Multiply the damage by (2 - i*0.2)
        damage = damage * math.max(2.2 - i * 0.1, 1.8)
    end

    -- If x is not an integer, handle the fractional part
    local fractional_part = x - math.floor(x)
    if fractional_part > 0 then
        damage = damage * math.max(2.2 - (math.floor(x) + 1) * 0.1,1.8) ^ fractional_part
    end
	
    return damage
end
]]

function calcMawDamage(pl,damageKind,originalDamage,rand,monLvl,ratioOnly)
	local monLvl=monLvl or pl.LevelBase

	local id=pl:GetIndex()
	--AC for phys
	local damage = originalDamage
	
	--shield skill
	if pl:GetActiveItem(0) then
		local it=pl:GetActiveItem(0)
		if it and it:T().Skill==const.Skills.Shield then --shield skill
			s,m=SplitSkill(pl.Skills[const.Skills.Shield])
			if m>=4 then
				damage=damage*0.85
			end
		end
	end
	--PHYSICAL DAMAGE CALCULATION
	if damageKind==4 then 		
		local AC=pl:GetArmorClass()
		if getMapAffixPower(28) then
			AC=AC*(1-getMapAffixPower(28)/100)
		end
		local damage=round(damage*MawCore.Formulas.armorDamageTaken(AC, monLvl))
		
		--dk/shaman
		damage=classDamageReduction(pl, damage, const.Skills.Body)
		--enchant reduction
		if vars.shieldEnchant and vars.shieldEnchant[id] then
			damage=damage*0.85
		end
		return applyPostMitigation(pl, damage, originalDamage, ratioOnly)
	end
	
	
	damage=classDamageReduction(pl, damage, const.Skills.Dark)

	--MAGIC DAMAGE CALCULATION
	--shield buff
	if vars.MAWSETTINGS.buffRework=="ON" then
		if Party.SpellBuffs[14].ExpireTime>=Game.Time or potionBuffActive(pl, const.Spells.Shield) then
			local s,m=bestBuffSource(17, pl, buffValueMult)
			damage=damage*math.max(1-GetBuffMultiplier(const.Spells.Shield, s, m),0.7)
		end
	else
		if pl.SpellBuffs[11].ExpireTime>Game.Time or Party.SpellBuffs[14].ExpireTime>Game.Time  then --shield buff
			damage=damage*0.85
		end
	end
	--shield skill
	if pl:GetActiveItem(0) then
		local it=pl:GetActiveItem(0)
		if it and it:T().Skill==const.Skills.Shield then --shield skill
			s,m=SplitSkill(pl.Skills[const.Skills.Shield])
			if m>=4 then
				damage=damage*0.85
			end
		end
	end
	
	--get resistances
	if not damageKindResistance[damageKind] then
		local damage=round(damage)
		return applyPostMitigation(pl, damage, originalDamage, ratioOnly)
	end
	local res=math.huge
	local resList=damageKindResistance[damageKind]
	
	-- Initialize enchant resistance table
	vars.normalEnchantResistance=vars.normalEnchantResistance or {}
	vars.normalEnchantResistance[id]=vars.normalEnchantResistance[id] or {}
	
	-- Find the resistance type that provides the highest effective protection
	local bestEffectiveRes = 0
	local effectiveBaseRes=0
	local baseRes=0
	for i=1,#resList do
		baseRes = pl:GetResistance(resList[i])
		
		-- Get item enchant resistance for this resistance type
		vars.normalEnchantResistance[id][resList[i]+1]=vars.normalEnchantResistance[id][resList[i]+1] or 0
		local itemRes = vars.normalEnchantResistance[id][resList[i]+1]
		
		-- Apply legendary power 16 to item resistance
		if vars.legendaries and vars.legendaries[id] and table.find(vars.legendaries[id], 16) then
			itemRes=itemRes*1.5
		end
		
		-- Calculate total resistance for this type (base resistance with item enchant multiplier)
		local itemResMultiplier = MawCore.Formulas.enchantResistanceDamageTaken(itemRes)
		local totalRes = baseRes 
		
		-- Apply map affix reduction if present
		if getMapAffixPower(29) then
			totalRes=totalRes*(1-getMapAffixPower(29)/100)
		end
		
		-- Calculate the effective resistance using the proper formula
		local effectiveRes=MawCore.Formulas.resistanceDamageTaken(totalRes, monLvl)*itemResMultiplier
		
		-- Keep track of the highest effective resistance (best protection)
		if effectiveRes > bestEffectiveRes then
			bestEffectiveRes = effectiveRes
			effectiveBaseRes = baseRes
		end
	end
	
	-- Skip if this resistance is immune
	if effectiveBaseRes>=65000 then
		return 0
	end

	local res = bestEffectiveRes
	--randomize resistance
	if res>0 and rand then
		local roll=(math.random()+math.random())-1
		res=math.max(0, res+(math.min(res,1-res)*roll))
	end
	
	local damage=round(damage*res)
	return applyPostMitigation(pl, damage, originalDamage, ratioOnly)
end


function mawTick_PowerLabels()
	if Game.CurrentCharScreen==100 and Game.CurrentScreen==7 then
		local i=Game.CurrentPlayer
		if i<0 or i>Party.High then return end
		local pl=Party[i]
		DPS1, DPS2, DPS3, vitality=calcPowerVitality(pl, true)
		--get spell and its damage
		spellIndex = pl.AttackSpell==0 and pl.QuickSpell or pl.AttackSpell
		
        if spellPowers[spellIndex] or (healingSpells and healingSpells[spellIndex]) then 		
			Game.GlobalTxt[47]=string.format("근/원/주:%s/%s/%s\n\n\n\n\n\n\n",StrColor(255,0,0,DPS1),StrColor(200,200,0,DPS2),StrColor(50,50,220,DPS3))
		else
		    Game.GlobalTxt[47]=string.format("근/원:%s/%s\n\n\n\n\n\n\n",StrColor(255,0,0,DPS1),StrColor(200,200,0,DPS2))
		end
		Game.GlobalTxt[172]=string.format("활력: %s\n\n\n\n\n\n\n\n",StrColor(0,255,0,vitality))
	else
		Game.GlobalTxt[47]="Condition"
		Game.GlobalTxt[172]="퀵스펠"
	end
end


function events.GameInitialized2()
	for i=12,38 do
		Skillz.setDesc(i,1,Skillz.getDesc(i,1) .. "\n")
	end
end

function calcPowerVitality(pl, statsMenu)
	local DPS1=0
	local DPS2=0
	local DPS3=0
	--get spell and its damage
	spellIndex = pl.AttackSpell==0 and pl.QuickSpell or pl.AttackSpell
	--MELEE
	local low=pl:GetMeleeDamageMin()
	local high=pl:GetMeleeDamageMax()
	local accuracy=pl:GetAccuracy()
	local luck=pl:GetLuck()
	local delay=pl:GetAttackDelay()
	local dmg=(low+high)/2
	--hit chance
	local atk=pl:GetMeleeAttack()
	local lvl=MawReferenceLevel()
	local hitChance= MawCore.Formulas.mawHitChance(atk, lvl,
		MawCore.Formulas.blessHitBonus(pl)) or 0
	local critChance, critMult=getCritInfo(pl,false,lvl)
	local enchantDamage=0
	for i=0,1 do
		local it=pl:GetActiveItem(i)
		if it and it:T().EquipStat<=2 then
			local dmg1=calcEnchantDamage(pl, it, 0, false, false, "power")
			local dmg2=calcFireAuraDamage(pl, it, 0, false, false, "power")
			enchantDamage=enchantDamage+dmg1+dmg2+MawArtifactOnHitPower(it, pl)
		end
	end
	DPS1=round((dmg*(1+math.min(critChance,1)*(critMult-1))+enchantDamage)/(delay/60)*hitChance*damageMultiplier[pl:GetIndex()]["Melee"]*math.max(critChance,1))
	

	--RANGED
	local low=pl:GetRangedDamageMin()
	local high=pl:GetRangedDamageMax()
	local delay=pl:GetAttackDelay(true)
	local dmg=(low+high)/2
	--hit chance
	local atk=pl:GetRangedAttack()
	local hitChance= MawCore.Formulas.mawHitChance(atk, lvl,
		MawCore.Formulas.blessHitBonus(pl)) or 0
	local it=pl:GetActiveItem(2)
	enchantDamage=0
	if it and it:T().EquipStat<=2 then
		local dmg=calcEnchantDamage(pl, it, 0, false, false, "power")
		local dmg2=calcFireAuraDamage(pl, it, 0, false, false, "power")
		enchantDamage=enchantDamage+dmg+dmg2+MawArtifactOnHitPower(it, pl)
	end
	local s,m=SplitSkill(pl.Skills[const.Skills.Bow])
	if m>=3 then
		dmg=dmg*2
	end
	local DPS2=round((dmg*(1+math.min(critChance,1)*(critMult-1))+enchantDamage)/(delay/60)*hitChance*damageMultiplier[pl:GetIndex()]["Ranged"]*math.max(critChance,1))
	if spellPowers[spellIndex] or (healingSpells and healingSpells[spellIndex]) then 
		--calculate damage
		--skill
		skillType=math.floor((spellIndex-1)/11)+12
		skill, mastery=SplitSkill(pl:GetSkill(skillType))
		local mastery=math.max(1,mastery)
		--SPELLS
		local ascensionSkill, m = SplitSkill(pl:GetSkill(const.Skills.Learning))
		if spellPowers[spellIndex] then
			diceMin, diceMax, damageAdd = ascendSpellDamage(ascensionSkill, m, spellIndex)
		else
			diceMin, diceMax, damageAdd = healingSpells[spellIndex].Scaling[mastery], healingSpells[spellIndex].Scaling[mastery], healingSpells[spellIndex].Base[mastery]
		end
		
		power=damageAdd + skill*(diceMin+diceMax)/2
		if spellIndex==111 then
			if mastery==3 then
				power=power/3*5
			elseif mastery>=4 then
				power=power/3*7
			end
		end
		intellect=pl:GetIntellect()	
		personality=pl:GetPersonality()
		if healingSpells and healingSpells[spellIndex] then
			critChance, critDamage=getCritInfo(pl, "heal")
			local level = pl.LevelBase
			power=power*(1+personality/math.min(1000+level*3, 4000))  -- Personality affects healing
		else
			critChance, critDamage=getCritInfo(pl, "spell",lvl)
			power=power*(1+getIntellectDamageMultiplier(intellect, lvl))   -- Intellect affects spell damage, might curve
		end
		enchantDamage=0
		for i=0,2 do 
			local it=pl:GetActiveItem(i)
			if it and it:T().EquipStat<=2 then
				local dmg=calcEnchantDamage(pl, it, 0, false, true, "power")
				local dmg2=calcFireAuraDamage(pl, it, 0, false, true, "power")
				enchantDamage=enchantDamage+dmg+dmg2
			end
		end
		enchantDamage=enchantDamage*1.02^ascensionSkill
		if table.find(aoespells, spellIndex) then
			enchantDamage=enchantDamage/2.5
			if vars.madnessMode then
				--enchantDamage=enchantDamage*0.7
			end
		end
		haste=math.floor(pl:GetSpeed()/10)/100+1
		delay=getSpellDelay(pl,spellIndex) or 100
		DPS3=round((power*(1+math.min(critChance,1)*(critDamage-1))+enchantDamage)/(delay/60)*math.max(critChance,1))			
	end
	
	buffManaLock()
	local fullHP=GetMaxHP(pl)
	local id=pl:GetIndex()
	for i=0,Party.High do
		if Party[i]:GetIndex()==id then
			if vars.manaShield and vars.manaShield[i] then
				local sp=getMaxMana(pl)
				local s, m= SplitSkill(Skillz.get(pl, 51))
				local efficiency=round(manaShieldManaEfficiency(false, s)*100)/100
				fullHP=fullHP+sp*efficiency
			end
		end
	end
	--AC
	local lvl=MawReferenceLevel()
	local acReduction=1-calcMawDamage(pl,4,10000,false,lvl,true)/10000
	local chanceToGetHit=MawCore.Formulas.chanceToBeHit(pl:GetSpeed(), lvl)
	--dodging
	local speed=pl:GetSpeed()
	local dodging=0
	local Skill, Mas = SplitSkill(pl:GetSkill(const.Skills.Dodging))
	if Mas == 4 then
		dodging=Skill+10
	end
	--local speed=pl:GetSpeed()
	--local speedEffect=speed/10
	local dodgeChance=1/(1+dodging/200)
	if Game.CharacterPortraits[pl.Face].Race==const.Race.Dragon then
		dodgeChance = 1
	end
	local fullHP=fullHP/dodgeChance
	--resistances
	res={0,1,2,3,7,8,12}
	for v=1,7 do
		res[v]=1-calcMawDamage(pl,res[v],10000,false,lvl,true)/10000
	end
	
	--calculation
	local physShare=MawCore.Formulas.physicalVitalityShare
	local magicShare=(1-physShare)/8
	local magicTaken=(1-res[1])+(1-res[2])+(1-res[3])+(1-res[4])+(1-res[5])+(1-res[6])
	local reduction= ((1-acReduction)*physShare + magicTaken*magicShare
		+ (1-res[7])*magicShare*2)*chanceToGetHit
	
	vitality=round(fullHP/reduction)
	if statsMenu then
		DPS1=shortenNumber(DPS1, 3)
		DPS2=shortenNumber(DPS2, 3)
		DPS3=shortenNumber(DPS3, 3)
		vitality=shortenNumber(vitality, 3)
	end
	return DPS1, DPS2, DPS3, vitality
end

--racial skills down below
function events.CalcStatBonusByItems(t)

	local Res = t.Stat
	if not (Res >= 10 and Res <= 15) then
		return
	end
	
	local Race = GetRace(t.Player, t.PlayerIndex)
	local lvl=t.Player.LevelBase
	if Race == 6 and (Res == 15 or Res == 14) then -- Lich's immunities
		t.Result = 65000
		t.Player.Resistances[6].Base = 65000
		t.Player.Resistances[7].Base = 65000
	
	elseif Race == 1 and Res == 14 then -- Vampire's mind immunity
		t.Result = 65000
		t.Player.Resistances[7].Base = 65000
	
	elseif (Race == 2 or Race == 7) and (Res == 10 or Res == 11 or Res == 12 or Res == 13) then -- elves
		t.Result = t.Result+25 + lvl
	
	elseif Race == 4 and (Res == 12 or Res == 13) then -- Troll's Water and Earth resistance.
		t.Result = t.Result + 25 + lvl
		
	elseif Race == 8 and (Res == 11 or Res == 13) then -- Goblins's Air and Earth resistance.
		t.Result = t.Result + 25 + lvl

	elseif Race == 9 and (Res == 13 or Res == 14) then -- Dwarf's Mind and Earth resistance.
		t.Result = t.Result + 25 + lvl
	elseif Race == 5 and Res == 10 then -- Dragon's bonus
		t.Result = t.Result + 100 + math.floor(lvl*2)

	end	
	
end

function events.PlayerAttacked(t)
	setUnarmedToZero=2
end

function events.GetSkill(t)
	if t.Skill==33 and setUnarmedToZero and setUnarmedToZero>0 then
		t.Result=0
		setUnarmedToZero=setUnarmedToZero-1
	end
end




function GetHealParams(id)
	local base, scaling = healingSpells[id].Base[1], healingSpells[id].Scaling[1]
	
	-- Collect actual levels for each mastery
	local masteryLevels = {{}, {}, {}, {}}
	for j=1,1000 do
		local mastery = masteryPerLevel(j)
		table.insert(masteryLevels[mastery], j)
	end
	
	local averageRatios = {}
	for i=1,4 do
		local totalRatio = 0
		local count = 0
		local levelList = masteryLevels[i]
		
		-- If mastery has 50+ levels, print averages for every 50 levels
		if #levelList >= 50 then
			local segmentCount = math.floor(#levelList / 50)
			for segment = 1, segmentCount do
				local segmentStart = (segment - 1) * 50 + 1
				local segmentEnd = math.min(segment * 50, #levelList)
				local segmentTotal = 0
				local segmentSize = segmentEnd - segmentStart + 1
				
				for idx = segmentStart, segmentEnd do
					local k = levelList[idx]
					local base, scaling = healingSpells[id].Base[masteryPerLevel(k)], healingSpells[id].Scaling[masteryPerLevel(k)]
					local heal = getBodyHealing(k, id, masteryPerLevel(k))
					local health = getPlayerExtimatedHealth(k)
					local rateo = round(heal/health*100)/100
					segmentTotal = segmentTotal + rateo
				end
				
				if segmentSize > 0 then
					local segmentAverage = round(segmentTotal / segmentSize * 100) / 100
					local actualStartLevel = levelList[segmentStart]
					local actualEndLevel = levelList[segmentEnd]
					print("Mastery " .. i .. " levels " .. actualStartLevel .. "-" .. actualEndLevel .. ": " .. segmentAverage)
				end
			end
		end	
		
		-- Calculate overall average for the mastery
		for _, k in ipairs(levelList) do
			local base, scaling = healingSpells[id].Base[masteryPerLevel(k)], healingSpells[id].Scaling[masteryPerLevel(k)]
			local heal=getBodyHealing(k, id, masteryPerLevel(k))
			local health=getPlayerExtimatedHealth(k)
			local rateo=round(heal/health*100)/100
			totalRatio = totalRatio + rateo
			count = count + 1
		end
		if count > 0 then
			averageRatios[i] = round(totalRatio / count*100)/100
		else
			averageRatios[i] = 0
		end
		print(averageRatios[i])
	end

	return base, scaling
end

function masteryForSkill(S)
	local th = masteryThresholds()
	local m = 1
	for i = 4, 1, -1 do
	  if S >= th[i] then m = i; break end
	end
	return m
end

function masteryPerLevel(lvl)
	return masteryForSkill(estimateSkill(lvl))
end

--A mastery bonus phases in instead of jumping. The value a rank grants ramps
--from that rank's skill threshold to the next rank's (GM has no next rank, so
--it ramps to 1.4x its own: skill 10->14, or 50->70 in madness). Training a
--mastery is then a gradual gain rather than a step.
--tbl is any mastery-indexed table (armsmasterSkill.Damage, skillRecovery[x], ...)
function GetGradualMasteryValue(tbl, s, m)
	m = math.max(m or 0, 0)
	if m < 1 then
		return tbl[0] or 0
	end
	local th = masteryThresholds()
	local i = math.min(m, #th)
	local from = th[i]
	local to = th[i+1] or from*1.4
	local prev = tbl[m-1] or 0
	local cur = tbl[m] or prev
	if to <= from then
		return cur
	end
	return prev + (cur-prev)*math.min(math.max((s-from)/(to-from), 0), 1)
end

function masteryThresholds()
	if vars.madnessMode then
	  return {0, 10, 24, 40}
	elseif vars.insanityMode then
	  return {0, 8, 16, 25}
	else
	  return {0, 4, 7, 10}
	end
end

function GetDifficulty()
	local difficulty=3 --baseline
	local bolster=Game.BolsterAmount or 100
	if vars.madnessMode then
		difficulty=9
	elseif vars.insanityMode then
		difficulty=8
	elseif vars.Mode==2 then
		difficulty=7
	elseif bolster>=300 then
		difficulty=6
	elseif bolster>=200 then
		difficulty=5
	elseif bolster>=150 then
		difficulty=4
	elseif bolster>=100 then
		difficulty=3
	elseif bolster>=70 then
		difficulty=2
	else
		difficulty=1
	end
	return difficulty
end

--Tick handlers above run as MawCore scheduler tasks (ms; 0=frame, -1=poke only)
function events.GameInitialized2()
	local every=MawCore.Scheduler.every
	every("stats/label-watch", 0, mawTick_LabelWatch)
	every("stats/pool-labels", 250, mawTick_PoolLabels)
	every("stats/power-labels", 250, mawTick_PowerLabels)
end
