#+feature dynamic-literals
package main

import "core:fmt"
MAX_SKILL_LEVEL :: 3

DatabaseError :: enum {
	None,
	LoadError,
}

SKILLS :: enum u8 {
	Melee,
	Athletics,
}

Skill :: struct {
	level: u32,
	name:  SKILLS,
}

SkillData :: struct {
	blocks: u32,
}

Perk :: enum u8 {
	Trip,
	Aim,
	Sight,
}

PerkValue :: struct {
	skills_reqs: [dynamic]Skill,
	prereqs:     bit_set[Perk],
	blocks:      u32,
}


void :: struct {}

ShareError :: enum {
	None,
	MissingPerk,
	StrengthIsNotPercentage,
}

BuyError :: enum {
	None,
	NotEnoughPoints,
	MissingRequiredSkills,
	MissingRequiredPerks,
	AlreadyHasSkill,
}

BuyableCreationError :: enum {
	None,
	INVALID_SKILLS_REQS,
	INVALID_PRE_REQS,
	CYCLE_IN_PRE_REQS,
}

Error :: union #shared_nil {
	BuyableCreationError,
	BuyError,
	ShareError,
}

Block :: struct {
	bought:    bool,
	linked_to: [dynamic]^Block,
}

Buyable :: union {
	Perk,
	Skill,
}


BuyableData :: struct {
	owned_blocks: []Block,
	bought:       bool,
	kind:         Buyable,
}


player_has_perk :: proc(perk: Perk) -> bool {
	return perk in player.owned_perks
}
player_has_skill :: proc(skill: Skill) -> bool {
	_, ok := player.owned_skills[skill]
	return ok
}

Melee1 := Skill {
	name  = .Melee,
	level = 1,
}

skills := map[Skill]SkillData{}
perks := map[Perk]PerkValue{}
load_db :: proc() -> Error {
	skills[Skill{name = .Melee, level = 1}] = SkillData {
		blocks = 1,
	}
	skills[Skill{name = .Melee, level = 2}] = SkillData {
		blocks = 2,
	}
	skills[Skill{name = .Melee, level = 3}] = SkillData {
		blocks = 3,
	}
	skills[Skill{name = .Athletics, level = 1}] = SkillData {
		blocks = 1,
	}
	skills[Skill{name = .Athletics, level = 2}] = SkillData {
		blocks = 2,
	}
	skills[Skill{name = .Athletics, level = 3}] = SkillData {
		blocks = 3,
	}

	perks[.Trip] = PerkValue {
		blocks      = 4,
		prereqs     = {},
		skills_reqs = [dynamic]Skill{Skill{name = .Melee, level = 1}},
	}
	perks[.Aim] = PerkValue {
		blocks      = 4,
		prereqs     = {},
		skills_reqs = [dynamic]Skill{Skill{name = .Melee, level = 1}},
	}
	perks[.Sight] = PerkValue {
		blocks      = 2,
		skills_reqs = [dynamic]Skill{Skill{name = .Melee, level = 1}},
	}
	// add_containee(Perk.Trip, Perk.Aim)
	// add_containee(Skill{name = .Melee, level = 1}, Perk.Trip)
	// add_drag(.Melee, .Athletics, 1)
	create_buyables() or_return
	add_share(.Trip, .Aim, 50) or_return
	return nil
}


buyable_data := map[Buyable]BuyableData{}

check_for_cycles :: proc(perk: Perk, seen: bit_set[Perk]) -> bool {
	if perk in seen do return true
	new_seen := seen | {perk}
	for req_perk in perks[perk].prereqs {
		if check_for_cycles(req_perk, new_seen) do return true
	}
	return false
}

create_buyables :: proc() -> BuyableCreationError {
	for perk in Perk {
		// Verify that there are no cycles in reqs
		if check_for_cycles(perk, {}) do return .CYCLE_IN_PRE_REQS
		perk_val := perks[perk]
		buyable_data[perk] = BuyableData {
			kind         = perk,
			owned_blocks = make([]Block, perk_val.blocks),
		}
	}
	for skill in skills {
		skill_val := skills[skill]
		buyable_data[skill] = BuyableData {
			kind         = skill,
			owned_blocks = make([]Block, skill_val.blocks),
		}}
	return .None
}

buyable_contains := map[Buyable][dynamic]Buyable{}
add_containee :: proc(buyableA, buyableB: Buyable) {
	_, ok := buyable_contains[buyableA]
	if !ok {
		buyable_contains[buyableA] = make([dynamic]Buyable, 0)
	}
	append(&buyable_contains[buyableA], buyableB)
}

buyable_drags := map[SKILLS]map[SKILLS]u32{}
add_drag :: proc(skillA, skillB: SKILLS, drag: u32) {
	_, ok := buyable_drags[skillA]
	if !ok {
		buyable_drags[skillA] = {}
	}
	buyable_drags_from := &buyable_drags[skillA]
	_, ok = buyable_drags_from[skillB]
	if !ok {
		buyable_drags_from[skillB] = {}
	}
	buyable_drags_from[skillB] = drag
}


add_share :: proc(buyableA: Buyable, buyableB: Buyable, strength: u8) -> ShareError {
	// if typeid_of(buyableA) != typeid(Perk) && typeid_of(buyableB) != typeid(Perk) do return
	if strength > 100 do return .StrengthIsNotPercentage
	buyable_a_data := buyable_data[buyableA]
	buyable_b_data := buyable_data[buyableB]

	shared_blocks := min(
		len(buyable_a_data.owned_blocks),
		int(f32(len(buyable_b_data.owned_blocks)) * f32(strength) / 100),
	)
	for block_num in 0 ..< shared_blocks {
		append(
			&buyable_a_data.owned_blocks[block_num].linked_to,
			&buyable_b_data.owned_blocks[block_num],
		)
		append(
			&buyable_b_data.owned_blocks[block_num].linked_to,
			&buyable_a_data.owned_blocks[block_num],
		)
	}
	return .None
}
