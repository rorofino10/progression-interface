#+feature dynamic-literals
package main

PerkID :: enum u8 {
	Trip,
	Aim,
	Sight,
	Knife_Master,
}

SkillID :: enum u8 {
	Melee,
	Endurance,
	Sorcery,
	Mana,
	Ranged,
	Perception,
	Medicine,
	Logic,
	Finesse,
	Athletics,
}

load_db :: proc() {

	BuildPlayer(
		points_gain = {300, 300, 300, 300, 300},
		rank_caps = {
			{6,5,3,2,1,1,0},
			{7,6,4,3,2,2,1},
			{8,7,5,4,3,3,1},
			{9,8,6,5,4,4,2},
			{10,9,7,6,5,5,2},
			}
	)

    // Literal
	// BuildMainSkillLambda(.Melee, { 10, 20, 30 })

	// Lambda
	BuildMainSkillLambda(.Melee, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildMainSkillLambda(.Endurance, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildMainSkillLambda(.Sorcery, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildMainSkillLambda(.Mana, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildMainSkillLambda(.Ranged, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildMainSkillLambda(.Perception, proc(i: BlocksSize) -> BlocksSize{return i})

	BuildExtraSkillLambda(.Medicine, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildExtraSkillLambda(.Logic, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildExtraSkillLambda(.Finesse, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildExtraSkillLambda(.Athletics, proc(i: BlocksSize) -> BlocksSize{return i}) 

	Perk(.Trip, 100, {}, {{.Melee, 1}})
	Perk(.Aim, 100, {}, {{.Melee, 1}})
	Perk(.Sight, 100, {}, {{.Melee, 1}})
	// Perk(.Sight, 10, {}, {{.Melee, 1}})
	Perk(.Knife_Master, 100, {}, {{.Melee, 1}})

	// Contains(LeveledSkill{.Melee, 1}, .Trip)
	Contains(LeveledSkill{.Melee, 10}, LeveledSkill{.Logic, 1})
	// Share(LeveledSkill{.Melee, 1}, .Trip, 100)
	// Drags(.Melee, .Endurance, 1)


	Share(.Trip, .Aim, 100)
	// Share(.Aim, .Sight, 100)
	// Share(.Sight, .Knife_Master, 100)
	// Share(.Sight, .Aim, 50)
	// Share(.Aim, .Knife_Master, 100)
	// Overlap(.Melee, .Athletics, 50)
	// Overlap(.Finesse, .Athletics, 50)
}
