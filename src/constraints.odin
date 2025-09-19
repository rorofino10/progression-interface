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

handle_share :: proc(share: TShare) -> BuyableCreationError{
	// fmt.println("Handling", share)
	buyable_a_blocks_to_own := DB.buyable_data[share.buyableA].assigned_blocks_amount
	buyable_b_blocks_to_own := DB.buyable_data[share.buyableB].assigned_blocks_amount

	blocks_to_share := BlocksSize(2 * (f64(share.strength) / 100) * f64(buyable_a_blocks_to_own*buyable_b_blocks_to_own) / f64(buyable_a_blocks_to_own+buyable_b_blocks_to_own))
	fudged_strength_a := f64(blocks_to_share) / f64(buyable_a_blocks_to_own)
	fudged_strength_b := f64(blocks_to_share) / f64(buyable_b_blocks_to_own)
	share_a_diff := abs(f64(share.strength)/100 - fudged_strength_a)
	share_b_diff := abs(f64(share.strength)/100 - fudged_strength_b)

	// fmt.println("To Share", blocks_to_share)
	// fmt.println("Efective A strength", fudged_strength_a)
	// fmt.println("Efective B strength", fudged_strength_b)
	// fmt.println("Share A diff",share_a_diff)
	// fmt.println("Share B diff",share_b_diff)
	
	if !(0 <= fudged_strength_a && fudged_strength_a <= 1.0) || !(0 <= fudged_strength_b && fudged_strength_b <= 1.0) || share_a_diff >= 0.10 || share_b_diff >= 0.10 do return ShareFudgeError{share}
	block_system_assign_share(share.buyableA, share.buyableB, blocks_to_share)
	return nil
}

handle_overlap :: proc(overlap: TOverlap) -> BuyableCreationError {
	for level in 1..=MAX_SKILL_LEVEL {
		skillA, skillB := LeveledSkill{overlap.skillA, LEVEL(level)}, LeveledSkill{overlap.skillB, LEVEL(level)}
		
		err := handle_share(TShare{skillA, skillB, overlap.strength})
		if err != nil do return OverlapFudgeError{overlap, LEVEL(level)}
	}
	return nil
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
        handle_overlap(overlap) or_return
    }
	return nil
}
