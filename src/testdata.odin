#+feature dynamic-literals
package main

load_db_debug :: proc() {

	// BuildPlayer(
	// 	// Level = Skill Points on Level, Major Skill Caps, Extra Skill Cap
	// 	{
	// 		1 = {10000,{6,5,3,2,2,2},		1},
	// 		2 = {500,{7,6,4,3,2,2},		1},
	// 		3 = {500,{8,7,5,4,3,3},		1},
	// 		4 = {500,{9,8,6,5,4,4},		2},
	// 		5 = {500,{10,9,7,6,5,5},	2},
	// 		6 = {500,{11,10,8,7,6,6},	3},
	// 		7 = {500,{12,11,9,8,7,7},	4},
	// 		8 = {500,{13,12,10,9,8,8},	5},
	// 	}
	// )

	{ // Build Levels
		BuildLevel(1, 500,	{6,5,3,2,2,2}, 		1)
		BuildLevel(2, 500,	{7,6,4,3,2,2}, 		1)
		BuildLevel(3, 500,	{8,7,5,4,3,3}, 		1)
		BuildLevel(4, 500,	{9,8,6,5,4,4}, 		2)
		BuildLevel(5, 500,	{10,9,7,6,5,5}, 	2)
		BuildLevel(6, 500,	{11,10,8,7,6,6},	3)
		BuildLevel(7, 500,	{12,11,9,8,7,7},	4)
		BuildLevel(8, 500,	{13,12,10,9,8,8},	5)
		BuildLevel(9, 500,	{14,13,11,10,9,9},	7)
	}

	// { // Build Levels
	// 	SkillPoints = proc(level:LEVEL) -> Points {if level == 1 {return 5000} else {return 1400+Points(level)*100}}
	// 	Primary1Cap = proc(level:LEVEL) -> LEVEL {return 5+level}
	// 	Primary2Cap = proc(level:LEVEL) -> LEVEL {return 4+level}
	// 	Major1Cap	= proc(level:LEVEL) -> LEVEL {return 2+level}
	// 	Major2Cap	= proc(level:LEVEL) -> LEVEL {return 1+level}
	// 	Major3Cap	= proc(level:LEVEL) -> LEVEL {return max(2,level)}
	// 	Major4Cap	= proc(level:LEVEL) -> LEVEL {return max(2,level)}
	// 	ExtrasCap	= proc(level:LEVEL) -> LEVEL {if level <= 3 {return 1} else if level <= 5 {return 2} else {return level - 3}}
	// }

	BuildSkills(proc(i: BlocksSize) -> BlocksSize{return 100+10*i})

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
	// 	// {.Arcana, .Logic},
	// 	// {.Engineering, .Physics},
	// 	{.Biology, .Chemistry},
	// 	{.Chemistry, .Physics},
	// 	// {.Geology, .Physics},
	// 	// {.Arts, .Language},
	// 	}
	// )

	// BuildPerk(.Flurry, 			{SkillReqsOr({.Melee, 9}, {.Ranged, 9}), Skill{.Finesse, 4}}, 	{},		50, {{Skill{.Finesse, 9}, 50}})
	// BuildPerk(.PerfectFlurry,	{Skill{.Finesse, 15}}, 									{},		70, {})
	// BuildPerk(.Deadeye,			{SkillReqsOr({.Melee, 9}, {.Ranged, 9}), Skill{.Composure, 4}}, 	{.Aim}, 50, {{Skill{.Composure, 9}, 50}})
	// BuildPerk(.Headshot,			{Skill{.Composure, 12}}, 								{},		40, {})
	// BuildPerk(.Bullseye,			{Skill{.Composure, 15}}, 								{},		40, {})
	// BuildPerk(.SaturationFire,	{Skill{.Ranged, 9}, Skill{.Athletics, 4}}, 				{},		50, {{Skill{.Athletics, 9}, 50}})
	// BuildPerk(.MoreDakka,		{Skill{.Ranged, 15}, Skill{.Athletics, 10}},			{},		70, {})
	// BuildPerk(.GrandSlam,		{Skill{.Athletics, 9}, Skill{.Melee, 4}}, 				{},		50, {})
	// BuildPerk(.FullSwing,		{Skill{.Athletics, 15}}, 								{},		70, {})
	// BuildPerk(.Guillotine,		{Skill{.Melee, 9}}, 									{},		50, {})
	// BuildPerk(.ReignOfTerror,	{Skill{.Melee, 15}}, 									{},		70, {})
	// BuildPerk(.Whirlwind,		{SkillReqsOr({.Melee, 9}, {.Ranged, 9})}, 						{},		50, {})
	// BuildPerk(.ImmortalKing,		{SkillReqsOr({.Melee, 15}, {.Ranged, 15})}, 						{},		70, {})

	// BuildPerk(.QuickAttack,	{Skill{.Finesse, 9}},						{.Flurry}	,30, {})
	// BuildPerk(.Sweep,		{SkillReqsOr({.Melee,6}, {.Ranged, 6})},				{}			,30, {})
	// BuildPerk(.Skewer,		{Skill{.Melee, 6}}, 						{}			,30, {})
	// BuildPerk(.Brutalize,	{Skill{.Melee, 6}},							{}			,30, {})
	// BuildPerk(.Slam,			{Skill{.Melee, 6}},							{.Bully}	,30, {})
	// BuildPerk(.Setup,		{Skill{.Acting, 6}, Skill{.Perception, 6}}, {.Feint}	,30, {})
	// BuildPerk(.Disarm,		{SkillReqsOr({.Melee, 6}, {.Ranged, 6})},			{.Aim}		,30, {})
	// BuildPerk(.Hobble,		{SkillReqsOr({.Melee, 6}, {.Ranged, 6})},			{.Aim}		,30, {})
	// BuildPerk(.FightMeCoward,{Skill{.Acting, 6}},						{}			,30, {})
	// BuildPerk(.HeyListen,	{Skill{.Acting, 6}},						{}			,30, {})

	BuildPerk(
		display = "Covering Fire",
		id = .CoveringFire,
		skill_reqs = {Skill{.Ranged, 3}},
		cost = 30,
	)
	BuildPerk(
		id = .Overwatch,
		skill_reqs = {SkillReqsOr({.Ranged,3}, {.Melee, 6})},
		cost = 30,
	)
	BuildPerk(
		id = .Killzone,
		skill_reqs = {Skill{.Ranged, 12}},
		cost = 60,
	)
	BuildPerk(
		id = .Bully,
		skill_reqs = {Skill{.Athletics, 6}},
		cost = 30,
	)
	BuildPerk(
		id = .Taunt,
		skill_reqs = {Skill{.Influence, 3}},
		cost = 30,
	)
	BuildPerk(
		id = .Feint,
		skill_reqs = {Skill{.Influence, 3}},
		cost = 30,
	)
	BuildPerk(
		id = .Direct,
		skill_reqs = {Skill{.Influence, 9}},
		cost = 30,
	)
	BuildPerk(
		id = .Aim,
		skill_reqs = {Skill{.Composure, 3}},
		cost = 30,
		shares = {{Skill{.Perception, 1}, 30}},
	)
	BuildPerk(
		display = "Predictable",
		id = .Predictable,
		skill_reqs = {Skill{.Logic, 9}, Skill{.Perception, 4}},
		cost = 30,
	)
	BuildPerk(
		display = "Get It Together",
		id = .GetItTogether,
		skill_reqs = {Skill{.Influence, 6}},
		cost = 30,
	)
	BuildPerk(
		display = "Zero-In",
		id = .ZeroIn,
		pre_reqs = {.Aim},
		skill_reqs = {Skill{.Composure, 9}},
		cost = 30,
	)
	BuildPerk(
		display = "Everyone!",
		id = .Everyone,
		skill_reqs = {Skill{.Influence, 15}},
		cost = 60,
	)
	BuildPerk(
		display = "Perfectly Clear",
		id = .PerfectlyClear,
		pre_reqs = {.Predictable},
		skill_reqs = {Skill{.Logic, 15}},
		cost = 60,
	)
	BuildPerk(
		display = "I'll Take You All On",
		id = .IllTakeYouAllOn,
		skill_reqs = {Skill{.Acting, 9}},
		cost = 30,
	)
	BuildPerk(
		display = "You Don't Have To Die Here",
		id = .YouDontHaveToDieHere,
		skill_reqs = {Skill{.Influence, 12}},
		cost = 60,
	)
	// BuildPerk(.KnifeMaster,	{Skill{.Melee, 15}, Skill{.Finesse, 10}}, 							{}, 50, {{.Swordmaster, 50}})
	// BuildPerk(.Swordmaster,	{Skill{.Melee, 15}, Skill{.Finesse, 10}}, 							{}, 50, {{.StaffMaster, 20}})
	// BuildPerk(.StaffMaster,	{Skill{.Melee, 15}, Skill{.Athletics, 10}}, 						{}, 50, {{.SpearMaster, 50}, {.Axeman, 30}, {.Hammerer, 30}})
	// BuildPerk(.SpearMaster,	{Skill{.Melee, 15}, Skill{.Athletics, 10}, Skill{.Composure, 7}}, 	{}, 50, {{.Axeman, 20}, {.Hammerer, 20}})
	// BuildPerk(.Axeman,		{Skill{.Melee, 15}, Skill{.Athletics, 10}}, 						{}, 50, {{.Hammerer, 50}})
	// BuildPerk(.Hammerer,		{Skill{.Melee, 15}, Skill{.Athletics, 10}}, 						{}, 50, {})

	// BuildPerk(.MasterOfMartialArts,	{Skill{.Melee, 15}, 	Skill{.Athletics, 10}, Skill{.Finesse, 7}}, {}, 50, {{.StaffMaster, 50}})
	// BuildPerk(.Slinger,				{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}, Skill{.Athletics, 7}}, {.SlingTraining}, 50, {{PERK.Archer, 20}, {PERK.Pistoleer, 20}, {PERK.Marksman, 40}})
	// BuildPerk(.Archer,				{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}, Skill{.Athletics, 7}}, {.BowTraining}, 50, {{PERK.Marksman, 40}})
	// BuildPerk(.Pistoleer,			{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}}, {}, 50, {{PERK.Marksman, 40}, {PERK.HeavyWeaponsGuy, 20}})
	// BuildPerk(.Marksman,				{Skill{.Ranged, 15},	Skill{.Composure, 10}}, {}, 50, {{PERK.HeavyWeaponsGuy, 40}})
	// BuildPerk(.HeavyWeaponsGuy,		{Skill{.Ranged, 15},	Skill{.Athletics, 10}, Skill{.Endurance, 10}}, {}, 50, {{PERK.Beamer, 40}})
	// BuildPerk(.Beamer,				{Skill{.Ranged, 15},	Skill{.Endurance, 10}}, {}, 50, {})

	// BuildPerk(.BowTraining,		{Skill{.Ranged, 6}, Skill{.Athletics, 4}}, 						{}, 30, {})
	// BuildPerk(.SlingTraining, {Skill{.Ranged, 6}, Skill{.Finesse, 4}, Skill{.Athletics, 2}},	{}, 60, {})
}
