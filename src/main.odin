package main

import "core:fmt"


unlock_buyable :: proc(buyable: Buyable) {
	b_data := buyable_data[buyable]
	for &block in b_data.owned_blocks {
		block.bought = true
		for &linked_block in block.linked_to {
			linked_block.bought = true // TODO: perhaps some recursion?
		}
	}
}

buy_skill :: proc(skill: Skill) -> (u32, BuyError) {
	if skill.level != 1 && !player_has_skill(Skill{name = skill.name, level = skill.level - 1}) do return 0, .MissingRequiredSkills
	skill_buyable := &buyable_data[skill]

	blocks_to_buy := u32(0)
	for block in skill_buyable.owned_blocks {
		if !block.bought do blocks_to_buy += 1
	}
	if blocks_to_buy > player.unused_points do return 0, .NotEnoughPoints
	player.unused_points -= blocks_to_buy
	unlock_buyable(skill) // Set all blocks to bought
	skill_buyable.bought = true
	player.owned_skills[skill] = void{}

	{ 	// Handle Contains
		containees, ok := buyable_contains[skill]
		if ok {
			for buyable in containees do unlock_buyable(buyable)
		}
	}

	{ 	// Handle Drag
		drags := buyable_drags[skill.name]
		for dragged_skill, drag in drags {
			if skill.level <= drag do continue
			unlock_buyable(Skill{level = skill.level - drag, name = dragged_skill})
		}
	}

	return blocks_to_buy, .None
}


buy_perk :: proc(perk: Perk) -> (u32, BuyError) {

	perk_buyable := &buyable_data[perk]
	perk_val := perks[perk]

	{ 	// check pre_reqs
		for prereq in perk_val.prereqs {
			if prereq not_in player.owned_perks do return 0, .MissingRequiredPerks
		}
	}

	{ 	// check skills_reqs
		has_reqs := false
		for skill_req in perk_val.skills_reqs {
			if player_has_skill(skill_req) {
				has_reqs = true
				break
			}
		}
		if !has_reqs do return 0, .MissingRequiredSkills
	}

	blocks_to_buy := u32(0)
	for block in perk_buyable.owned_blocks {
		if !block.bought do blocks_to_buy += 1
	}
	if blocks_to_buy > player.unused_points do return 0, .NotEnoughPoints
	player.unused_points -= blocks_to_buy
	unlock_buyable(perk) // Set all blocks to bought

	{ 	// Set as bought
		perk_buyable.bought = true
		player.owned_perks |= {perk}
	}

	{ 	// Handle Contains
		containees, ok := buyable_contains[perk]
		if ok {
			for buyable in containees do unlock_buyable(buyable)
		}
	}


	return blocks_to_buy, .None
}


Unit :: struct {
	owned_skills:  map[Skill]void,
	owned_perks:   bit_set[Perk],
	unused_points: u32,
}


ConstraintType :: enum {
	Contains,
	Drag,
	Overlap,
	Share,
}

player := Unit{}

init_player :: proc() {
	player.unused_points = 120
}

run :: proc() -> Error {
	init_player()
	load_db() or_return

	// add_containee_to(&buyable_skills[Skill{level = 1, name = .Melee}], &buyable_perks[.Sight])
	buy_skill(Skill{level = 1, name = .Melee}) or_return
	// buy_skill(Skill{level = 2, name = .Melee}) or_return
	// buy_skill(Skill{level = 1, name = .Athletics}) or_return
	spent: u32
	// spent = buy_perk(.Sight) or_return
	buy_perk(.Trip) or_return
	buy_perk(.Aim) or_return
	// for buyable, v in buyable_data {
	// 	fmt.println(buyable, v.bought)
	// }
	fmt.println("Unused points", player.unused_points)
	for owned_skill in player.owned_skills {
		fmt.println(owned_skill)
	}
	fmt.println(player.owned_perks)
	return nil
}

main :: proc() {
	err := run()
	if err != nil {
		fmt.println(err)
	}
}
