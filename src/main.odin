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
		query := b_data.assigned_blocks
		
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
			_skill_req_or_group_satisfied :: proc(or_group: SKILL_REQ_OR_GROUP) -> bool {
				satisfied := false
				for req in or_group {
					if player_has_skill(req) {satisfied = true; break}
				}
				return satisfied
			}
			has_reqs := true
			// fmt.println(perk_val.skills_reqs)
			for skill_req in perk_val.skills_reqs {
				if !has_reqs do break
				switch req in skill_req {
					case LeveledSkill:
						if !player_has_skill(req) do has_reqs = false
					case SKILL_REQ_OR_GROUP:
						if !_skill_req_or_group_satisfied(req) do has_reqs = false
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
			if blocks_to_buy == 0 {
				perk_val.buyable_state = .Free
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
			query := b_data.assigned_blocks
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
	assigned_blocks := DB.buyable_data[buyable].assigned_blocks
	for &block in assigned_blocks do block.bought = true
}


lock_buyable :: proc(buyable: Buyable) {
	assigned_blocks := DB.buyable_data[buyable].assigned_blocks
	for &block in assigned_blocks do block.bought = false
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
		for contains in DB.contains_constraint {
			containee_data := DB.buyable_data[contains.containee]
			if contains.container == skill && containee_data.is_owned do return 0, .ContainsAnotherBuyable
		}
	}

	{ // Check if it drags another buyable
		for drag in DB.drag_constraint {
			if skill_level-drag.differential <= 0 do continue
			dragged_skill := DB.buyable_data[LeveledSkill{drag.skillB, skill_level-drag.differential}]
			if drag.skillA == skill_id && dragged_skill.is_owned {
				fmt.println(drag, dragged_skill)
				return 0, .DragsAnotherBuyable
			}
		}
	}

	{ // Check if it is required in another owned buyable
		_skill_in_or_group :: proc(skill: LeveledSkill, group: SKILL_REQ_OR_GROUP) -> bool {
			for entry in group {
				if entry == skill do return true
			}
			return false
		}
		for owned_perk in DB.owned_perks {
			owned_perk_data := DB.perk_data[owned_perk]	
			for skill_req in owned_perk_data.skills_reqs {
				switch req in skill_req {
					case LeveledSkill:
						if skill == req do return 0, .RequiredByAnotherBuyable
					case SKILL_REQ_OR_GROUP:
						if _skill_in_or_group(skill, req) do return 0, .RequiredByAnotherBuyable
				}
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
	
	recalc_buyable_states()

	return blocks_to_buy, .None
}


buy_perk :: proc(perk: PerkID) -> (u32, BuyError) {

	b_data := &DB.buyable_data[perk]
	perk_val := DB.perk_data[perk]
	owned_block_amount := b_data.assigned_blocks_amount
	blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount

	{ 	// check reqs
		if perk_val.buyable_state == .Owned do return 0, .AlreadyHasBuyable
		if perk_val.buyable_state == .UnmetRequirements do return 0, .UnmetRequirements
	}

	{ 	// Set as bought
		DB.unused_points -= blocks_to_buy
		unlock_buyable(perk) // Set all blocks to bought

		b_data.spent = blocks_to_buy
		b_data.is_owned = true
		DB.owned_perks |= {perk}
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

test :: proc() -> Error {
	// fmt.println(merge_sorted_slices({1,7,9}, {2,5,8,10, 24}))
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
