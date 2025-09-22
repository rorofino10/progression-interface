#+feature dynamic-literals
package main

WEAK :: 25
NORMAL :: 50
STRONG :: 75


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
	BuildMainSkillLambda(.Melee, proc(i: BlocksSize) -> BlocksSize{return 10*i})
	BuildMainSkillLambda(.Endurance, proc(i: BlocksSize) -> BlocksSize{return 10*i})
	BuildMainSkillLambda(.Sorcery, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildMainSkillLambda(.Mana, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildMainSkillLambda(.Ranged, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildMainSkillLambda(.Perception, proc(i: BlocksSize) -> BlocksSize{return i})

	BuildExtraSkillLambda(.Medicine, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildExtraSkillLambda(.Logic, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildExtraSkillLambda(.Finesse, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildExtraSkillLambda(.Athletics, proc(i: BlocksSize) -> BlocksSize{return i}) 

	BuildPerk(.Trip, 100, {.Knife_Master, .Sight, .Aim}, {{.Melee, 1}})
	BuildPerk(.Aim, 110, {.Knife_Master,.Sight}, {{.Melee, 1}})
	BuildPerk(.Sight, 110, {.Knife_Master}, {{.Melee, 1}})
	BuildPerk(.Knife_Master, 100, {}, {{.Melee, 1}})
	// Perk(.Sight, 10, {}, {{.Melee, 1}})

	Contains(LeveledSkill{.Melee, 1}, .Trip)
	Contains(.Trip, LeveledSkill{.Melee, 1})
	// Share(LeveledSkill{.Melee, 1}, .Trip, 100)
	// Drags(.Melee, .Endurance, 1)
	
	Overlap(.Melee, .Endurance, NORMAL)
	
	// Contains(LeveledSkill{.Melee, 10}, LeveledSkill{.Logic, 1})
	Share(.Trip, .Sight, NORMAL)
}
