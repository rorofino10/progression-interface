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
}

load_db :: proc() {

    // Literal
	Skill(.Melee, { 10, 20, 30 }) 
	// Skill(.Athletics, { {10, 1}, {20, 1}, {30, 1} }) 
	// Skill(.Finesse, { {10, 1}, {20, 1}, {30, 1} }) 
	// Skill(.Athletics, { 10, 20, 30 }) 
    // By Function
	SkillByProc(.Athletics, proc(i: BlocksSize) -> BlocksSize{return i*5}) 


	Perk(.Trip, 4, {}, {{.Melee, 1}})
	// Perk(.Aim, 8, {}, {{.Melee, 1}})
	// Perk(.Sight, 2, {}, {{.Melee, 1}})
	// Perk(.Knife_Master, 2, {}, {{.Melee, 1}})

	Contains(LeveledSkill{.Melee, 1}, .Trip)

	// Drags(.Melee, .Athletics, 3)
	// Share(.Trip, .Aim, 50)
	// Share(.Aim, .Knife_Master, 100)
	// Overlap(.Melee, .Athletics, 75)
	// Overlap(.Finesse, .Athletics, 50)
}
