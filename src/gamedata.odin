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
}

load_db :: proc() {

    // Literal
	Skill(.Melee, { 10, 20, 30 }) 
	// Skill(.Athletics, { 10, 20, 30 }) 
    // By Function
	SkillByProc(.Athletics, proc(i: BlocksSize) -> BlocksSize{return i*5}) 


	Perk(.Trip, 4, {}, {{.Melee, 1}})
	Perk(.Aim, 8, {.Knife_Master}, {{.Melee, 1}})
	Perk(.Sight, 2, {.Knife_Master}, {{.Melee, 1}})
	Perk(.Knife_Master, 2, {}, {{.Melee, 1}})

	Contains(LeveledSkill{.Melee, 1}, .Trip)
	Drags(.Melee, .Athletics, 1)
	Share(.Trip, .Aim, 50)
	Share(.Aim, .Knife_Master, 100)
	Overlap(.Melee, .Athletics, 75)
}
