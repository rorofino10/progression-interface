#+feature dynamic-literals
package main

WEAK :: 25
NORMAL :: 50
STRONG :: 75

PerkID :: PERK

PERK :: enum u8 {
	Flurry,
	PerfectFlurry,
	Deadeye,
	Headshot,
	Bullseye,
	SaturationFire,
	MoreDakka,
	GrandSlam,
	FullSwing,
	Guillotine,
	ReignOfTerror,
	Whirlwind,
	ImmortalKing,
}

SkillID :: SKILL

SKILL :: enum u8 {
	// Physical
	Athletics,
	Finesse,
	Endurance,
	// Mental
	Logic,
	Composure,
	Perception,
	// Combat
	Melee,
	Ranged,
	// Social
	Influence,
	Acting,
	// Magic
	Sorcery,
	Astral,
	Mana,	

	// Professional (Operative)
	Medicine,
	Survival,
	Thievery,

	// Professional (Operative Sometimes)
	Arcana,
	Computers,
	Construction,
	Piloting,

	// Professional (Noncombat)
	Arts,
	Biology,
	Chemistry,
	Geology,
	Engineering,
	Language,
	Physics,
}

load_db :: proc() {

	BuildPlayer(
		{
			1 = {500,{6,5,3,2,2,2},		1},
			2 = {500,{7,6,4,3,2,2},		1},
			3 = {500,{8,7,5,4,3,3},		1},
			4 = {500,{9,8,6,5,4,4},		2},
			5 = {500,{10,9,7,6,5,5},	2},
			6 = {500,{11,10,8,7,6,6},	3},
			7 = {500,{12,11,9,8,7,7},	4},
		}
	)

	BuildSkills()

	Perk(.Flurry, {{.Melee, 9}, {.Ranged, 9}, {.Finesse, 4}}, {}, 50)
	Share(PERK.Flurry, SKILL.Finesse, 9, 50)
	// Perk(.Trip, 50, {}, {{.Melee, 1}})
	// Perk(.Aim, 50, {}, {{.Melee, 1}})
	// Perk(.Sight, 50, {}, {{.Melee, 1}})
	// Perk(.KnifeMaster, 50, {}, {{.Melee, 1}})
	// Perk(.Sight, 10, {}, {{.Melee, 1}})

	// Contains(SKILL.Melee, 1, PERK.Trip)
	// Contains(PERK.Trip, SKILL.Melee, 1)
	// Share(SKILL.Melee, 1, PERK.Trip, 50)
	// Drags(.Melee, .Endurance, 3)
	// Drags(.Endurance, .Melee, 3)
	
	// Overlap(.Melee, .Endurance, 100)
	// CloseSkills(.Melee,.Endurance)
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

CloseSkills :: proc(A, B: SKILL) {
	Contains(A, 4, B, 1)
	Contains(B, 4, A, 1)
	Overlap(A, B, 60)
}

DistantSkills :: proc(A, B: SKILL) {
	Overlap(A, B, 40)
}

CloseDerivativeSkills :: proc(A, B: SKILL) {
	Drags(A, B, 5)
	Overlap(A, B, 20)
}

DistantDerivativeSkills :: proc(A, B: SKILL) {
	Drags(A, B, 8)
	Overlap(A, B, 20)
}
