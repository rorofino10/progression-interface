package main

TShare :: struct {
	buyableA: Buyable,
	buyableB: Buyable,
	strength: STRENGTH,
}

TOverlap :: struct {
	skillA: SkillID,
	skillB: SkillID,
	strength: STRENGTH,
}

Contains :: proc(buyableA, buyableB: Buyable) {
	_, ok := DB.contains_constraint[buyableA]
	if !ok {
		DB.contains_constraint[buyableA] = make(DynBuyables, 0)
	}
	append(&DB.contains_constraint[buyableA], buyableB)
}

Drags :: proc(skillA, skillB: SkillID, drag: LEVEL) {
	_, ok := DB.drag_constraint[skillA]
	if !ok {
		DB.drag_constraint[skillA] = {}
	}
	drag_constraint_from := &DB.drag_constraint[skillA]
	_, ok = drag_constraint_from[skillB]
	if !ok {
		drag_constraint_from[skillB] = {}
	}
	drag_constraint_from[skillB] = drag
}

Share :: proc(buyableA, buyableB: Buyable, strength: STRENGTH) {
    append(&DB.share_constraints, TShare{buyableA, buyableB, strength})
}

Overlap :: proc(skillA, skillB : SkillID, strength: STRENGTH) {
    append(&DB.overlap_constraints, TOverlap{skillA, skillB, strength})
}


share_buyables :: proc(buyableA, buyableB: Buyable, strength: STRENGTH) {
	buyable_a_data, buyable_b_data := DB.buyable_data[buyableA], DB.buyable_data[buyableB]
	
	buyable_a_blocks_to_own, buyable_b_blocks_to_own : BlocksSize 
	blocks_to_share_a, blocks_to_share_b, blocks_to_share_max: BlocksSize
	switch a in buyableA {
		case LeveledSkill:
			buyable_a_blocks_to_own = DB.skill_id_data[a.id].blocks[a.level]
		case PerkID:
			buyable_a_blocks_to_own = DB.perk_data[a].blocks
	}
	switch b in buyableB {
		case LeveledSkill:
			buyable_b_blocks_to_own = DB.skill_id_data[b.id].blocks[b.level]
		case PerkID:
			buyable_b_blocks_to_own = DB.perk_data[b].blocks
	}


// 	{ 	// Shuffle blocks to link random blocks
// 		rand.shuffle(buyable_a_data.owned_blocks_range)
// 		rand.shuffle(buyable_b_data.owned_blocks_range)
// 	}
	blocks_to_share_a = BlocksSize(f32(buyable_a_blocks_to_own) * f32(strength) / 100)
	blocks_to_share_b = BlocksSize(f32(buyable_b_blocks_to_own) * f32(strength) / 100)
	blocks_to_share_max = max(blocks_to_share_a, blocks_to_share_b)
	block_system_assign_share(buyableA, buyableB, blocks_to_share_a, blocks_to_share_b, blocks_to_share_max)
	{ 	// Link A -> B
		// for block_idx in 0 ..< len_shared_blocks_from_a_to_b {
		// 	block_idx_mod := block_idx % len(buyable_a_data.owned_blocks_range)
		// 	append(
		// 		&buyable_a_data.owned_blocks_range[block_idx_mod].linked_to,
		// 		&buyable_b_data.owned_blocks_range[block_idx],
		// 	)
		// }
	}

// 	{ 	// Link B -> A
// 		len_shared_blocks_from_b_to_a := int(
// 			f32(len(buyable_a_data.owned_blocks_range)) * f32(strength) / 100,
// 		)
// 		for block_idx in 0 ..< len_shared_blocks_from_b_to_a {
// 			block_idx_mod := block_idx % len(buyable_b_data.owned_blocks_range)
// 			append(
// 				&buyable_b_data.owned_blocks_range[block_idx_mod].linked_to,
// 				&buyable_a_data.owned_blocks_range[block_idx],
// 			)
// 		}
// 	}
}


handle_share :: proc(share: TShare) {
	share_buyables(share.buyableA, share.buyableB, share.strength)
}

handle_overlap :: proc(overlap: TOverlap) {
	for level in 1..=MAX_SKILL_LEVEL {
		skillA, skillB := LeveledSkill{overlap.skillA, LEVEL(level)}, LeveledSkill{overlap.skillB, LEVEL(level)}

		share_buyables(skillA, skillB, overlap.strength)
	}
}

check_constraints :: proc() -> Error {
	{ // Check Share Constraints
		for share in DB.share_constraints {
			has_one_perk := false
			#partial switch _ in share.buyableA {
			case PerkID:
				has_one_perk = true
			}
			#partial switch _ in share.buyableB {
			case PerkID:
				has_one_perk = true
			}
			if !has_one_perk do return .ShareMissingPerk
			if share.strength > 100 do return .StrengthIsNotPercentage
		}
	}
	{ // Check Overlap Constraints
		for overlap in DB.overlap_constraints {
			if overlap.strength > 100 do return .StrengthIsNotPercentage
			if overlap.skillA == overlap.skillB do return .CannotOverlapWithItself
		}
	}
	return nil
}

handle_constraints :: proc() {
    for share in DB.share_constraints {
        handle_share(share)
    }
    for overlap in DB.overlap_constraints {
        handle_overlap(overlap)
    }
}
