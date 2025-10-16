#+feature dynamic-literals
package main

WEAK :: 25
NORMAL :: 50
STRONG :: 75

MAX_SKILL_LEVEL :: 10
MAX_SKILL_REQS_LEN :: 10

skill_slot_name := [MAIN_SKILLS_AMOUNT]string{"Primary 1", "Primary 2", "Major 1", "Major 2", "Major 3", "Major 4"}

PerkID :: PERK

PERK :: enum {
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
	//
	QuickAttack,
	Sweep,
	Skewer,
	Brutalize,
	Slam,
	Setup,
	Disarm,
	Hobble,
	FightMeCoward,
	HeyListen,	
	//
	CoveringFire,
	Overwatch,
	Killzone,
	Bully,
	Taunt,
	Feint,
	Direct,
	Aim,
	Predictable,
	GetItTogether,
	ZeroIn,
	Everyone,
	PerfectlyClear,
	GrandStrategy,
	IllTakeYouAllOn,
	YouDontHaveToDieHere,	
	//
	KnifeMaster,
	Swordmaster,
	StaffMaster,
	SpearMaster,
	Axeman,
	Hammerer,
	MasterOfMartialArts,
	Slinger,
	Archer,
	Pistoleer,
	Marksman,
	HeavyWeaponsGuy,
	Beamer,
	//
	SlingTraining,
	BowTraining,

	//
	COUNT
}

SkillID :: SKILL

