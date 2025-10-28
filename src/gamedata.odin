#+feature dynamic-literals
package main

WEAK :: 25
NORMAL :: 50
STRONG :: 75

MAX_SKILL_LEVEL :: 50
MAX_SKILL_REQS_LEN :: 10

skill_slot_name := [MAIN_SKILLS_AMOUNT]string{"Primary 1", "Primary 2", "Major 1", "Major 2", "Major 3", "Major 4"}

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
    // GrandStrategy,
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

    {     // Build Levels
        // Level, Skill Points on Level, Major Skill Caps, Extra Skill Cap
        BuildLevel(1, 500, {6, 5, 3, 2, 2, 2}, 1)
        BuildLevel(2, 500, {7, 6, 4, 3, 2, 2}, 1)
        BuildLevel(3, 500, {8, 7, 5, 4, 3, 3}, 1)
        BuildLevel(4, 500, {9, 8, 6, 5, 4, 4}, 2)
        BuildLevel(5, 500, {10, 9, 7, 6, 5, 5}, 2)
        BuildLevel(6, 500, {11, 10, 8, 7, 6, 6}, 3)
        BuildLevel(7, 500, {12, 11, 9, 8, 7, 7}, 4)
        BuildLevel(8, 500, {13, 12, 10, 9, 8, 8}, 5)
        BuildLevel(9, 500, {14, 13, 11, 10, 9, 9}, 7)
    }

    BuildSkills(proc(i: BlocksSize) -> BlocksSize {return 100 + 10 * i})

    ListOf(CloseSkills, {{.Melee, .Athletics}, {.Ranged, .Finesse}, {.Influence, .Acting}})
    ListOf(
        DistantSkills,
        {
            {.Influence, .Composure},
            {.Acting, .Composure},
            {.Influence, .Acting},
            {.Endurance, .Composure},
            {.Endurance, .Athletics},
            {.Athletics, .Finesse},
            {.Logic, .Perception},
            {.Arts, .Influence},
            {.Arts, .Acting},
            {.Ranged, .Perception},
            {.Melee, .Perception},
            {.Survival, .Perception},
            {.Survival, .Construction},
        },
    )
    ListOf(
        CloseDerivativeSkills,
        {
            {.Computers, .Logic},
            {.Medicine, .Logic},
            {.Thievery, .Finesse},
            {.Construction, .Athletics},
            {.Engineering, .Logic},
            {.Geology, .Logic},
            // {.Physics, .Logic},
            {.Piloting, .Finesse},
            {.Influence, .Language},
            {.Arts, .Acting},
        },
    )
    ListOf(
        DistantDerivativeSkills,
        {
            {.Sorcery, .Arcana},
            // {.Arcana, .Logic},
            // {.Engineering, .Physics},
            {.Biology, .Chemistry},
            {.Chemistry, .Physics},
            // {.Geology, .Physics},
            // {.Arts, .Language},
        },
    )

    BuildPerk(.Flurry, 			{SkillReqsOr({.Melee, 9}, {.Ranged, 9}), Skill{.Finesse, 4}}, 	{},		50, {{Skill{.Finesse, 9}, 50}})
    BuildPerk(.PerfectFlurry,	{Skill{.Finesse, 15}}, 									{},		70, {})
    BuildPerk(.Deadeye,			{SkillReqsOr({.Melee, 9}, {.Ranged, 9}), Skill{.Composure, 4}}, 	{.Aim}, 50, {{Skill{.Composure, 9}, 50}})
    BuildPerk(.Headshot,			{Skill{.Composure, 12}}, 								{},		40, {})
    BuildPerk(.Bullseye,			{Skill{.Composure, 15}}, 								{},		40, {})
    BuildPerk(.SaturationFire,	{Skill{.Ranged, 9}, Skill{.Athletics, 4}}, 				{},		50, {{Skill{.Athletics, 9}, 50}})
    BuildPerk(.MoreDakka,		{Skill{.Ranged, 15}, Skill{.Athletics, 10}},			{},		70, {})
    BuildPerk(.GrandSlam,		{Skill{.Athletics, 9}, Skill{.Melee, 4}}, 				{},		50, {})
    BuildPerk(.FullSwing,		{Skill{.Athletics, 15}}, 								{},		70, {})
    BuildPerk(.Guillotine,		{Skill{.Melee, 9}}, 									{},		50, {})
    BuildPerk(.ReignOfTerror,	{Skill{.Melee, 15}}, 									{},		70, {})
    BuildPerk(.Whirlwind,		{SkillReqsOr({.Melee, 9}, {.Ranged, 9})}, 						{},		50, {})
    BuildPerk(.ImmortalKing,		{SkillReqsOr({.Melee, 15}, {.Ranged, 15})}, 						{},		70, {})

    BuildPerk(.QuickAttack,	{Skill{.Finesse, 9}},						{.Flurry}	,30, {})
    BuildPerk(.Sweep,		{SkillReqsOr({.Melee,6}, {.Ranged, 6})},				{}			,30, {})
    BuildPerk(.Skewer,		{Skill{.Melee, 6}}, 						{}			,30, {})
    BuildPerk(.Brutalize,	{Skill{.Melee, 6}},							{}			,30, {})
    BuildPerk(.Slam,			{Skill{.Melee, 6}},							{.Bully}	,30, {})
    BuildPerk(.Setup,		{Skill{.Acting, 6}, Skill{.Perception, 6}}, {.Feint}	,30, {})
    BuildPerk(.Disarm,		{SkillReqsOr({.Melee, 6}, {.Ranged, 6})},			{.Aim}		,30, {})
    BuildPerk(.Hobble,		{SkillReqsOr({.Melee, 6}, {.Ranged, 6})},			{.Aim}		,30, {})
    BuildPerk(.FightMeCoward,{Skill{.Acting, 6}},						{}			,30, {})
    BuildPerk(.HeyListen,	{Skill{.Acting, 6}},						{}			,30, {})

    BuildPerk(
        display = "Covering Fire",
        id = .CoveringFire,
        cost = 30,
        skill_reqs = {Skill{.Ranged, 3}},
    )
    BuildPerk(
        id = .Overwatch, 
        cost = 30,
        skill_reqs = {SkillReqsOr({.Ranged, 3}, {.Melee, 6})}, 
    )
    BuildPerk(
        id = .Killzone, 
        cost = 60,
        skill_reqs = {Skill{.Ranged, 12}}, 
    )
    BuildPerk(
        id = .Bully, 
        skill_reqs = {Skill{.Athletics, 6}}, 
        cost = 30
    )
    BuildPerk(
        id = .Taunt, 
        cost = 30,
        skill_reqs = {Skill{.Influence, 3}}, 
    )
    BuildPerk(
        id = .Feint, 
        cost = 30,
        skill_reqs = {Skill{.Influence, 3}}, 
    )
    BuildPerk(id = .Direct, skill_reqs = {Skill{.Influence, 9}}, cost = 30)
    BuildPerk(id = .Aim, skill_reqs = {Skill{.Composure, 3}}, cost = 30, shares = {{Skill{.Perception, 1}, 30}})
    BuildPerk(display = "Predictable", id = .Predictable, skill_reqs = {Skill{.Logic, 9}, Skill{.Perception, 4}}, cost = 30)
    BuildPerk(display = "Get It Together", id = .GetItTogether, skill_reqs = {Skill{.Influence, 6}}, cost = 30)
    BuildPerk(display = "Zero-In", id = .ZeroIn, pre_reqs = {.Aim}, skill_reqs = {Skill{.Composure, 9}}, cost = 30)
    BuildPerk(display = "Everyone!", id = .Everyone, skill_reqs = {Skill{.Influence, 15}}, cost = 60)
    BuildPerk(display = "Perfectly Clear", id = .PerfectlyClear, pre_reqs = {.Predictable}, skill_reqs = {Skill{.Logic, 15}}, cost = 60)
    BuildPerk(display = "I'll Take You All On", id = .IllTakeYouAllOn, skill_reqs = {Skill{.Acting, 9}}, cost = 30)
    BuildPerk(display = "You Don't Have To Die Here", id = .YouDontHaveToDieHere, skill_reqs = {Skill{.Influence, 12}}, cost = 60)
    BuildPerk(id = .KnifeMaster, skill_reqs = {Skill{.Melee, 15}, Skill{.Finesse, 10}}, cost = 50, shares = {{.Swordmaster, 50}})
    BuildPerk(id = .Swordmaster, skill_reqs = {Skill{.Melee, 15}, Skill{.Finesse, 10}}, pre_reqs = {}, cost = 50, shares = {{.StaffMaster, 20}})
    BuildPerk(id = .StaffMaster, skill_reqs = {Skill{.Melee, 15}, Skill{.Athletics, 10}}, pre_reqs = {}, cost = 50, shares = {{.SpearMaster, 50}, {.Axeman, 30}, {.Hammerer, 30}})
    BuildPerk(id = .SpearMaster, skill_reqs = {Skill{.Melee, 15}, Skill{.Athletics, 10}, Skill{.Composure, 7}}, pre_reqs = {}, cost = 50, shares = {{.Axeman, 20}, {.Hammerer, 20}})
    BuildPerk(id = .Axeman, skill_reqs = {Skill{.Melee, 15}, Skill{.Athletics, 10}}, cost = 50, shares = {{.Hammerer, 50}})
    BuildPerk(id = .Hammerer, skill_reqs = {Skill{.Melee, 15}, Skill{.Athletics, 10}}, cost = 50)

    BuildPerk(.MasterOfMartialArts,	{Skill{.Melee, 15}, 	Skill{.Athletics, 10}, Skill{.Finesse, 7}}, {}, 50, {{.StaffMaster, 50}})
    BuildPerk(.Slinger,				{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}, Skill{.Athletics, 7}}, {.SlingTraining}, 50, {{PERK.Archer, 20}, {PERK.Pistoleer, 20}, {PERK.Marksman, 40}})
    BuildPerk(.Archer,				{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}, Skill{.Athletics, 7}}, {.BowTraining}, 50, {{PERK.Marksman, 40}})
    BuildPerk(.Pistoleer,			{Skill{.Ranged, 15}, 	Skill{.Finesse, 10}}, {}, 50, {{PERK.Marksman, 40}, {PERK.HeavyWeaponsGuy, 20}})
    BuildPerk(.Marksman,				{Skill{.Ranged, 15},	Skill{.Composure, 10}}, {}, 50, {{PERK.HeavyWeaponsGuy, 40}})
    BuildPerk(.HeavyWeaponsGuy,		{Skill{.Ranged, 15},	Skill{.Athletics, 10}, Skill{.Endurance, 10}}, {}, 50, {{PERK.Beamer, 40}})
    BuildPerk(.Beamer,				{Skill{.Ranged, 15},	Skill{.Endurance, 10}}, {}, 50, {})

    BuildPerk(.BowTraining,		{Skill{.Ranged, 6}, Skill{.Athletics, 4}}, 						{}, 30, {})
    BuildPerk(.SlingTraining, {Skill{.Ranged, 6}, Skill{.Finesse, 4}, Skill{.Athletics, 2}},	{}, 60, {})
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
