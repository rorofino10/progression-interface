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

	BuildPlayer({30, 120, 120}, {
		{6,5,3,2,1,1,0},
		{7,6,4,3,2,2,1},
		{8,7,5,4,3,3,1}
	})

    // Literal
	// BuildMainSkillLambda(.Melee, { 10, 20, 30 })

	// Lambda
	BuildMainSkillLambda(.Melee, proc(i: BlocksSize) -> BlocksSize{return i*10})
	BuildMainSkillLambda(.Endurance, proc(i: BlocksSize) -> BlocksSize{return i*10})
	BuildMainSkillLambda(.Sorcery, proc(i: BlocksSize) -> BlocksSize{return i*10})
	BuildMainSkillLambda(.Mana, proc(i: BlocksSize) -> BlocksSize{return i*10})
	BuildMainSkillLambda(.Ranged, proc(i: BlocksSize) -> BlocksSize{return i*10})
	BuildMainSkillLambda(.Perception, proc(i: BlocksSize) -> BlocksSize{return i*10})

	BuildExtraSkillLambda(.Medicine, proc(i: BlocksSize) -> BlocksSize{return i*10}) 
	BuildExtraSkillLambda(.Logic, proc(i: BlocksSize) -> BlocksSize{return i*10}) 
	BuildExtraSkillLambda(.Finesse, proc(i: BlocksSize) -> BlocksSize{return i*10}) 
	BuildExtraSkillLambda(.Athletics, proc(i: BlocksSize) -> BlocksSize{return i*10}) 

	Perk(.Trip, 90, {}, {{.Melee, 1}})
	Perk(.Aim, 100, {}, {{.Melee, 1}})
	// Perk(.Sight, 10, {}, {{.Melee, 1}})
	// Perk(.Knife_Master, 2, {}, {{.Melee, 1}})

	// Contains(LeveledSkill{.Melee, 1}, .Trip)
	// Contains(LeveledSkill{.Melee, 3}, LeveledSkill{.Endurance, 1})
	// Share(LeveledSkill{.Melee, 1}, .Trip, 100)
	Drags(.Melee, .Endurance, 1)


	Share(.Trip, .Aim, 50)
	// Share(.Aim, .Sight, 50)
	// Share(.Sight, .Aim, 50)
	// Share(.Aim, .Knife_Master, 100)
	// Overlap(.Melee, .Athletics, 50)
	// Overlap(.Finesse, .Athletics, 50)
}
