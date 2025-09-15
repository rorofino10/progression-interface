package main

import "core:mem"
import "core:fmt"

player_has_perk :: proc(perk: PerkID) -> bool {
	return perk in player.owned_perks
}
player_has_skill :: proc(skill: LeveledSkill) -> bool {
	owned_skill_level, ok := player.owned_skills[skill.id]
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
	unlock_block :: proc(block: OwnedBlock) {
		switch &b in block {
			case ^Block:
				if !b.bought {
					for owner in b.owned_by {
						owner_b_data := &DB.buyable_data[owner]
						owner_b_data.bought_amount += 1
					}

					b.bought = true
				}
			case ^BlockGroup:
				for &single_block in b.blocks {
					if !single_block.bought {
						for owner in single_block.owned_by {
							owner_b_data := &DB.buyable_data[owner]
							owner_b_data.bought_amount += 1
						}

						single_block.bought = true
					}		
				} 
		}
	}	
	b_data := &DB.buyable_data[buyable]
	for &block in b_data.owned_blocks do unlock_block(block)
}


lock_buyable :: proc(buyable: Buyable) {
	lock_block :: proc(block: OwnedBlock) {
		switch &b in block {
			case ^Block:
				if b.bought {
					for owner in b.owned_by {
						owner_b_data := &DB.buyable_data[owner]
						owner_b_data.bought_amount -= 1
					}

					b.bought = false
				}
			case ^BlockGroup:
				for &single_block in b.blocks {
					if single_block.bought {
						for owner in single_block.owned_by {
							owner_b_data := &DB.buyable_data[owner]
							owner_b_data.bought_amount -= 1
						}

						single_block.bought = false
					}
				} 
		}
	}

	b_data := &DB.buyable_data[buyable]
	for &block in b_data.owned_blocks do lock_block(block)
}

level_up :: proc() {
	player.level += 1
}

refund_buyable :: proc(buyable: Buyable) -> (u32, RefundError) {
	if !player_has_buyable(buyable) do return 0, .BuyableNotOwned
	b_data := &DB.buyable_data[buyable]
	owned_blocks_amount := BlocksSize(len(b_data.owned_blocks))

	lock_buyable(buyable)

	b_data.bought = false
	refunded := b_data.spent
	player.unused_points += refunded
	b_data.bought_amount = 0
	switch b in buyable {
		case LeveledSkill:
			if b.level == 1 do delete_key(&player.owned_skills, b.id)
			else do player.owned_skills[b.id] = b.level - 1
		case PerkID:
			player.owned_perks -= {b}
	}
	return refunded, .None
}

buy_skill :: proc(skill: LeveledSkill) -> (u32, BuyError) {
	skill_id_data := DB.skill_id_data[skill.id]

	if skill.level != 1 && !player_has_skill({skill.id, skill.level - 1}) do return 0, .MissingRequiredSkills
	b_data := &DB.buyable_data[skill]

    owned_block_amount := BlocksSize(len(b_data.owned_blocks))
	blocks_to_buy := owned_block_amount - b_data.bought_amount
	if blocks_to_buy > player.unused_points do return 0, .NotEnoughPoints
	player.unused_points -= blocks_to_buy
	unlock_buyable(skill) // Set all blocks to bought

	{ // Set as bought
		b_data.spent = blocks_to_buy
		b_data.bought = true
		player.owned_skills[skill.id] = skill.level
	}
	
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

	b_data := &DB.buyable_data[perk]
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

	
    owned_block_amount := BlocksSize(len(b_data.owned_blocks))

	blocks_to_buy := owned_block_amount - b_data.bought_amount
	if blocks_to_buy > player.unused_points do return 0, .NotEnoughPoints
	player.unused_points -= blocks_to_buy
	unlock_buyable(perk) // Set all blocks to bought

	{ 	// Set as bought
		b_data.spent = blocks_to_buy
		b_data.bought = true
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
	level : LEVEL,
	owned_skills:  map[SkillID]LEVEL,
	owned_perks:   Perks,
	unused_points: u32,
}

player : Unit

init_player :: proc() {
	player.level = 1
	player.unused_points = 120
}

run :: proc() -> Error {
	init_player()
	init_block_system_alloc() or_return
	init_db() or_return
	
	run_cli()
	return nil
}

main :: proc() {
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
	err := run()
	
	if err != nil {
		fmt.println(err)
	}
	{ // Cleanup
		delete(block_system_buffer)
	}

}
