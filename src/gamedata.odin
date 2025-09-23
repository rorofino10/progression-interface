#+feature dynamic-literals
package main

WEAK :: 25
NORMAL :: 50
STRONG :: 75

PerkID :: PERK

PERK :: enum u8 {
	Trip,
	Aim,
	Sight,
	KnifeMaster,
}

SkillID :: SKILL

SKILL :: enum u8 {
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
		{
			0 = {1500,{6,5,3,2,1,1}, 0},
			1 = {1500,{7,6,4,3,2,2}, 1},
			2 = {1500,{8,7,5,4,3,3}, 1},
			3 = {1500,{9,8,6,5,4,4}, 2},
			4 = {1500,{10,9,7,6,5,5}, 2},
		}
	)

    // Literal
	// BuildMainSkillLambda(.Melee, { 10, 20, 30 })

	// Lambda
	Skill(.Melee, 		proc(i: BlocksSize) -> BlocksSize{return 100+10*i})
	Skill(.Endurance, 	proc(i: BlocksSize) -> BlocksSize{return 100+10*i})
	Skill(.Sorcery, 	proc(i: BlocksSize) -> BlocksSize{return 100+10*i})
	Skill(.Mana, 		proc(i: BlocksSize) -> BlocksSize{return 100+10*i})
	Skill(.Ranged, 		proc(i: BlocksSize) -> BlocksSize{return 100+10*i})
	Skill(.Perception, 	proc(i: BlocksSize) -> BlocksSize{return 100+10*i})
	Skill(.Medicine, 	proc(i: BlocksSize) -> BlocksSize{return 100+10*i}) 
	Skill(.Logic, 		proc(i: BlocksSize) -> BlocksSize{return 100+10*i}) 
	Skill(.Finesse, 	proc(i: BlocksSize) -> BlocksSize{return 100+10*i}) 
	Skill(.Athletics, 	proc(i: BlocksSize) -> BlocksSize{return 100+10*i}) 

	Perk(.Trip, 50, {}, {{.Melee, 1}})
	Perk(.Aim, 50, {}, {{.Melee, 1}})
	Perk(.Sight, 50, {}, {{.Melee, 1}})
	Perk(.KnifeMaster, 50, {}, {{.Melee, 1}})
	// Perk(.Sight, 10, {}, {{.Melee, 1}})

	// Contains(SKILL.Melee, 1, PERK.Trip)
	// Contains(PERK.Trip, SKILL.Melee, 1)
	Share(SKILL.Melee, 1, PERK.Trip, 50)
	// Drags(.Melee, .Endurance, 3)
	// Drags(.Endurance, .Melee, 3)
	
	// Overlap(.Melee, .Endurance, 100)
	// Overlap(.Endurance, .Athletics, 100)
	// Overlap(.Athletics, .Melee, 100)
	
	// Contains(LeveledSkill{.Melee, 10}, LeveledSkill{.Logic, 1})
	// Share(.Trip, .Aim, 100)
	// Share(.Aim, .Sight, 100)
	// Share(.Sight, .Trip, 100)
	// Share(SKILL.Melee, 1, PERK.Sight, 100)
	// Share(PERK.Sight, SKILL.Melee, 2, 100)
	// Share(SKILL.Melee, 1, PERK.Sight, NORMAL)
	// Share(.Trip, .Sight, NORMAL)
}