SKILL :: enum {
	// Physical
	Athletics,
	Finesse,
	Endurance,

	// Combat
	Melee,
	Ranged,

	// Mental
	Logic,
	Composure,
	Perception,
	
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
		// Level = Skill Points on Level, Major Skill Caps, Extra Skill Cap
		{
			1 = {10000,{6,5,3,2,2,2},		1},
			2 = {500,{7,6,4,3,2,2},		1},
			3 = {500,{8,7,5,4,3,3},		1},
			4 = {500,{9,8,6,5,4,4},		2},
			5 = {500,{10,9,7,6,5,5},	2},
			6 = {500,{11,10,8,7,6,6},	3},
			7 = {500,{12,11,9,8,7,7},	4},
			8 = {500,{13,12,10,9,8,8},	5},
		}
	)

	BuildSkills(proc(i: BlocksSize) -> BlocksSize{return 100+10*i})

	// Overlap(.Athletics, .Composure, 100)
	// Overlap(.Athletics, .Influence, 50)
	// Contains(SKILL.Melee, 7, SKILL.Composure, 4)
	// Contains(SKILL.Composure, 7, SKILL.Melee, 4)
	// Contains(SKILL.Melee, 4, SKILL.Athletics, 2)
	// Contains(SKILL.Composure, 4, SKILL.Athletics, 2)
	// Contains(SKILL.Melee, 4, SKILL.Influence, 2)
	// Contains(SKILL.Influence, 3, SKILL.Athletics, 2)
	// Contains(SKILL.Endurance, 4, SKILL.Composure, 3)
	// Contains(SKILL.Composure, 3, SKILL.Athletics, 2)
	// Contains(SKILL.Athletics, 4, SKILL.Melee, 1)
	// Contains(SKILL.Athletics, 4, SKILL.Composure, 3)
	// ListOf(
	// 	TestRelation, {
	// 		{.Melee, .Composure},
	// 		{.Melee, .Athletics},
	// 		// {.Melee, .Ranged},
	// 		// {.Athletics, .Ranged },
	// 	}
	// )
	// ListOf(
	// 	CloseSkills, {
	// 	{.Melee, .Athletics},
	// 	{.Ranged, .Finesse},
	// 	{.Influence, .Acting},
	// 	}
	// )
	// ListOf(
	// 	DistantSkills, {
	// 	{.Influence, .Composure},
	// 	{.Acting, .Composure},
	// 	{.Influence, .Acting},
	// 	{.Endurance, .Composure},
	// 	{.Endurance, .Athletics},
	// 	{.Athletics, .Finesse},
	// 	{.Logic, .Perception},
	// 	{.Arts, .Influence},
	// 	{.Arts, .Acting},
	// 	{.Ranged, .Perception},
	// 	{.Melee, .Perception},
	// 	{.Survival, .Perception},
	// 	{.Survival, .Construction},
	// })
	// ListOf(
	// 	CloseDerivativeSkills, {
	// 	{.Computers, .Logic},
	// 	{.Medicine, .Logic},
	// 	{.Thievery, .Finesse},
	// 	{.Construction, .Athletics},
	// 	{.Engineering, .Logic},
	// 	{.Geology, .Logic},
	// 	// {.Physics, .Logic},
	// 	{.Piloting, .Finesse},
	// 	{.Influence, .Language},
	// 	{.Arts, .Acting},
	// 	}
	// )
	// ListOf(
	// 	DistantDerivativeSkills,{
	// 	{.Sorcery, .Arcana},
	// 	{.Arcana, .Logic},
	// 	// {.Engineering, .Physics},
	// 	{.Biology, .Chemistry},
	// 	{.Chemistry, .Physics},
	// 	// {.Geology, .Physics},
	// 	// {.Arts, .Language},
	// 	}
	// )

	// Perk(.Flurry, 			{OR{{.Melee, 9}, {.Ranged, 9}}, Skill{.Finesse, 4}}, 	{},		50, {{Skill{.Finesse, 9}, 50}})
	// Perk(.PerfectFlurry,	{Skill{.Finesse, 15}}, 									{},		70, {})
	// Perk(.Deadeye,			{OR{{.Melee, 9}, {.Ranged, 9}}, Skill{.Composure, 4}}, 	{.Aim}, 50, {{Skill{.Composure, 9}, 50}})
	// Perk(.Headshot,			{Skill{.Composure, 12}}, 								{},		40, {})
	// Perk(.Bullseye,			{Skill{.Composure, 15}}, 								{},		40, {})
	// Perk(.SaturationFire,	{Skill{.Ranged, 9}, Skill{.Athletics, 4}}, 				{},		50, {{Skill{.Athletics, 9}, 50}})
	// Perk(.MoreDakka,		{Skill{.Ranged, 15}, Skill{.Athletics, 10}},			{},		70, {})
	// Perk(.GrandSlam,		{Skill{.Athletics, 9}, Skill{.Melee, 4}}, 				{},		50, {})
	// Perk(.FullSwing,		{Skill{.Athletics, 15}}, 								{},		70, {})
	// Perk(.Guillotine,		{Skill{.Melee, 9}}, 									{},		50, {})
	// Perk(.ReignOfTerror,	{Skill{.Melee, 15}}, 									{},		70, {})
	// Perk(.Whirlwind,		{OR{{.Melee, 9}, {.Ranged, 9}}}, 						{},		50, {})
	// Perk(.ImmortalKing,		{OR{{.Melee, 15}, {.Ranged, 15}}}, 						{},		70, {})

	// Perk(.QuickAttack,	{Skill{.Finesse, 9}},						{.Flurry}	,30, {})
	// Perk(.Sweep,		{OR{{.Melee,6}, {.Ranged, 6}}},				{}			,30, {})
	// Perk(.Skewer,		{Skill{.Melee, 6}}, 						{}			,30, {})
	// Perk(.Brutalize,	{Skill{.Melee, 6}},							{}			,30, {})
	// Perk(.Slam,			{Skill{.Melee, 6}},							{.Bully}	,30, {})
	// Perk(.Setup,		{Skill{.Acting, 6}, Skill{.Perception, 6}}, {.Feint}	,30, {})
	// Perk(.Disarm,		{OR{{.Melee, 6}, {.Ranged, 6}}},			{.Aim}		,30, {})
	// Perk(.Hobble,		{OR{{.Melee, 6}, {.Ranged, 6}}},			{.Aim}		,30, {})
	// Perk(.FightMeCoward,{Skill{.Acting, 6}},						{}			,30, {})
	// Perk(.HeyListen,	{Skill{.Acting, 6}},						{}			,30, {})

	// Perk(.KnifeMaster,	{Skill{.Melee, 15}, Skill{.Finesse, 10}}, 							{}, 50, {{.Swordmaster, 50}})
	// Perk(.Swordmaster,	{Skill{.Melee, 15}, Skill{.Finesse, 10}}, 							{}, 50, {{.StaffMaster, 20}})
	// Perk(.StaffMaster,	{Skill{.Melee, 15}, Skill{.Athletics, 10}}, 						{}, 50, {{.SpearMaster, 50}, {.Axeman, 30}, {.Hammerer, 30}})
	// Perk(.SpearMaster,	{Skill{.Melee, 15}, Skill{.Athletics, 10}, Skill{.Composure, 7}}, 	{}, 50, {{.Axeman, 20}, {.Hammerer, 20}})
	// Perk(.Axeman,		{Skill{.Melee, 15}, Skill{.Athletics, 10}}, 						{}, 50, {{.Hammerer, 50}})
	// Perk(.Hammerer,		{Skill{.Melee, 15}, Skill{.Athletics, 10}}, 						{}, 50, {})

	// Perk(.MasterOfMartialArts,	{Skill{.Melee, 15}, 	Skill{.Athletics, 10}, Skill{.Finesse, 7}}, {}, 50, {{.StaffMaster, 50}})
	// Perk(.Slinger,				{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}, Skill{.Athletics, 7}}, {.SlingTraining}, 50, {{PERK.Archer, 20}, {PERK.Pistoleer, 20}, {PERK.Marksman, 40}})
	// Perk(.Archer,				{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}, Skill{.Athletics, 7}}, {.BowTraining}, 50, {{PERK.Marksman, 40}})
	// Perk(.Pistoleer,			{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}}, {}, 50, {{PERK.Marksman, 40}, {PERK.HeavyWeaponsGuy, 20}})
	// Perk(.Marksman,				{Skill{.Ranged, 15},	Skill{.Composure, 10}}, {}, 50, {{PERK.HeavyWeaponsGuy, 40}})
	Perk(.HeavyWeaponsGuy,		{Skill{.Ranged, 15},	Skill{.Athletics, 10}, Skill{.Endurance, 10}}, {}, 50, {{PERK.Beamer, 40}})
	// Perk(.Beamer,				{Skill{.Ranged, 15},	Skill{.Endurance, 10}}, {}, 50, {})
	Perk(.Beamer,				{}, {}, 50, {})

	// Perk(.BowTraining,		{Skill{.Ranged, 6}, Skill{.Athletics, 4}}, 						{}, 30, {})
	// Perk(.SlingTraining,	{Skill{.Ranged, 6}, Skill{.Finesse, 4}, Skill{.Athletics, 2}},	{}, 60, {})
}

TestRelation :: proc(A, B: SKILL) {
	Overlap(A, B, 100)
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
