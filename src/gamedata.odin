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
	Athletics,
	Finesse,
	Medicine,
}

load_db :: proc() {

	BuildPlayer({120, 120, 120}, {{5,2,1,0},{3,3,3,2},{4,4,4,3}})

    // Literal
	BuildMainSkill(.Melee, { 10, 20, 30 })
	BuildMainSkill(.Athletics, { 10, 10, 10 })
	BuildMainSkill(.Finesse, { 10, 10, 10 })
	BuildExtraSkill(.Medicine, { 10, 10, 10 }) 
	// Skill(.Athletics, { 10, 10, 10 }) 
	// Skill(.Athletics, { {10, 1}, {20, 1}, {30, 1} }) 
	// Skill(.Finesse, { {10, 1}, {20, 1}, {30, 1} }) 
	// Skill(.Athletics, { 10, 20, 30 }) 
    // By Function
	// SkillByProc(.Athletics, proc(i: BlocksSize) -> BlocksSize{return i*5}) 


	Perk(.Trip, 5, {}, {{.Melee, 1}})
	Perk(.Aim, 10, {}, {{.Melee, 1}})
	Perk(.Sight, 10, {}, {{.Melee, 1}})
	// Perk(.Knife_Master, 2, {}, {{.Melee, 1}})

	// Contains(LeveledSkill{.Melee, 1}, .Trip)
	// Contains(LeveledSkill{.Melee, 1}, LeveledSkill{.Athletics, 1})
	// Share(LeveledSkill{.Melee, 1}, .Trip, 100)
	// Drags(.Melee, .Athletics, 1)


	Share(.Trip, .Aim, 50)
	// Share(.Aim, .Sight, 50)
	Share(.Sight, .Aim, 50)
	// Share(.Aim, .Knife_Master, 100)
	// Overlap(.Melee, .Athletics, 75)
	// Overlap(.Finesse, .Athletics, 50)
}
