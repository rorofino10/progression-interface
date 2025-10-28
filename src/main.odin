package main

import "core:slice"
import "core:mem"
import "core:fmt"

@require_results
player_has_perk :: proc(perk: PerkID) -> bool {
	return perk in DB.owned_perks
}

@require_results
player_has_skill :: proc(skill: LeveledSkill) -> bool {
	owned_skill_level := DB.owned_skills[skill.id]
	return  skill.level<=owned_skill_level 
}

@require_results
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
	_immediate_perk_state :: proc(perk: PerkID, prereqs: []PRE_REQ_ENTRY, skills_reqs: []SKILL_REQ_ENTRY) -> PerkBuyableState {
		b_data := &DB.buyable_data[perk]
		
		b_data.bought_blocks_amount = slice.count_proc(b_data.assigned_blocks_indices[:], is_block_bought)

		{ // Owned?
			if player_has_perk(perk) do return .Owned
		}

		{ 	// check if pre_reqs are satisfied
			has_reqs := 
				slice.is_empty(prereqs) ||
				slice.all_of_proc(prereqs, proc(prereq: PRE_REQ_ENTRY) -> bool {
					switch req in prereq {
						case PerkID:
							return req in DB.owned_perks
						case PRE_REQ_OR_GROUP:
							satisfied := false
							for perk_in_or_group in req {
								if perk_in_or_group in DB.owned_perks do satisfied = true
							}
							return satisfied
					}
					return false
				})

			if !has_reqs do return .UnmetRequirements
		}

		{ 	// check skills_reqs
			has_reqs := 
				slice.is_empty(skills_reqs) || 
				slice.all_of_proc(skills_reqs, proc(skill_req: SKILL_REQ_ENTRY) -> bool {
					switch req in skill_req {
						case LeveledSkill:
							return player_has_skill(req)
						case SKILL_REQ_OR_GROUP:
							return slice.any_of_proc(req, proc(skill: LeveledSkill) -> bool {return player_has_skill(skill)}) 
					}
					return true
				})

			if !has_reqs do return .UnmetRequirements
		}
		{ // Check for points

			owned_block_amount := b_data.assigned_blocks_amount

			blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount
			if blocks_to_buy > DB.unused_points do return .UnmetRequirements
			if blocks_to_buy == 0 do return .Free
		}

		return .Buyable
	}

	for &perk_val, perk in DB.perk_data do perk_val.buyable_state = _immediate_perk_state(perk, perk_val.prereqs, perk_val.skills_reqs)
}
recalc_skill_id_raisable_state :: proc() {
	_immediate_raisable_state :: proc(skillID: SkillID) -> SkillRaisableState{
		
		curr_level := DB.owned_skills[skillID]

		if curr_level == MAX_SKILL_LEVEL do return .Capped

		skill := LeveledSkill{skillID, curr_level}
		next_skill := LeveledSkill{skillID, curr_level+1}

		b_data := &DB.buyable_data[next_skill]
		b_data.bought_blocks_amount = slice.count_proc(b_data.assigned_blocks_indices[:], is_block_bought)
		
		{ // Check if Capped
			cap: LEVEL
			skill_id_data := &DB.skill_id_data[skillID]
			switch skill_id_data.type {
				case .Main:
					cap = DB.player_states[DB.unit_level].main_skill_caps[skill_id_data.slot]
				case .Extra:
					cap = DB.player_states[DB.unit_level].extra_skill_cap
			}
			if curr_level >= cap do return .Capped
		}

		{ // Check If Enough Points or Free
			owned_block_amount := b_data.assigned_blocks_amount
			blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount
			if blocks_to_buy > DB.unused_points do return .NotEnoughPoints
			if blocks_to_buy == 0 do return .Free
		}

		return .Raisable
	}
	primary_1 := DB.owned_main_skills[0]
	(&DB.skill_id_data[primary_1]).raisable_state = _immediate_raisable_state(primary_1)
	for main_skill_idx in 1..<MAIN_SKILLS_AMOUNT {
		prev_main_skill := DB.owned_main_skills[main_skill_idx-1]
		curr_main_skill := DB.owned_main_skills[main_skill_idx]

		curr_raisable_state := _immediate_raisable_state(curr_main_skill)
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

		curr_raisable_state := _immediate_raisable_state(extra_skill)
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
	assigned_blocks := DB.buyable_data[buyable].assigned_blocks_indices
	for block_idx in assigned_blocks do block_system.blocks[block_idx].bought = true
}


lock_buyable :: proc(buyable: Buyable) {
	assigned_blocks := DB.buyable_data[buyable].assigned_blocks_indices
	for block_idx in assigned_blocks do block_system.blocks[block_idx].bought = false
}


reduce_to_skill :: proc(skill: LeveledSkill) -> (Points, RefundError) {
	curr_skill_level := DB.owned_skills[skill.id]
	refund : Points = 0

	for level in skill.level..<curr_skill_level {
		reduce_refund, reduce_err := reduce_skill(skill.id)
		refund += reduce_refund
		if reduce_err != nil do return refund, reduce_err
	}

	return refund, nil
}

reduce_skill :: proc(skill_id: SkillID) -> (Points, RefundError) {
	skill_level := DB.owned_skills[skill_id]
	if skill_level == 0 do return 0, .Unrefundable

	reduced_level := skill_level - 1
	skill := LeveledSkill{skill_id, skill_level}
	b_data := &DB.buyable_data[skill]
	owned_blocks_amount := b_data.assigned_blocks_amount
	skill_id_data := &DB.skill_id_data[skill_id]

	{ // Check if it is required in another owned buyable
		for owned_perk in DB.owned_perks {
			owned_perk_data := DB.perk_data[owned_perk]	
			for skill_req in owned_perk_data.skills_reqs {
				switch req in skill_req {
					case LeveledSkill:
						if skill == req do return 0, .RequiredByAnotherBuyable
					case SKILL_REQ_OR_GROUP:
						if slice.contains(req, skill) do return 0, .RequiredByAnotherBuyable
				}
			} 
		}
	}
	// Set as Locked
	refunded : Points
	DB.owned_skills[skill_id] = reduced_level
	for assigned_block_idx in b_data.assigned_blocks_indices {
		assigned_block := &block_system.blocks[assigned_block_idx]
		if !slice.any_of_proc(assigned_block.owned_by[:], player_has_buyable) {
			assigned_block.bought = false
			refunded += 1
		}
	}
	DB.unused_points += refunded

	if skill_id_data.type == .Main {

	{ // Sift Down if possible 
		for main_skill_idx := skill_id_data.slot; main_skill_idx < MAIN_SKILLS_AMOUNT-1; main_skill_idx+=1 {
			curr_main_skill, next_main_skill := DB.owned_main_skills[main_skill_idx], DB.owned_main_skills[main_skill_idx+1]
			curr_main_skill_level, next_main_skill_level := DB.owned_skills[curr_main_skill], DB.owned_skills[next_main_skill] 
			curr_main_skill_data, next_main_skill_data := &DB.skill_id_data[curr_main_skill], &DB.skill_id_data[next_main_skill]

			if curr_main_skill_level < next_main_skill_level {
				// swap
				slice.swap(DB.owned_main_skills[:], int(main_skill_idx), int(main_skill_idx)+1)

				curr_main_skill_data.slot += 1
				next_main_skill_data.slot -= 1
			}
		}
	}

	{ // Demote if Possible

		for extra_skill_id in DB.owned_extra_skills{
			extra_skill_level := DB.owned_skills[extra_skill_id]
			extra_skill_data := &DB.skill_id_data[extra_skill_id]
			if reduced_level < extra_skill_level {
				
				// swap
				skill_id_data.slot = extra_skill_data.slot
				skill_id_data.type = .Extra

				extra_skill_data.slot = DB.owned_main_skills_amount-1
				extra_skill_data.type = .Main
				
				DB.owned_main_skills[extra_skill_data.slot] = extra_skill_id
				DB.owned_extra_skills[skill_id_data.slot] = skill_id
				break
			}
		}

	}
	}
	recalc_buyable_states()
	return refunded, .None
}

refund_perk :: proc(perk_id: PerkID) -> (Points, RefundError) {
	if !player_has_buyable(perk_id) do return 0, .BuyableNotOwned

	{ // Check if it is required in another owned buyable
		for owned_perk in DB.owned_perks do if perk_id in _flattened_pre_reqs(owned_perk) do return 0, .RequiredByAnotherBuyable	
	}

	b_data := &DB.buyable_data[perk_id]
	DB.owned_perks -= {perk_id}
	
	refunded : Points
	for assigned_block_idx in b_data.assigned_blocks_indices {
		assigned_block := &block_system.blocks[assigned_block_idx]
		if !slice.any_of_proc(assigned_block.owned_by[:], player_has_buyable) {
			assigned_block.bought = false
			refunded += 1
		}
	}

	DB.unused_points += refunded

	recalc_buyable_states()

	return refunded, .None
}

raise_to_skill :: proc(skill: LeveledSkill) -> (Points, BuyError) {
	curr_skill_level := DB.owned_skills[skill.id]
	cost : Points = 0

	for level in curr_skill_level..<skill.level {
		raise_cost, raise_err := raise_skill(skill.id)
		cost += raise_cost
		if raise_err != nil do return cost, raise_err
	}

	return cost, nil
}

raise_skill :: proc(skill_id: SkillID) -> (Points, BuyError) {
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


	b_data := &DB.buyable_data[next_skill]

    owned_block_amount := b_data.assigned_blocks_amount
	blocks_to_buy := owned_block_amount - b_data.bought_blocks_amount
	

	{ // Set as bought
		DB.unused_points -= blocks_to_buy
		unlock_buyable(next_skill) // Set all blocks to bought
	
		DB.owned_skills[next_skill.id] = next_skill.level
	}

	{ // Promote if Possible
		last_main_skill_id := DB.owned_main_skills[DB.owned_main_skills_amount-1]
		last_main_skill_level := DB.owned_skills[last_main_skill_id]
		if skill_id_data.type == .Extra && next_skill.level > last_main_skill_level {
			// Promote
			(&DB.skill_id_data[last_main_skill_id]).slot = skill_id_data.slot
			(&DB.skill_id_data[last_main_skill_id]).type = .Extra
			
			DB.owned_main_skills[DB.owned_main_skills_amount-1] = skill_id
			DB.owned_extra_skills[skill_id_data.slot] = last_main_skill_id

			skill_id_data.slot = DB.owned_main_skills_amount-1
			skill_id_data.type = .Main
		}
	}

	{ // Sift Up if possible 
		if skill_id_data.type == .Main {
			for main_skill_idx := skill_id_data.slot; main_skill_idx > 0; main_skill_idx-=1 {
				curr_main_skill, prev_main_skill := DB.owned_main_skills[main_skill_idx], DB.owned_main_skills[main_skill_idx-1]
				curr_main_skill_level, prev_main_skill_level := DB.owned_skills[curr_main_skill], DB.owned_skills[prev_main_skill] 
				curr_main_skill_data, prev_main_skill_data := &DB.skill_id_data[curr_main_skill], &DB.skill_id_data[prev_main_skill]

				if curr_main_skill_level > prev_main_skill_level {
					// swap
					slice.swap(DB.owned_main_skills[:], int(main_skill_idx), int(main_skill_idx)-1)

					curr_main_skill_data.slot -= 1
					prev_main_skill_data.slot += 1
				}
			}
		}
	}
	
	recalc_buyable_states()

	return blocks_to_buy, .None
}


buy_perk :: proc(perk: PerkID) -> (Points, BuyError) {

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

		DB.owned_perks |= {perk}
	}

	recalc_buyable_states()

	return blocks_to_buy, .None
}

