-- A use for the Druid Circlet of Power (item 638). It lies in chest 3 of the Druid Circle
-- (d23) since MM8 itself, but no quest ever asked for it.
--
-- Giver: Dantillion (NPC 41), Cleric of the Sun in Murmurwoods, slot B (his slot A holds
-- the Cauri Blackthorne topics). Quest bit 299, empty in Quests.txt.

local rewarding

function events.ItemGenerated(t)
	if rewarding then
		t.Item.Identified = true
	end
end

local function reward()
	-- through the generator, so MAW rolls rarity and enchantments; lands on the mouse cursor
	rewarding = true
	local ok, err = pcall(evt.GiveItem, {Strength = 5, Type = const.ItemType.Amulet, Id = 0})
	rewarding = nil
	assert(ok, err)
end

Quest{
	"DruidCircletQuest",
	NPC = 41,
	Slot = 1,
	Quest = 299,
	QuestItem = 638,
	Gold = 3000,
	Exp = 10000,
	Done = reward,
}.SetTexts{
	Topic = "드루이드 머리띠",
	Give = "드루이드의 원으로 향한 순례자들이 찾던 것은 그저 오래된 돌무더기가 아니었습니다. 고대인의 드루이드들이 그곳에 힘의 드루이드 머리띠라는 유물을 남겼다고 합니다. 태양의 신전에서는 그 유물이 악한 자들의 손에 들어가기 전에 안전하게 보관하려 합니다. 드루이드의 원은 여기서 북동쪽에 있습니다. 머리띠를 찾으면 제게 가져오십시오. 신전에서 보상해 드리겠습니다.",
	Undone = "머리띠가 없으시군요. 드루이드의 원은 여기서 북동쪽에 있으니, 그곳을 찾아보십시오.",
	Done = "힘의 드루이드 머리띠! 이 유물을 한 번 보려고 얼마나 많은 순례자들이 목숨을 잃었는지... 태양의 신전에서 안전하게 보관하겠습니다. 신전의 감사와 함께 이 부적을 받으십시오.",
	After = "머리띠는 안전하게 보관하고 있습니다. 태양의 신전은 여러분의 도움을 잊지 않을 것입니다.",
	Quest = "드루이드의 원에서 힘의 드루이드 머리띠를 찾아 머머우드의 단틸리온에게 가져가십시오.",
}
