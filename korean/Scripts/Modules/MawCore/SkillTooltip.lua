-- SkillTooltip.lua -- per-player skill tooltip text (SKILL_TOOLTIPS.md).
--
-- The desc store holds static text only; anything dynamic is a builder
-- fn(pl, skillId, part) -> string registered per (skill, part) slot, and
-- getTooltipText(pl, skillId [, withBonus]) composes the hint at click time.
-- Return nil from a builder to fall through to the static store.
--
-- Slots: 1 = body, part n = mastery row for mastery n-1 (2 Novice, 3 Expert,
-- 4 Master, 5 Grand, 6 Supreme, ...).

local SkillTooltip = {}
MawCore.SkillTooltip = SkillTooltip

local Formulas = MawCore.Formulas

-- damageMultiplier (zzMAW-Skills) is only filled by the in-game skill
-- recalc; on the creation screen it's nil, so fall back to 1
local function meleeMult(pl)
	local t = damageMultiplier and damageMultiplier[pl:GetIndex()]
	return t and t.Melee or 1
end

function dkDamageRow()
	return dkDamageSkill[1] .. "-" .. dkDamageSkill[2] .. "-" .. dkDamageSkill[3]
end

-- index part -> row label; also the source for SkillsUI's mastery name
-- array (the engine's four name slots get redirected to these strings)
SkillTooltip.masteryNames = {"", "초보", "Expert", "Master", "Grand",
	"Supreme", "Ultimate", "Ascended", "Deity"}

local builders = {}		-- [skillId][part] = {fn = fn, label = label}

function SkillTooltip.set(id, part, fn, label)
	builders[id] = builders[id] or {}
	assert(not builders[id][part],
		("skill tooltip: builder %d/%d already registered"):format(id, part))
	builders[id][part] = {fn = fn, label = label or "?"}
end

function SkillTooltip.remove(id, part)
	if builders[id] and builders[id][part] then
		builders[id][part] = nil
		return true
	end
	return false
end

-- builder first, static desc store second
function SkillTooltip.partText(pl, id, part)
	local b = builders[id] and builders[id][part]
	if b then
		local text = b.fn(pl, id, part)
		if text then
			return text
		end
	end
	return Skillz.getDesc(id, part)
end

function SkillTooltip.getTooltipText(pl, skillId, withBonus)
	if withBonus == nil then
		withBonus = true
	end
	local race = Game.CharacterPortraits[pl.Face].Race
	local clas = pl.Class
	local mNames = SkillTooltip.masteryNames
	local s = {SkillTooltip.partText(pl, skillId, 1), " \n"}
	for part = 2, 20 do
		local txt = SkillTooltip.partText(pl, skillId, part)
		local mn = mNames[part]
		if not txt or txt == "" or not mn or mn == "" then
			break
		end
		local m = part - 1
		local r, g, b = 255, 0, 0
		if MawCore.Skills.API.MasteryTable_get(race, clas, skillId) >= m then
			r, g, b = 255, 255, 255
		elseif MawCore.Skills.API.MasteryTable_get(race,
				MawCore.Skills.nextClass(clas), skillId) >= m then
			r, g, b = 255, 255, 0
		end
		s[#s + 1] = StrColor(r, g, b,
			string.format("%s:\t%03d%s\t000\n", mn, 72, txt))
	end
	if withBonus then
		local raw = Skillz.get(pl, skillId)
		local buffed = pl:GetSkill(skillId)
		local diff = bit.band(buffed, 0x3FF) - bit.band(raw, 0x3FF)
		if diff ~= 0 then
			s[#s + 1] = string.format("\n\n Bonus: %s%d", diff > 0 and "+" or "", diff)
		end
	end
	return table.concat(s)
end

function SkillTooltip.describe()
	local out = {"skill tooltip builders:"}
	local ids = {}
	for id in pairs(builders) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local parts = {}
		for part in pairs(builders[id]) do
			parts[#parts + 1] = part
		end
		table.sort(parts)
		-- one line per id when every part shares a label, else one per slot
		local label = builders[id][parts[1]].label
		for _, part in ipairs(parts) do
			if builders[id][part].label ~= label then
				label = nil
				break
			end
		end
		if label then
			out[#out + 1] = ("  %3d/%s %s"):format(id, table.concat(parts, ","), label)
		else
			for _, part in ipairs(parts) do
				out[#out + 1] = ("  %3d/%d %s"):format(id, part, builders[id][part].label)
			end
		end
	end
	if #out == 1 then
		out[#out + 1] = "  (none)"
	end
	return table.concat(out, "\n")
end

------------------------------------------------------------------------
-- Dynamic builders -- bodies verbatim from the legacy Tick/Action
-- rewriters. Base strings stay captured in the legacy files (timing) and
-- per-player vars are still read via Game.CurrentPlayer: SKILL_TOOLTIPS.md.
------------------------------------------------------------------------

-- was zzMAW-Skills.lua "DINAMIC SKILL TOOLTIP" events.Tick

SkillTooltip.set(30, 1, function(pl)
	local FHP = GetMaxHP(pl)
	local s, m = SplitSkill(pl:GetSkill(30))
	local raw = Formulas.hpRegenPerSec(FHP, s, m)
	local hpRegen = round(raw * 10) / 10
	local hpRegen2 = round(Formulas.hpRegenPerSec(FHP, s + 1, m) * 10) / 10
	local pct = FHP > 0 and round(raw/FHP * 1000) / 10 or 0
	local nextBonus = round((hpRegen2 - hpRegen) * 10) / 10
	local txt = string.format("%s\n\n현재 생명력 재생: %s (초당 최대 생명력의 %s)\n다음 레벨 보너스: 생명력 재생 %s", baseRegStr, StrColor(0, 255, 0, hpRegen), StrColor(0, 255, 0, pct .. "%"), StrColor(0, 255, 0, "+" .. nextBonus))
	--dragon melee leech, shown only for dragons
	local leech = getDragonRegenLeech(pl)
	if leech > 0 then
		local leechNext = leech * (s + 1) / s
		txt = txt .. string.format("\n\n동일 레벨 대상 근접 흡혈: %s\n다음 레벨 보너스: %s\n(더 높은 레벨의 몬스터에게는 효과 감소)",
			StrColor(255, 80, 80, round(leech * 1000) / 10 .. "%"),
			StrColor(255, 80, 80, "+" .. round((leechNext - leech) * 1000) / 10 .. "%\n"))
	end
	return txt
end, "regeneration + dragon leech")

SkillTooltip.set(28, 1, function(pl)
	local slot = Game.CurrentPlayer
	local raw = getMeditationRegen(slot)
	local spRegen2 = round((getMeditationRegen(slot, 1) - raw) * 100) / 100
	local spRegen = raw > 10 and round(raw * 10) / 10 or round(raw * 100) / 100
	return string.format("%s\n\n레벨당 주문력과 숙련도에 따라 주문력 재생이 증가합니다.\n\n현재 주문력 재생: %s\n다음 레벨 보너스: 주문력 재생 %s\n", baseMedStr, StrColor(60, 60, 255, spRegen), StrColor(60, 60, 255, "+" .. spRegen2))
end, "meditation SP regen")

SkillTooltip.set(const.Skills.Learning, 1, function(pl)
	local s, m = SplitSkill(pl:GetSkill(const.Skills.Learning))
	local F = MawCore.Formulas
	local dmgMult = shortenNumber(round((F.spellDiceScale(s) - 1) * 100), 3)
	local dmgBaseMult = shortenNumber(round((F.spellAddScale(s) - 1) * 100), 3)
	local healMult = shortenNumber(round(((1 + 0.05 * s) * 1.02 ^ s - 1) * 100), 3)
	local healBaseMult = shortenNumber(round(((1 + 0.03 * s ^ 2) * 1.02 ^ s - 1) * 100), 3)
	local masteryReduction = (1 - m * 0.125)
	local manaMult = shortenNumber(round(((1 + 0.125 * s) * 1.04 ^ s - 1) * masteryReduction * 100), 3)
	local castMult = shortenNumber(round((1.015 ^ s - 1) * 100), 3)
	return string.format("%s\n\n기술 %s의 현재 보너스:\n- 기본 피해: %s\n- 피해 배율: %s\n\n- 기본 치유량: %s\n- 치유 배율: %s\n\n- 마나 소모: %s\n- 시전 시간: %s\n",
		baseAscStr,
		StrColor(255, 255, 100, s),
		StrColor(0, 255, 0, "+" .. dmgBaseMult .. "%"),
		StrColor(0, 255, 0, "+" .. dmgMult .. "%"),
		StrColor(0, 255, 0, "+" .. healBaseMult .. "%"),
		StrColor(0, 255, 0, "+" .. healMult .. "%"),
		StrColor(255, 100, 100, "+" .. manaMult .. "%"),
		StrColor(255, 100, 100, "+" .. castMult .. "%"))
end, "ascension bonuses")

SkillTooltip.set(const.Skills.Spear, 5, function(pl)
	local s = SplitSkill(pl:GetSkill(const.Skills.Spear))
	local mult = meleeMult(pl)
	local damageIncrease = round((2 + s * 0.02) * mult * 10) / 10
	local it = pl:GetActiveItem(1)
	if it then
		if it:T().Skill == 4 and it:T().EquipStat == 1 then
			damageIncrease = damageIncrease * 1.5
		end
	end
	return string.format("%s\n\t070창 공격마다 대상이 받는 물리 피해가 %s%% 증가하며, 죽을 때까지 중첩됩니다.\n미늘창 사용 시 효과가 50%% 증가합니다", baseSpearTooltip, damageIncrease)
end, "spear GM damage taken stacks")

-- was zzMAW-Skills.lua armor events.Action (RunNextTick on the skill screen)

local armorBase = {
	[8] = "방패 기술은 물리 공격과 마법 공격 모두에 뛰어난 방어력을 제공합니다.\n\n방패 기술은 방패에서 얻는 방어력과 저항을 일정 비율만큼 높입니다.",
	[9] = "가죽 갑옷은 착용할 수 있는 가장 가벼운 방어구입니다. 사슬이나 판금 갑옷보다 보호력은 낮지만 행동 속도 감소도 가장 적습니다.\n\n가죽 갑옷을 장비하면 가죽 갑옷 기술이 모든 방어구에서 얻는 방어력과 저항을 일정 비율만큼 높입니다.",
	[10] = "사슬 갑옷은 중간 무게의 방어구입니다. 가죽 갑옷보다 보호력이 높고 판금 갑옷보다는 낮지만, 가죽 갑옷보다 행동을 더 느리게 만듭니다.\n\n사슬 갑옷을 장비하면 사슬 갑옷 기술이 모든 방어구에서 얻는 방어력과 저항을 일정 비율만큼 높입니다.",
	[11] = "판금 갑옷은 가장 무거운 방어구입니다. 가장 높은 보호력을 제공하지만 가죽이나 사슬 갑옷보다 행동을 더 느리게 만듭니다.\n\n판금 갑옷을 장비하면 판금 갑옷 기술이 모든 방어구에서 얻는 방어력과 저항을 일정 비율만큼 높입니다.",
}

local function armorPart1(pl, id)
	itemStats(pl:GetIndex())
	local txt = armorBase[id]
	local it = pl:GetActiveItem(3)
	if it and it:T().Skill == id then
		txt = txt .. "\n\n아이템으로 얻는 현재 방어력: " .. StrColor(255, 255, 100, armorAC) .. "\n"
		txt = txt .. "추가 방어력: " .. StrColor(255, 255, 100, itemArmorClassBonus1) .. "\n"
		txt = txt .. "추가 저항: " .. StrColor(255, 255, 100, itemResistanceBonus1) .. "\n"
	end
	local it = pl:GetActiveItem(0)
	if it and id == 8 and it:T().Skill == 8 then
		txt = txt .. "\n\n추가 방어력: " .. StrColor(255, 255, 100, itemArmorClassBonus2) .. "\n"
		txt = txt .. "추가 저항: " .. StrColor(255, 255, 100, itemResistanceBonus2) .. "\n"
	end
	txt = txt .. "\n------------------------------------------------------------\n         \t075AC| Res\t000"
	return txt
end

for id = 8, 11 do
	SkillTooltip.set(id, 1, armorPart1, "armor AC/Res from items")
end

-- was zzMAW-Skills.lua "COVER SKILL" events.Tick (desc parts only; the
-- Game.GlobalTxt[143] category-header juggling stays in the legacy Tick)

-- per-player toggle state tail (cover / mana shield); inits the vars table
-- with everyone enabled, as the legacy Tick did
local function toggleState(name)
	if not vars[name] then
		vars[name] = {}
		for i = 0, 4 do
			vars[name][i] = true
		end
	end
	if vars[name][Game.CurrentPlayer] then
		return StrColor(0, 255, 0, "\n현재 활성화됨\n")
	end
	return StrColor(255, 0, 0, "\n현재 비활성화됨\n")
end

SkillTooltip.set(50, 1, function(pl)
	local s = SplitSkill(Skillz.get(pl, 50))
	local chance = math.min(10 + s, 10 + skillCap[50])
	local solo = ""
	if Party.Count <= 1 then
		local cut = round((1 - MawCore.Formulas.soloCoverDamageTaken)*100)
		solo = StrColor(178, 255, 255, "\n\n홀로 여행할 때는 자신을 해치려는 적과 직접 맞서야 합니다. 보호할 동료가 없으므로 엄호는 자신을 지킵니다. 엄호 성공 시 공격을 막아 피해를 "
			.. cut .. "%만큼 피해를 줄이며, 이때도 반격이 발동합니다.")
	end
	return "엄호는 동료가 받을 피해를 대신 가로막는 방어 기술입니다. 적의 공격을 자신에게 집중시켜 취약한 동료를 보호합니다.\n\n습득 가능한 경우 전문가·마스터·그랜드마스터의 요구 기술 레벨: "
		.. (vars.insanityMode and "8-20-30" or "6-12-20")
		.. ".\n\n엄호 확률은 기본 10%에 기술 포인트당 1%가 추가되며, 최대 40%입니다. 다만 최고 레벨에 도달하면 무언가 달라질 수도 있습니다...\n\n현재 엄호 확률: " .. chance .. "%"
		.. solo .. "\n\nP 키로 활성화/비활성화\n"
		.. toggleState("covering")
end, "cover chance + toggle state")

SkillTooltip.set(51, 1, function(pl)
	local s = SplitSkill(Skillz.get(pl, 51))
	local efficiency = round(manaShieldManaEfficiency(false, s) * 100) / 100
	return "마나 방패는 공격으로 생명력이 일정 기준 아래로 떨어질 때 주문력을 소모하여 피해를 줄입니다.\n\n습득 가능한 경우 전문가·마스터·그랜드마스터의 요구 기술 레벨: "
		.. (vars.insanityMode and "8-20-32" or "6-12-20")
		.. ".\n\n숙련도가 높아질수록 주문력 효율이 증가하며, 다음 기술 레벨을 넘으면 더 이상 증가하지 않습니다: "
		.. skillCap[51] .. ".\n" .. "마나당 현재 피해 감소: " .. StrColor(178, 255, 255, efficiency) .. "\n\nM키로 활성화/비활성화"
		.. toggleState("manaShield")
end, "mana shield efficiency + toggle state")

SkillTooltip.set(53, 1, function(pl)
	local powerMult, DPS2, DPS3, vitMult = calcPowerVitality(pl)
	local power, vit = MawCore.Formulas.retaliationCoefficients(powerMult, vitMult)
	local retS = SplitSkill(Skillz.get(pl, 53))
	local ladder = skillMasteryLadder[53].normal
	return "엄호를 숙달한 당신은 동료를 해치려는 적에게 치명적인 반격을 가할 수 있습니다. 엄호 성공 시 기술 포인트당 1%의 확률로 반격이 발동합니다. 동료를 엄호할 때뿐 아니라 홀로 여행하며 자신을 엄호할 때도 적용됩니다.\n\n전문가·마스터·그랜드마스터는 다음 기술 레벨에서 자동으로 습득합니다: " .. ladder[1] .. ", " .. ladder[2] .. " and " .. ladder[3] .. ".\n\n피해량은 두 계수를 곱한 뒤 기술 레벨을 곱해 결정됩니다.\n\n근접 위력 계수: " .. StrColor(255, 0, 0, power) .. "\n활력 계수: " .. StrColor(255, 0, 0, vit) .. "\n\n총 피해: " .. StrColor(255, 0, 0, retS * vit * power) .. "\n\n위력과 활력을 균형 있게 높이면 가장 높은 피해를 낼 수 있습니다.\n"
end, "retaliation coefficients")

-- was zzMAW-Skills.lua mace events.Action (RunNextTick on the skill screen)

SkillTooltip.set(6, 5, function(pl)
	local s, m = SplitSkill(pl:GetSkill(const.Skills.Mace))
	if m < 3 then
		return maceGMtxt
	end
	local refLvl = MawReferenceLevel()
	local chance = round(s / estimateSkill(refLvl) * 1500 * meleeMult(pl) / math.min(1 + refLvl / 150, 3)) / 100
	local txt = "\n\n"
	if m == 3 then
		txt = txt .. "기절 확률 (대상 레벨: " .. refLvl .. ": " .. chance .. "%"
	elseif m >= 4 then
		txt = txt .. "마비 확률 (대상 레벨: " .. refLvl .. ": " .. chance .. "%"
	end
	return maceGMtxt .. StrColor(0, 0, 0, txt)
end, "mace stun/paralyze chance")

-- was zzMAW-Skills.lua armsmaster events.LoadMap (requirement varies with
-- madness/insanity mode, so per save, not per player)

SkillTooltip.set(35, 1, function(pl)
	local requirement = GetArmsmasterSupremeRequirement()
	return Skillz.getDesc(35, 1) .. "\n기사는 최상위 단계까지 습득할 수 있으며, 해당 단계는 기술 레벨 " .. requirement .. ".\n"
end, "armsmaster supreme requirement")


------------------------------------------------------------------------
-- Class school tooltips (12-20) + dragon fangs/scales (32/33), as data:
-- classSpecs[n].slots[skillId][part] = string, or function(pl) when the
-- text carries numbers. Dispatch order, the neutral fallbacks and why
-- registration waits for GameInitialized2: SKILL_TOOLTIPS.md.
------------------------------------------------------------------------

local function registerClassBuilders()
	local ST=MawCore.SkillTooltip
	local EV="효과는 주문마다 다릅니다"
	local ASC="\n\n기술 레벨 7마다 승천 레벨이 1 증가합니다.\n"

	--what the old reset branches forced, where that differs from the store:
	--EV mastery rows for 16-19, plus the part-1 school texts from
	--MawSchoolDescBase (captured by zzClasses.lua at its legacy position,
	--before the later "\n"-append init handlers -- capture timing is part
	--of the displayed text)
	local neutralText={
		[16]={[2]=EV,[3]=EV,[4]=EV},
		[17]={[2]=EV,[3]=EV,[4]=EV},
		[18]={[2]=EV,[3]=EV,[4]=EV},
		[19]={[2]=EV,[3]=EV,[4]=EV,[5]=EV},
		[20]={[1]=MawSchoolDescBase[20]},
	}
	for id=12,15 do
		neutralText[id]={[1]=MawSchoolDescBase[id]}
	end

	local classSpecs={

	--was shamanSkills(true)
	{match=function(pl) return table.find(shamanClass, pl.Class) end, slots={
		[12]={[1]=function(pl)
			local m1=SplitSkill(pl.Skills[const.Skills.Fire])
			return MawSchoolDescBase[12] .. ASC .. "근접 공격의 추가 피해: " .. m1/10 .. "%만큼 추가 화염 피해를 줍니다."
		end},
		[13]={[1]=function(pl)
			local m2=SplitSkill(pl.Skills[const.Skills.Air])
			local airReduction=Formulas.reductionPercent(m2)
			return MawSchoolDescBase[13] .. ASC .. "받는 모든 피해 감소량: " .. airReduction .. "%\n"
		end},
		[14]={[1]=function(pl)
			local m3=SplitSkill(pl.Skills[const.Skills.Water])
			local lvl=getPartyLevel(4)
			local _,_,_,avgTaken=getPlayerEstimatedVitality(lvl+1)
			local waterReduction=round(getMonsterDamage(false,(lvl+1))*(m3/estimateSkill(lvl))*avgTaken*0.99^estimateSkill(lvl)/2) --on average 1/2 of a B monster
			return MawSchoolDescBase[14] .. ASC .. "받는 모든 피해 감소량: " .. waterReduction .. "(저항 적용 후 계산)\n"
		end},
		[15]={[1]=MawSchoolDescBase[15] .. ASC .. "대지 마법 기술 레벨당 근접 피해가 0.5-1-1.5-2 증가합니다 (초보-전문가-마스터-그랜드마스터).\n"},
		[16]={[1]=function(pl)
			local m5=SplitSkill(pl.Skills[const.Skills.Spirit])
			return MawSchoolDescBase[16] .. ASC .. "근접 피해 증가량: " .. m5 .. "%\n"
		end},
		[17]={[1]=function(pl)
			local m6=SplitSkill(pl.Skills[const.Skills.Mind])
			local spLeech=round(Formulas.mindLeech(m6))
			return MawSchoolDescBase[17] .. ASC .. "근접 공격 시 회복량: " .. spLeech .. " 주문력\n"
		end},
		[18]={[1]=function(pl)
			local m7, bodyMastery=SplitSkill(pl.Skills[const.Skills.Body])
			local FHP=pl:GetFullHP()
			local leech=Formulas.bodyLeech(FHP, m7, bodyMastery)
			return MawSchoolDescBase[18] .. ASC .. "근접 공격 시 회복량: " .. leech .. " 생명력\n"
		end},
	}},

	--was dkSkills(true) desc lines
	{match=function(pl) return table.find(dkClass, pl.Class) end, slots={
		[14]={[1]=function(pl)
			return "죽음의 기사만 사용할 수 있는 기술입니다. 피해 증가량: "
				.. dkDamageRow() .. " (기술 포인트당; 초보·전문가·마스터에 적용, 그랜드마스터는 추가 없음)"
				.. " 또한 기술 포인트당 공격 속도가 1% 증가합니다.\n"
		end,
			[5]=EV},
		[18]={[1]=function(pl)
			local bloodS=SplitSkill(pl.Skills[const.Skills.Body])
			local blood=Formulas.dkBloodLeech*100
			return "죽음의 기사만 사용할 수 있는 기술입니다. 받는 물리 피해가 감소합니다.\n"
				.. "현재 피해 감소: " .. Formulas.reductionPercent(bloodS) .."%\n\n"
				.. "또한 공격 시 흡수하는 생명력은 가한 물리 피해의 " .. blood .. "%입니다 (활 사용 시 "
				.. blood/2 .. "%의 생명력을 흡수합니다). 무기의 흡혈 마법부여와 중첩됩니다.\n"
		end,
			[5]=EV},
		[20]={[1]=function(pl)
			local unholyS=SplitSkill(pl.Skills[const.Skills.Dark])
			return "죽음의 기사만 사용할 수 있는 기술입니다. 피해 증가량: "
				.. dkDamageRow() .. " (기술 포인트당; 초보·전문가·마스터에 적용, 그랜드마스터는 추가 없음)"
				.. " 또한 받는 마법 피해를 줄입니다.\n"
				.. "현재 피해 감소: " .. Formulas.reductionPercent(unholyS) .."%\n"
		end},
	}},

	--was seraphSkills(true)
	{match=function(pl) return table.find(seraphClass, pl.Class) end, slots={
		[16]={[1]=function(pl)
			local spiritS=SplitSkill(pl.Skills[const.Skills.Spirit])
			local lvl=getTotalLevel()
			local _,_,_,avgTaken=getPlayerEstimatedVitality(lvl+1)
			local spiritReduction=round(getMonsterDamage(false,(lvl+1))*(spiritS/estimateSkill(lvl))*avgTaken/2*0.99^estimateSkill(lvl)) --on average 1/2 of a B monster
			return MawSchoolDescBase[16] .. "\n\n세라프의 영혼은 세라프의 결의를 강화하여 가벼운 공격은 흘려내고 강한 공격의 피해를 줄입니다.\n" .. "피해 감소: " .. StrColor(0,255,0,spiritReduction) .. " (저항 적용 후 계산)\n"
		end},
		[17]={[1]=function(pl)
			local mindS, mindM=SplitSkill(pl.Skills[const.Skills.Mind])
			return MawSchoolDescBase[17] .. "\n\n세라핌의 공격 시 피해는 정신 마법에 따라 증가하고 힘에 비례합니다(무기 속도와 무기 피해 배율이 적용됩니다).\n\n" .. "정신 마법으로 얻는 현재 피해: " .. StrColor(255,0,0,round(mindS*(mindM+1)/2)) .. "\n"
		end,
			[2]="기술 포인트당 피해가 1 증가합니다",
			[3]="기술 포인트당 피해가 1.5 증가합니다",
			[4]="기술 포인트당 피해량이 2 증가합니다",
			[5]="n/a"},
		[18]={[1]=function(pl)
			local bodyS, bodyM=SplitSkill(pl.Skills[const.Skills.Body])
			local healMult=1+pl:GetPersonality()/1000
			local bodyHeal=round(bodyS^1.3*bodyM*meleeMult(pl)*healMult*2)
			return MawSchoolDescBase[18] .. "\n\n세라핌의 공격 시 회복량은 육체 마법에 따라 증가하고 인격에 비례합니다(무기 속도 배율이 적용됩니다).\n\n" .. "육체 마법으로 얻는 현재 회복량: " .. StrColor(0,255,0,bodyHeal) .. "\n"
		end,
			[2]="근접 공격 적중 시 생명력을 회복합니다",
			[3]="회복 효과가 2배가 됩니다",
			[4]="회복 효과가 3배가 됩니다",
			[5]="n/a"},
		[19]={[1]=MawSchoolDescBase[19]
				.. StrColor(255,255,30,"\n\n빛 마법은 세라핌의 공격을 가속하여 공격 속도를 높입니다.\n\n그 빛은 칼날을 매우 가볍게 만들어 양손검도 한 손으로 사용할 수 있게 하며, 다른 손에는 방패를 들 수 있습니다.\n"),
			[2]="기술 포인트당 공격 속도가 0.5% 증가합니다",
			[3]="기술 포인트당 공격 속도가 1% 증가합니다",
			[4]="기술 포인트당 공격 속도가 1.5% 증가합니다",
			[5]="기술 포인트당 공격 속도가 2% 증가합니다"},
	}},

	--was elementalistSkills(true) desc loop
	{match=function(pl) return table.find(elementalistClass, pl.Class) end, slots=(function()
		local function progressionText(pl, id)
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
			local progression=list[id]
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
				return EV .. " \n\n" .. rotationText .. "원소술사는 책 대신 실전을 통해 새로운 주문을 익힙니다.\n\n다음 주문 습득 진행도: " .. Game.SpellsTxt[(id-12)*11+currentTier+1].Name .. ": " .. percentageProgression .."%"
			else
				return EV .. " \n\n" .. rotationText .. "원소술사는 책 대신 실전을 통해 새로운 주문을 익힙니다.\n\n이 계통에서 배울 수 있는 주문을 모두 습득했습니다."
			end
		end
		local slots={}
		for id=12,15 do
			slots[id]={[5]=progressionText}
		end
		return slots
	end)()},

	--was assassinSkills(true) desc lines
	{match=function(pl) return table.find(assassinClass, pl.Class) end, slots={
		[12]={[1]="전투 기술은 에너지 회복을 강화하여 장기전에 버틸 수 있게 합니다.\n\n공격할 때마다 기본 10%에 기술 포인트당 1%를 더한 확률로 에너지 15를 회복합니다.\n\n",
			[2]="근접 공격에 에너지 45를 소모합니다",[3]="근접 공격에 에너지 40을 소모합니다",[4]="근접 공격에 에너지 35를 소모합니다",[5]="근접 공격에 에너지 30을 소모합니다"},
		[13]={[1]="기민함은 삶과 죽음의 경계를 다루어 적을 처치할 때 기력을 얻고 속도를 높여 줍니다.\n\n기력을 소모하는 공격은 중첩 효과를 1회 부여합니다. 중첩당 기민함 기술 포인트마다 공격 속도가 0.5% 증가하며, 최대 5회 중첩됩니다.\n\n",
			[2]="몬스터 처치 시 에너지 10을 회복합니다",[3]="몬스터 처치 시 에너지 15를 회복합니다",[4]="몬스터 처치 시 에너지 20을 회복합니다",[5]="몬스터 처치 시 에너지 25를 회복합니다"},
		[14]={[1]="독은 스스로 독을 시험하며 독성을 다루는 법을 익혀 고통을 활력으로 바꾸는 기술입니다. 기술 레벨이 높을수록 에너지 재생이 증가합니다.\n\n공격할 때마다 기술 포인트당 대상 생명력의 0.1%에 해당하는 추가 물 피해를 줍니다.\n\n",
			[2]="재생하는 양: " .. Formulas.assassinEnergyPerSec(1) .. " 기력/초",[3]="재생하는 양: " .. Formulas.assassinEnergyPerSec(2) .. " 기력/초",[4]="재생하는 양: " .. Formulas.assassinEnergyPerSec(3) .. " 기력/초",[5]="재생하는 양: " .. Formulas.assassinEnergyPerSec(4) .. " 기력/초"},
		[15]={[1]="암살은 고립된 대상을 반응하기 전에 제거하는 데 특화돼 있습니다. 기력을 소모하는 공격이나 주문의 피해가 기술 포인트당 2-3-4-5 증가합니다. 대상 근처의 적 하나당 증가량이 20% 감소하며, 최대 4명까지 적용됩니다.\n이러한 공격은 연계 포인트도 1 부여하여 암살자가 공격 주문을 시전할 수 있게 합니다.\n활은 발동 확률과 기력 소모량이 각각 50%입니다.\n\n레벨이 높아질수록 시작 기력도 증가하여 짧은 교전에서 폭발적인 피해를 주기 좋습니다.\n\n",
			[2]="최대 에너지가 10 증가합니다",[3]="최대 에너지가 20 증가합니다",[4]="최대 에너지가 30 증가합니다",[5]="최대 에너지가 40 증가합니다"},
	}},

	}

	local function slotText(slots, pl, id, part)
		local slot=slots[id]
		local v=slot and slot[part]
		if type(v)=="function" then
			v=v(pl, id)
		end
		return v
	end

	local function classText(pl, id, part)
		for i=1,#classSpecs do
			if classSpecs[i].match(pl) then
				local v=slotText(classSpecs[i].slots, pl, id, part)
				if v then
					return v
				end
				break
			end
		end
		return neutralText[id] and neutralText[id][part]
	end

	--register exactly the slots the tables above declare
	local covered={}
	local function cover(slots)
		for id, parts in pairs(slots) do
			covered[id]=covered[id] or {}
			for part in pairs(parts) do
				covered[id][part]=true
			end
		end
	end
	for i=1,#classSpecs do
		cover(classSpecs[i].slots)
	end
	cover(neutralText)
	for id, parts in pairs(covered) do
		for part in pairs(parts) do
			ST.set(id, part, classText, "class school text")
		end
	end

	--was dragonSkill desc + engine-array writes: dragons swap Unarmed/Dodging
	--for Fangs/Scales by RACE, independent of the class system above (their
	--slots don't overlap it)
	local dragonSlots={
		[33]={[1]=function(pl)
			local cap=vars.madnessMode and 900 or 600
			return "용은 송곳니로 적에게 막대한 피해를 줍니다. 기본 피해는 30이며 레벨당 2가 추가됩니다 (적용 레벨 상한: " .. cap .. "). 송곳니 기술은 숙련도와 기술 레벨에 따른 비율로 이 피해를 높입니다.\n\n이 기술이 용 기술보다 낮으면 몬스터를 밀쳐냅니다.\n기술 포인트마다 피해와 회복 시간이 1.5% 증가합니다.\n" .. "\n------------------------------------------------------------\n            공격| 피해|"
		end,
			[2]=fangsNormal,[3]=fangsExpert,[4]=fangsMaster,[5]=fangsGM},
		[32]={[1]=function(pl)
			local cap=vars.madnessMode and 900 or 600
			return "용의 비늘은 천연 방어구 역할을 합니다. 기본 방어력은 40이며 레벨당 1이 추가됩니다 (적용 레벨 상한: " .. cap .. ").\n비늘은 강인함과 마법 피해 저항을 더욱 높이며, 강인함을 일정 비율로 증가시킵니다.\n\n------------------------------------------------------------\n          방어력%| 저항%"
		end,
			[2]=scalesNormal,[3]=scalesExpert,[4]=scalesMaster,[5]=scalesGM},
	}
	local function dragonText(pl, id, part)
		if Game.CharacterPortraits[pl.Face].Race~=const.Race.Dragon then
			return nil
		end
		return slotText(dragonSlots, pl, id, part)
	end
	for id, parts in pairs(dragonSlots) do
		for part in pairs(parts) do
			ST.set(id, part, dragonText, id==33 and "dragon fangs" or "dragon scales")
		end
	end
end

function SkillTooltip.start()
	function events.GameInitialized2()
		registerClassBuilders()
	end
end