local npcID = {314, 413, 794}

function MakeRespecDude(npcID)
  QuestNPC = npcID
  Greeting{
    NPC = npcID,
    Text = "새로운 길을 택해 기술을 초기화하려 한다면 제대로 찾아오셨습니다."
  }
  
  Quest{
	  Slot = 3,
	  Ungive = function(t) changeToRespec(npcID) end,
      Texts = {
          Topic = "기술 초기화 안내",
          Ungive = "동의하면 보유한 모든 기술이 처음의 초보 단계로 돌아가며, 지금까지 투자한 모든 기술 포인트를 돌려받습니다.\n\n기술이 필요한 레벨에 다시 도달하면 이전에 획득했던 숙련도도 다시 부여됩니다.\n\n이 서비스를 이용하려면 현재 레벨당 1,000 금화를 지불해야 합니다."  
	  }
  }


end


function changeToRespec(npcID)
  QuestNPC = npcID
  Quest{
  	  Slot = 3,
      Ungive = function(t) RespecSkills(npcID) end,
      Texts = {
          Topic = "초기화하겠습니다",
          Ungive = [[Your skill points has been reset!]],
      }
  }
end

function events.LoadMap() 
	for i=1,#npcID do
		MakeRespecDude(npcID[i])
	end
end

function RespecSkills(npcID)
	MakeRespecDude(npcID)
	local id=Game.CurrentPlayer
	if id<0 then return end
	local goldRequired=Party[id].LevelBase*1000
	if Party.Gold<goldRequired then
		Message("금화가 부족합니다.")
		return
	else
		Party.Gold=Party.Gold-goldRequired
		if vars.AusterityMode then
			for i=0,Party.High do
				Party[i].Skills[const.Skills.IdentifyMonster] = JoinSkill(0, const.GM)
			end
		end
	end
	respecMastery(id)
	local refund=0
	local spentOnAlchemy=0
	local p=Party[id]
	
	local shared=sharedSkills
	if table.find(shamanClass, p.Class) or table.find(seraphClass, p.Class) or table.find(dkClass, p.Class) or table.find(assassinClass, pl.Class) then
		shared={12,13,14,15,16,17,18,19,20,21,22}
	end
	for i=0, p.Skills.High do
		local skill=SplitSkill(p.Skills[i])
		if skill>1 and i~=const.Skills.Alchemy then
			if table.find(shared, i) then
				local lastSkill=2
				--reset mastery
				for j=1,#shared do
					p.Skills[shared[j]]=SplitSkill(p.Skills[shared[j]])
				end	
				while lastSkill>1 do
					maxSkill=0
					count=1	
					for v=1,#shared do
						if p.Skills[shared[v]]>maxSkill then
							maxSkill = p.Skills[shared[v]]
							maxIndex=shared[v]
							count=1
						elseif p.Skills[shared[v]]==maxSkill then
							count=count+1
						end
					end
					lastSkill=maxSkill
					refund=math.ceil(maxSkill/count)
					if lastSkill>1 then
						p.SkillPoints=p.SkillPoints+refund
						p.Skills[maxIndex]=p.Skills[maxIndex]-1
					end
				end
			else
				refund=skill*(skill+1)/2-1
				--reset to 1 and reset skill points
				if p.Skills[i]>0 then
					p.Skills[i]=1
				end
				p.SkillPoints=p.SkillPoints+refund
			end
		end
		if i == const.Skills.Alchemy and skill > 1 then
			spentOnAlchemy = skill*(skill+1)/2-1
		end
	end
	--custom skills
	for i=50,53 do
	local s=SplitSkill(Skillz.get(p,i))
		p.SkillPoints=p.SkillPoints+ math.max(s*(s+1)/2-1,0)
		if s>0 then
			Skillz.set(p,i,1)
		end
	end
	
	-- retroactive fix for mercs
	local shouldBeRefundedAmount = 0 - spentOnAlchemy
	for i=2, p.LevelBase do
		shouldBeRefundedAmount = shouldBeRefundedAmount + 4 + math.floor(i/10+1)
	end
	if p.SkillPoints < shouldBeRefundedAmount then
		p.SkillPoints = shouldBeRefundedAmount
	end
	Message("기술 포인트가 초기화되었습니다!")
end

function respecMastery(id)
	local index=Party[id]:GetIndex()
	vars.oldPlayerMasteries=vars.oldPlayerMasteries or {}
	vars.oldPlayerMasteries[index]=vars.oldPlayerMasteries[index] or {}
	local p=Party[id]
	for i=0, p.Skills.High do
		local s, m = SplitSkill(p.Skills[i])
		vars.oldPlayerMasteries[index][i]=vars.oldPlayerMasteries[index][i] or 0
		vars.oldPlayerMasteries[index][i]=math.max(vars.oldPlayerMasteries[index][i], m)
	end
end
