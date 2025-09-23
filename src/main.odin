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

recalc_perks_buyable_state :: proc() {
	for perk, &perk_val in DB.perk_data {
		b_data := &DB.buyable_data[perk]
		query := query_all_blocks_from_buyable(perk)
		defer free_all(query_system_alloc)
		
		bought_blocks_amount : BlocksSize =  0
		for &block in query do if block.bought do bought_blocks_amount += 1 
		b_data.bought_blocks_amount = bought_blocks_amount


		{ // Owned?
			if b_data.is_owned {
				perk_val.buyable_state = .Owned
				continue
			}
		}

		{ 	// check pre_reqs
			for prereq in perk_val.prereqs {
				if prereq not_in DB.owned_perks {
					perk_val.buyable_state = .UnmetRequirements
					continue
				}
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
			if !has_reqs { 
				perk_val.buyable_state = .UnmetRequirements
				continue
			}
		}
		{ // Check for points

			owned_block_amount := b_data.assigned_blocks_amount

			blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount
			if blocks_to_buy > DB.unused_points { 
				perk_val.buyable_state = .UnmetRequirements
				continue
			}
		}

		perk_val.buyable_state = .Buyable
	}
}
recalc_skill_id_raisable_state :: proc() {
	immediate_raisable_state :: proc(skillID: SkillID) -> SkillRaisableState{
		
		curr_level := DB.owned_skills[skillID]

		if curr_level == MAX_SKILL_LEVEL do return .Capped

		
		{ // Check If Enough Points
			skill := LeveledSkill{skillID, curr_level}
			next_skill := LeveledSkill{skillID, curr_level+1}
			
			b_data := &DB.buyable_data[next_skill]
			query := query_all_blocks_from_buyable(next_skill)
			defer free_all(query_system_alloc)
			
			bought_blocks_amount : BlocksSize =  0
			for &block in query do if block.bought do bought_blocks_amount += 1 
			b_data.bought_blocks_amount = bought_blocks_amount

			owned_block_amount := b_data.assigned_blocks_amount
			blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount
			if blocks_to_buy > DB.unused_points do return .NotEnoughPoints
		}


		{ // Check if Capped
			cap: LEVEL
			skill_id_data := &DB.skill_id_data[skillID]
			switch skill_id_data.type {
				case .Main:
					cap = DB.player_states[DB.unit_level].main_skill_caps[skill_id_data.idx]
				case .Extra:
					cap = DB.player_states[DB.unit_level].extra_skill_cap
			}
			if curr_level >= cap do return .Capped
		}

		{ // Check if Free
			skill := LeveledSkill{skillID, curr_level}
			next_skill := LeveledSkill{skillID, curr_level+1}

			b_data := &DB.buyable_data[next_skill]

			owned_block_amount := b_data.assigned_blocks_amount
			blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount
			if blocks_to_buy == 0 do return .Free
		}
		return .Raisable
	}
	primary_1 := DB.owned_main_skills[0]
	(&DB.skill_id_data[primary_1]).raisable_state = immediate_raisable_state(primary_1)
	for main_skill_idx in 1..<MAIN_SKILLS_AMOUNT {
		prev_main_skill := DB.owned_main_skills[main_skill_idx-1]
		curr_main_skill := DB.owned_main_skills[main_skill_idx]

		curr_raisable_state := immediate_raisable_state(curr_main_skill)
		(&DB.skill_id_data[curr_main_skill]).raisable_state = curr_raisable_state
		if curr_raisable_state != .Capped do continue
		prev_raisable_state := DB.skill_id_data[prev_main_skill].raisable_state
		if prev_raisable_state == .Capped do continue
		prev_main_skill_level := DB.owned_skills[prev_main_skill]
		curr_main_skill_level := DB.owned_skills[curr_main_skill]

		if curr_main_skill_level >= prev_main_skill_level do (&DB.skill_id_data[curr_main_skill]).raisable_state = .Raisable
	}

	for extra_skill in DB.owned_extra_skills {
		last_main_skill := DB.owned_main_skills[MAIN_SKILLS_AMOUNT-1]

		curr_raisable_state := immediate_raisable_state(extra_skill)
		(&DB.skill_id_data[extra_skill]).raisable_state = curr_raisable_state

		if curr_raisable_state != .Capped do continue
		last_main_skill_raisable_state := DB.skill_id_data[last_main_skill].raisable_state
		if last_main_skill_raisable_state == .Capped do continue

		extra_skill_level := DB.owned_skills[extra_skill]
		last_main_skill_level := DB.owned_skills[last_main_skill]

		if extra_skill_level >= last_main_skill_level do (&DB.skill_id_data[extra_skill]).raisable_state = .Raisable
	}

}

recalc_buyable_states :: proc() {
	recalc_skill_id_raisable_state()
	recalc_perks_buyable_state()
}

unlock_buyable :: proc(buyable: Buyable) {
	owned_blocks := query_all_blocks_from_buyable(buyable)
	defer free_all(query_system_alloc)
	for &block in owned_blocks do block.bought = true
}


lock_buyable :: proc(buyable: Buyable) {
	owned_blocks := query_all_blocks_from_buyable(buyable)
	defer free_all(query_system_alloc)
	for &block in owned_blocks do block.bought = false
}


reduce_to_skill :: proc(skill: LeveledSkill) -> (u32, ReduceError) {
	curr_skill_level := DB.owned_skills[skill.id]
	refund : u32 = 0

	for level in skill.level..<curr_skill_level {
		reduce_refund, reduce_err := reduce_skill(skill.id)
		refund += reduce_refund
		if reduce_err != nil do return refund, reduce_err
	}

	return refund, nil
}

reduce_skill :: proc(skill_id: SkillID) -> (u32, ReduceError) {
	skill_level := DB.owned_skills[skill_id]
	if skill_level == 0 do return 0, .CannotReduceSkill

	skill := LeveledSkill{skill_id, skill_level}
	b_data := &DB.buyable_data[skill]
	owned_blocks_amount := b_data.assigned_blocks_amount


	{ // Check if it contains another buyable
		containees, contains := DB.contains_constraint[skill]
		if contains && len(containees)>0 do return 0, .ContainsAnotherBuyable
	}

	{ // Check if it drags another buyable
		_, drags := DB.drag_constraint[skill_id]
		if drags do return 0, .DragsAnotherBuyable
	}

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
	b_data.bought_blocks_amount = 0
	DB.owned_skills[skill_id] = skill_level - 1
	
	recalc_buyable_states()
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
	owned_blocks_amount := b_data.assigned_blocks_amount

	lock_buyable(perk_id)

	b_data.is_owned = false
	refunded := b_data.spent
	DB.unused_points += refunded
	b_data.bought_blocks_amount = 0
	DB.owned_perks -= {perk_id}
	recalc_buyable_states()
	return refunded, .None
}

raise_to_skill :: proc(skill: LeveledSkill) -> (u32, BuyError) {
	curr_skill_level := DB.owned_skills[skill.id]
	cost : u32 = 0

	for level in curr_skill_level..<skill.level {
		raise_cost, raise_err := raise_skill(skill.id)
		cost += raise_cost
		if raise_err != nil do return cost, raise_err
	}

	return cost, nil
}

raise_skill :: proc(skill_id: SkillID) -> (u32, BuyError) {
	skill_level := DB.owned_skills[skill_id]
	skill := LeveledSkill{skill_id, skill_level}
	next_skill := LeveledSkill{skill_id, skill_level+1}


	skill_id_data := &DB.skill_id_data[skill_id]

	{ // Check points
		if skill_id_data.raisable_state == .NotEnoughPoints do return 0, .NotEnoughPoints 
	}

	{ // Check if it is capped	
		if skill_id_data.raisable_state == .Capped do return 0, .CapReached
	}

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

	b_data := &DB.buyable_data[next_skill]

    owned_block_amount := b_data.assigned_blocks_amount
	blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount
	

	{ // Set as bought
		DB.unused_points -= blocks_to_buy
		unlock_buyable(next_skill) // Set all blocks to bought
	
		b_data.spent = blocks_to_buy
		b_data.is_owned = true
		DB.owned_skills[next_skill.id] = next_skill.level
	}
	
	{ 	// Handle Contains
		containees, ok := DB.contains_constraint[next_skill]
		if ok do for buyable in containees do unlock_buyable(buyable)
	}

	{ 	// Handle Drag
		drags := DB.drag_constraint[next_skill.id]
		for dragged_skill, drag in drags {
			if next_skill.level <= drag do continue
			unlock_buyable(LeveledSkill{dragged_skill, next_skill.level - drag})
		}
	}

	recalc_buyable_states()

	return blocks_to_buy, .None
}


buy_perk :: proc(perk: PerkID) -> (u32, BuyError) {

	b_data := &DB.buyable_data[perk]
	perk_val := DB.perk_data[perk]
	owned_block_amount := b_data.assigned_blocks_amount
	blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount

	if blocks_to_buy > DB.unused_points do return 0, .NotEnoughPoints

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

	{ 	// Set as bought
		DB.unused_points -= blocks_to_buy
		unlock_buyable(perk) // Set all blocks to bought

		b_data.spent = blocks_to_buy
		b_data.is_owned = true
		DB.owned_perks |= {perk}
	}

	{ 	// Handle Contains
		containees, ok := DB.contains_constraint[perk]
		if ok do for buyable in containees do unlock_buyable(buyable)
	}

	recalc_buyable_states()

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
		delete(query_system_buffer)
	}

}
