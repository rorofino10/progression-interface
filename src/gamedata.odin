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
	Skill(.Melee, { 10, 10, 10 }) 
	// Skill(.Athletics, { 10, 10, 10 }) 
	// Skill(.Athletics, { {10, 1}, {20, 1}, {30, 1} }) 
	// Skill(.Finesse, { {10, 1}, {20, 1}, {30, 1} }) 
	// Skill(.Athletics, { 10, 20, 30 }) 
    // By Function
	// SkillByProc(.Athletics, proc(i: BlocksSize) -> BlocksSize{return i*5}) 


	Perk(.Trip, 10, {}, {{.Melee, 1}})
	Perk(.Aim, 10, {}, {{.Melee, 1}})
	Perk(.Sight, 10, {}, {{.Melee, 1}})
	// Perk(.Knife_Master, 2, {}, {{.Melee, 1}})

	Contains(LeveledSkill{.Melee, 1}, .Trip)
	// Share(LeveledSkill{.Melee, 1}, .Trip, 100)
	// Drags(.Melee, .Athletics, 1)


	Share(.Trip, .Aim, 100)
	// Share(.Aim, .Sight, 100)
	// Share(.Aim, .Knife_Master, 100)
	// Overlap(.Melee, .Athletics, 75)
	// Overlap(.Finesse, .Athletics, 50)
}
