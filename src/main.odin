package main

import "core:mem"
import "core:fmt"

player_has_perk :: proc(perk: PerkID) -> bool {
	return perk in DB.owned_perks
}
player_has_skill :: proc(skill: LeveledSkill) -> bool {
	owned_skill_level, ok := DB.owned_skills[skill.id]
	if !ok do return false
	return  skill.level<=owned_skill_level 
}

player_has_buyable :: proc(buyable: Buyable) -> bool {
	switch b in buyable {
		case LeveledSkill:
			return player_has_skill(b)
		case PerkID:
			return player_has_perk(b)
	}
	return false
}

unlock_buyable :: proc(buyable: Buyable) {
	unlock_block :: proc(block: ^Block) {
		if !block.bought {
			for owner in block.owned_by {
				owner_b_data := &DB.buyable_data[owner]
				owner_b_data.owned_amount += 1
			}
		}
		block.bought = true
	}
	b_data := &DB.buyable_data[buyable]
	for &block in b_data.owned_blocks do unlock_block(block)
}


lock_buyable :: proc(buyable: Buyable) {
	lock_block :: proc(block: ^Block) {
		if block.bought {
			for owner in block.owned_by {
				owner_b_data := &DB.buyable_data[owner]
				owner_b_data.owned_amount -= 1
			}

			block.bought = false
		}
	}

	b_data := &DB.buyable_data[buyable]
	for &block in b_data.owned_blocks do lock_block(block)
}



reduce_skill :: proc(skill_id: SkillID) -> (u32, ReduceError) {
	skill_level := DB.owned_skills[skill_id]
	if skill_level == 0 do return 0, .CannotReduceSkill

	skill := LeveledSkill{skill_id, skill_level}
	b_data := &DB.buyable_data[skill]
	owned_blocks_amount := BlocksSize(len(b_data.owned_blocks))


	{ // Check if it is required in another owned buyable
		for owned_perk in DB.owned_perks {
			owned_perk_data := DB.perk_data[owned_perk]	
			for skill_req in owned_perk_data.skills_reqs {
				if skill == skill_req do return 0, .RequiredByAnotherBuyable
			} 
		}
	}

	lock_buyable(skill)

	b_data.is_owned = false
	refunded := b_data.spent
	DB.unused_points += refunded
	b_data.owned_amount = 0
	DB.owned_skills[skill_id] = skill_level - 1
	return refunded, .None
}

refund_perk :: proc(perk_id: PerkID) -> (u32, RefundError) {
	if !player_has_buyable(perk_id) do return 0, .BuyableNotOwned

	{ // Check if it is required in another owned buyable
		for owned_perk in DB.owned_perks {
			owned_perk_data := DB.perk_data[owned_perk]	
			if perk_id in owned_perk_data.prereqs do return 0, .RequiredByAnotherBuyable
		}
	}

	b_data := &DB.buyable_data[perk_id]
	owned_blocks_amount := BlocksSize(len(b_data.owned_blocks))

	lock_buyable(perk_id)

	b_data.is_owned = false
	refunded := b_data.spent
	DB.unused_points += refunded
	b_data.owned_amount = 0
	DB.owned_perks -= {perk_id}
	return refunded, .None
}