level_up :: proc() -> LevelUpError {
	if DB.unit_level >= DB.unit_level_cap do return .MAX_LEVEL_REACHED
	DB.unit_level += 1
	DB.unused_points += DB.player_states[DB.unit_level].skill_points_on_level
	
	recalc_buyable_states()
	return nil
}

reduce_level :: proc() -> ReduceLevelError {
	{ // Is Valid?
		if DB.unit_level == 1 do return ReduceLevelErrorIrreducibleLevel{}
		if DB.unused_points < DB.player_states[DB.unit_level].skill_points_on_level do return ReduceLevelErrorNotEnoughPoints{DB.player_states[DB.unit_level].skill_points_on_level - DB.unused_points}
		main_skill_caps := DB.player_states[DB.unit_level-1].main_skill_caps
		extra_skill_cap := DB.player_states[DB.unit_level-1].extra_skill_cap
		for main_skill, slot in DB.owned_main_skills {
			if DB.owned_skills[main_skill] > main_skill_caps[slot] do return ReduceLevelErrorExceedsCap{main_skill}
		}
		for extra_skill in DB.owned_extra_skills {
			if DB.owned_skills[extra_skill] > extra_skill_cap do return ReduceLevelErrorExceedsCap{extra_skill}
		}
	}
	// Reduce
	DB.unused_points -= DB.player_states[DB.unit_level].skill_points_on_level
	DB.unit_level -= 1
	recalc_buyable_states()
	return nil
}

level_up_to :: proc(to_level: LEVEL) -> LevelUpError {
	// Recalc only once
	defer recalc_buyable_states()
	for level in DB.unit_level..<to_level do level_up() or_return
	
	return nil
}

INTERFACE :: #config(INTERFACE, "gui")

run :: proc() -> Error {
	init_db() or_return
	
	when INTERFACE == "gui" do gui_run()
	when INTERFACE == "cli" do cli_run()
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
		delete(block_system_arena.data)
		delete(query_system_arena.data)
		delete(database_arena.data)
	}
}
