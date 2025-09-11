package main

import "core:fmt"

player_has_perk :: proc(perk: PerkID) -> bool {
	return perk in player.owned_perks
}
player_has_skill :: proc(skill: LeveledSkill) -> bool {
	owned_skill_level, ok := player.owned_skills[skill.id]
	if !ok do return false
	return  skill.level<=owned_skill_level 
}


unlock_buyable :: proc(buyable: Buyable) {
	b_data := DB.buyable_data[buyable]
	for &block in b_data.owned_blocks {
		block.bought = true
		for &linked_block in block.linked_to {
			linked_block.bought = true // TODO: perhaps some recursion?
		}
	}
}

buy_skill :: proc(skill: LeveledSkill) -> (u32, BuyError) {
	if skill.level != 1 && !player_has_skill({skill.id, skill.level - 1}) do return 0, .MissingRequiredSkills
	skill_buyable := &DB.buyable_data[skill]

	blocks_to_buy := u32(0)
	for block in skill_buyable.owned_blocks {
		if !block.bought do blocks_to_buy += 1
	}
	if blocks_to_buy > player.unused_points do return 0, .NotEnoughPoints
	player.unused_points -= blocks_to_buy
	unlock_buyable(skill) // Set all blocks to bought
	skill_buyable.bought = true
	player.owned_skills[skill.id] = skill.level

	{ 	// Handle Contains
		containees, ok := DB.contains_constraint[skill]
		if ok {
			for buyable in containees do unlock_buyable(buyable)
		}
	}

	{ 	// Handle Drag
		drags := DB.drag_constraint[skill.id]
		for dragged_skill, drag in drags {
			if skill.level <= drag do continue
			unlock_buyable(LeveledSkill{dragged_skill, skill.level - drag})
		}
	}

	return blocks_to_buy, .None
}


buy_perk :: proc(perk: PerkID) -> (u32, BuyError) {

	perk_buyable := &DB.buyable_data[perk]
	perk_val := DB.perk_data[perk]

	{ 	// check pre_reqs
		for prereq in perk_val.prereqs {
			if prereq not_in player.owned_perks do return 0, .MissingRequiredPerks
		}
	}

	{ 	// check skills_reqs
		has_reqs := false
		for skill_req in perk_val.skills_reqs {
			if skill_req.id == .Melee && skill_req.level == 0 do break
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
		containees, ok := DB.contains_constraint[perk]
		if ok {
			for buyable in containees do unlock_buyable(buyable)
		}
	}


	return blocks_to_buy, .None
}

buy_buyable :: proc(buyable: Buyable) -> (u32, BuyError){
	switch b in buyable {
		case PerkID:
			return buy_perk(b)
		case LeveledSkill:
			return buy_skill(b)
	}
	return 0, nil
}

Unit :: struct {
	owned_skills:  map[SkillID]LEVEL,
	owned_perks:   Perks,
	unused_points: u32,
}

player : Unit

init_player :: proc() {
	player.unused_points = 120
}

run :: proc() -> Error {
	init_player()
	init_db() or_return
	
	run_cli()
	spent: u32
	spent = buy_skill({.Melee, 1}) or_return
	// buy_skill({.Melee, 2}) or_return

	spent = buy_skill({.Athletics, 1}) or_return

	spent = buy_skill({.Athletics, 2}) or_return


	// spent = buy_perk(.Trip) or_return
	// spent = buy_perk(.Knife_Master) or_return
	

	return nil
}

main :: proc() {
	err := run()
	if err != nil {
		fmt.println(err)
	}
}