raise_skill :: proc(skill_id: SkillID) -> (u32, BuyError) {
	skill_level := DB.owned_skills[skill_id]
	skill := LeveledSkill{skill_id, skill_level}
	next_skill := LeveledSkill{skill_id, skill_level+1}

	skill_id_data := &DB.skill_id_data[skill_id]

	b_data := &DB.buyable_data[next_skill]

    owned_block_amount := BlocksSize(len(b_data.owned_blocks))
	blocks_to_buy := owned_block_amount - b_data.owned_amount
	if blocks_to_buy > DB.unused_points do return 0, .NotEnoughPoints

	{ // Check for promotion
		last_main_skill_id := DB.owned_main_skills[DB.owned_main_skills_amount-1]
		last_main_skill_level := DB.owned_skills[last_main_skill_id]
		if skill_id_data.type == .Extra && next_skill.level > last_main_skill_level {
			// swap
			(&DB.skill_id_data[last_main_skill_id]).idx = skill_id_data.idx
			(&DB.skill_id_data[last_main_skill_id]).type = .Extra
			
			DB.owned_main_skills[DB.owned_main_skills_amount-1] = skill_id
			DB.owned_extra_skills[skill_id_data.idx] = last_main_skill_id

			skill_id_data.idx = DB.owned_main_skills_amount-1
			skill_id_data.type = .Main
		}
	}

	{ // Sift Up if possible 
		for main_skill_idx := skill_id_data.idx; main_skill_idx > 0; main_skill_idx-=1 {
			curr_main_skill, prev_main_skill := DB.owned_main_skills[main_skill_idx], DB.owned_main_skills[main_skill_idx-1]
			curr_main_skill_level, prev_main_skill_level := DB.owned_skills[curr_main_skill], DB.owned_skills[prev_main_skill] 
			curr_main_skill_data, prev_main_skill_data := &DB.skill_id_data[curr_main_skill], &DB.skill_id_data[prev_main_skill]

			if curr_main_skill_level >= prev_main_skill_level {
				// swap
				DB.owned_main_skills[main_skill_idx] = prev_main_skill
				DB.owned_main_skills[main_skill_idx-1] = curr_main_skill

				curr_main_skill_data.idx -= 1
				prev_main_skill_data.idx += 1
			}
		}
	}	

	{ // Check if it is capped	
		cap: LEVEL
		switch skill_id_data.type {
			case .Main:
				cap = DB.skill_rank_cap[DB.unit_level-1][skill_id_data.idx]
			case .Extra:
				cap = DB.skill_rank_cap[DB.unit_level-1][MAIN_SKILLS_AMOUNT]
		}
		if next_skill.level > cap do return 0, .CapReached
	}

	DB.unused_points -= blocks_to_buy
	unlock_buyable(next_skill) // Set all blocks to bought

	{ // Set as bought
		b_data.spent = blocks_to_buy
		b_data.is_owned = true
		DB.owned_skills[next_skill.id] = next_skill.level
	}
	
	{ 	// Handle Contains
		containees, ok := DB.contains_constraint[next_skill]
		if ok {
			for buyable in containees do unlock_buyable(buyable)
		}
	}

	{ 	// Handle Drag
		drags := DB.drag_constraint[next_skill.id]
		for dragged_skill, drag in drags {
			if next_skill.level <= drag do continue
			unlock_buyable(LeveledSkill{dragged_skill, next_skill.level - drag})
		}
	}

	return blocks_to_buy, .None
}


buy_perk :: proc(perk: PerkID) -> (u32, BuyError) {

	b_data := &DB.buyable_data[perk]
	perk_val := DB.perk_data[perk]

	{ 	// check pre_reqs
		for prereq in perk_val.prereqs {
			if prereq not_in DB.owned_perks do return 0, .MissingRequiredPerks
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

	
    owned_block_amount := BlocksSize(len(b_data.owned_blocks))

	blocks_to_buy := owned_block_amount - b_data.owned_amount
	if blocks_to_buy > DB.unused_points do return 0, .NotEnoughPoints
	DB.unused_points -= blocks_to_buy
	unlock_buyable(perk) // Set all blocks to bought

	{ 	// Set as bought
		b_data.spent = blocks_to_buy
		b_data.is_owned = true
		DB.owned_perks |= {perk}
	}

	{ 	// Handle Contains
		containees, ok := DB.contains_constraint[perk]
		if ok {
			for buyable in containees do unlock_buyable(buyable)
		}
	}


	return blocks_to_buy, .None
}

run :: proc() -> Error {
	init_block_system_alloc() or_return
	init_db() or_return
	
	run_cli()
	return nil
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	err := run()
	
	if err != nil {
		fmt.println(err)
	}
	{ // Cleanup
		delete(block_system_buffer)
	}

}
