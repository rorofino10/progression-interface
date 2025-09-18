package main

import "core:fmt"
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

	blocks_to_share_a = BlocksSize(f32(buyable_a_blocks_to_own) * f32(strength) / 100)
	blocks_to_share_b = BlocksSize(f32(buyable_b_blocks_to_own) * f32(strength) / 100)
	blocks_to_share_max = max(blocks_to_share_a, blocks_to_share_b)
	// block_system_assign_share(buyableA, buyableB, blocks_to_share_a, blocks_to_share_b, blocks_to_share_max)
}


handle_share :: proc(share: TShare) -> BuyableCreationError{
	
	buyable_a_blocks_to_own := DB.buyable_data[share.buyableA].blocks_left_to_assign
	buyable_b_blocks_to_own := DB.buyable_data[share.buyableB].blocks_left_to_assign

	blocks_to_share_a := BlocksSize(f32(buyable_a_blocks_to_own) * f32(share.strength) / 100)
	blocks_to_share_b := BlocksSize(f32(buyable_b_blocks_to_own) * f32(share.strength) / 100)

	blocks_to_share := max(blocks_to_share_a, blocks_to_share_b)
	share_a_diff := abs((f32(blocks_to_share) / f32(buyable_a_blocks_to_own)) - (f32(blocks_to_share_a) / f32(buyable_a_blocks_to_own)))
	share_b_diff := abs((f32(blocks_to_share) / f32(buyable_b_blocks_to_own)) - (f32(blocks_to_share_b) / f32(buyable_b_blocks_to_own)))

	fmt.println("Share A diff",share_a_diff)
	fmt.println("Share B diff",share_b_diff)
	
	if share_a_diff >= 0.10 || share_b_diff >= 0.10 do return ShareFudgeError{share}
	block_system_assign_share(share.buyableA, share.buyableB, blocks_to_share)
	return nil
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

handle_constraints :: proc() -> BuyableCreationError {
    for share in DB.share_constraints {
        handle_share(share) or_return
    }
    for overlap in DB.overlap_constraints {
        handle_overlap(overlap)
    }
	return nil
}
