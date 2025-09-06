package main

import "core:fmt"
import "core:simd"

BuyError :: enum {
	None,
	NotEnoughPoints,
	MissingRequiredSkills,
	AlreadyHasSkill,
}
Error :: union #shared_nil {
	BuyError,
}

Unit :: struct {
	skills:        map[SkillType]([dynamic]^Buyable),
	perks:         [dynamic]^Buyable,
	unused_points: i32,
}

SkillType :: enum {
	Melee,
}

Skill :: struct {
	level: i32,
	type:  SkillType,
}

PerkType :: enum {
	Trip,
}

Perk :: struct {
	requirements: []Skill,
	type:         PerkType,
}

BuyableType :: enum {
	Perk,
	Skill,
}

Buyable :: struct {
	cost:   i32,
	blocks: i32,
	bought: bool,
	kind:   union {
		Perk,
		Skill,
	},
	type:   BuyableType,
}

ConstraintType :: enum {
	Contains,
	Drag,
	Overlap,
	Share,
}

Constraint :: struct {
	operandA: ^Buyable,
	operandB: ^Buyable,
	strength: u8,
	type:     ConstraintType,
}

player := Unit{}
constraints := []Constraint {
	Constraint{operandA = &Melee1Buyable, operandB = &TripBuyable, type = .Contains},
}

Melee1 := Skill {
	level = 1,
	type  = .Melee,
}

Melee2 := Skill {
	level = 2,
	type  = .Melee,
}

Trip := Perk {
	requirements = []Skill{Melee1},
}

Melee1Buyable := Buyable {
	cost = 110,
	kind = Melee1,
	type = .Skill,
}
Melee2Buyable := Buyable {
	cost = 120,
	kind = Melee2,
	type = .Skill,
}
TripBuyable := Buyable {
	cost = 30,
	kind = Trip,
	type = .Perk,
}

update_constraints :: proc(buyable: ^Buyable) {
	for constraint in constraints {
		#partial switch constraint.type {
		case .Contains:
			if buyable == constraint.operandA && buyable.bought {
				constraint.operandB.blocks = constraint.operandB.cost
			}
		}
	}
}

init_player :: proc() {
	player.skills = make(map[SkillType]([dynamic]^Buyable), 0)
	player.perks = make([dynamic]^Buyable, 0)
	player.unused_points = 110
}

add_buyable_to_player :: proc(buyable: ^Buyable) {
	switch b in buyable.kind {
	case Skill:
		skills_branch, ok := player.skills[b.type]
		if !ok {
			skills_branch = make([dynamic]^Buyable, 0)
		}
		append(&skills_branch, buyable)
		player.skills[b.type] = skills_branch
	case Perk:
		append(&player.perks, buyable)

	}

}
has_required_skills :: proc(buyable: Buyable) -> BuyError {
	switch b in buyable.kind {
	case Skill:
		if b.level == 1 do return .None
		skills_branch, ok := player.skills[b.type]
		if !ok do return .MissingRequiredSkills
		if skills_branch[len(skills_branch) - 1].kind.(Skill).level != b.level - 1 do return .MissingRequiredSkills
		for s in skills_branch {
			if s.kind.(Skill).level == b.level do return .AlreadyHasSkill
		}
	case Perk:
		for req in b.requirements {
			req_skill_branch, ok := player.skills[req.type]
			if !ok do return .MissingRequiredSkills
			if req.level > req_skill_branch[len(req_skill_branch) - 1].kind.(Skill).level do return .MissingRequiredSkills
		}
	}
	return .None
}

buy_buyable :: proc(buyable: ^Buyable) -> BuyError {
	has_required_skills(buyable^) or_return
	req_points := max(buyable.cost - buyable.blocks, 0)
	if player.unused_points < req_points {
		return .NotEnoughPoints
	}
	player.unused_points -= req_points
	buyable.blocks = buyable.cost
	buyable.bought = true
	add_buyable_to_player(buyable)
	update_constraints(buyable)
	return .None
}

main :: proc() {
	init_player()
	buy_buyable(&Melee1Buyable)
	buy_buyable(&Melee2Buyable)
	buy_buyable(&TripBuyable)
	fmt.println("Player Skills:", player.skills)
	fmt.println("Player Perks:", player.perks)
	fmt.println("Player Unused Points:", player.unused_points)
	// fmt.println(player.unused_points)
}
