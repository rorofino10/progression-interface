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
	BuildSkill(.Melee, proc(i: BlocksSize) -> BlocksSize{return 100*i})
	BuildSkill(.Endurance, proc(i: BlocksSize) -> BlocksSize{return 100*i})
	BuildSkill(.Sorcery, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildSkill(.Mana, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildSkill(.Ranged, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildSkill(.Perception, proc(i: BlocksSize) -> BlocksSize{return i})
	BuildSkill(.Medicine, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildSkill(.Logic, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildSkill(.Finesse, proc(i: BlocksSize) -> BlocksSize{return i}) 
	BuildSkill(.Athletics, proc(i: BlocksSize) -> BlocksSize{return i}) 

	BuildPerk(.Trip, 100, {}, {{.Melee, 1}})
	BuildPerk(.Aim, 100, {}, {{.Melee, 1}})
	BuildPerk(.Sight, 100, {}, {{.Melee, 1}})
	BuildPerk(.KnifeMaster, 100, {}, {{.Melee, 1}})
	// Perk(.Sight, 10, {}, {{.Melee, 1}})

	// Contains(SKILL.Melee, 1, PERK.Trip)
	// Contains(PERK.Trip, SKILL.Melee, 1)
	// Share(LeveledSkill{.Melee, 1}, .Trip, 100)
	// Drags(.Melee, .Endurance, 1)
	
	// Overlap(.Melee, .Endurance, NORMAL)
	
	// Contains(LeveledSkill{.Melee, 10}, LeveledSkill{.Logic, 1})
	Share(.Trip, .Aim, 100)
	Share(.Aim, .Sight, 100)
	Share(.Sight, .Trip, 100)
	// Share(SKILL.Melee, 1, PERK.Sight, NORMAL)
	// Share(SKILL.Melee, 1, PERK.Sight, NORMAL)
	// Share(.Trip, .Sight, NORMAL)
}
