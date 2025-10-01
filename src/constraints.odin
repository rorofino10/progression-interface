package main

import "core:sort"
import "core:fmt"
TShare :: struct {
	buyableA: Buyable,
	buyableB: Buyable,
	strength: STRENGTH,
	fudged: bool,
}

TContains :: struct {
	container: Buyable,
	containee: Buyable,
}

TDrag :: struct {
	skillA: SkillID,
	skillB: SkillID,
	differential: LEVEL,
}

TOverlap :: struct {
	skillA: SkillID,
	skillB: SkillID,
	strength: STRENGTH,
}

Contains :: proc{_contains_skill_skill, _contains_skill_perk, _contains_perk_skill, _contains_perk_perk}

_contains_skill_skill :: proc(skill_id_a: SkillID, level_a: LEVEL, skill_id_b: SkillID, level_b: LEVEL) {
	_build_contains(LeveledSkill{skill_id_a, level_a}, LeveledSkill{skill_id_b, level_b})
}
_contains_skill_perk :: proc(skill_id_a: SkillID, level_a: LEVEL, perk: PerkID) {
	_build_contains(LeveledSkill{skill_id_a, level_a}, perk)
}
_contains_perk_skill :: proc(perk: PerkID, skill_id_a: SkillID, level_a: LEVEL) {
	_build_contains(perk, LeveledSkill{skill_id_a, level_a})
}
_contains_perk_perk :: proc(perkA, perkB: PerkID) {
	_build_contains(perkA, perkB)
}
_build_contains :: proc(buyableA, buyableB: Buyable) {
	append(&DB.contains_constraint, TContains{buyableA, buyableB})
}

Drags :: proc(skillA, skillB: SkillID, differential: LEVEL) {
    append(&DB.drag_constraint, TDrag{skillA, skillB, differential})
}

Share :: proc{_share_skill_perk, _share_perk_skill, _share_perk_perk}

_share_skill_perk :: proc(skill_id_a: SkillID, level_a: LEVEL, perk: PerkID, strength: STRENGTH) {
	_build_share(LeveledSkill{skill_id_a, level_a}, perk, strength, false)
}
_share_perk_skill :: proc(perk: PerkID, skill_id_a: SkillID, level_a: LEVEL,  strength: STRENGTH) {
	_build_share(LeveledSkill{skill_id_a, level_a}, perk, strength, false)
}
_share_perk_perk :: proc(perkA, perkB: PerkID, strength: STRENGTH) {
	_build_share(perkA, perkB, strength, true)
}

_build_share :: proc(buyableA, buyableB: Buyable, strength: STRENGTH, fudged: bool) {
    append(&DB.share_constraints, TShare{buyableA, buyableB, strength, fudged})
}

Overlap :: proc(skillA, skillB : SkillID, strength: STRENGTH) {
    append(&DB.overlap_constraints, TOverlap{skillA, skillB, strength})
}

handle_share :: proc(share: TShare){
	// fmt.println("Handling", share)
	blocks_to_share : BlocksSize
	buyable_a_blocks_to_own := DB.buyable_data[share.buyableA].assigned_blocks_amount
	buyable_b_blocks_to_own := DB.buyable_data[share.buyableB].assigned_blocks_amount

	if share.fudged {
		blocks_to_share = BlocksSize(2 * (f64(share.strength) / 100) * f64(buyable_a_blocks_to_own*buyable_b_blocks_to_own) / f64(buyable_a_blocks_to_own+buyable_b_blocks_to_own))
		fudged_strength_a := f64(blocks_to_share) / f64(buyable_a_blocks_to_own)
		fudged_strength_b := f64(blocks_to_share) / f64(buyable_b_blocks_to_own)
		share_a_diff := abs(f64(share.strength)/100 - fudged_strength_a)
		share_b_diff := abs(f64(share.strength)/100 - fudged_strength_b)

		if !(0 <= fudged_strength_a && fudged_strength_a <= 1.0) || !(0 <= fudged_strength_b && fudged_strength_b <= 1.0) || share_a_diff >= 0.10 || share_b_diff >= 0.10 do panic(fmt.tprint("Cannot fudge", share))		
	}
	else {
		blocks_to_share = BlocksSize(f64(share.strength) / 100 * f64(buyable_b_blocks_to_own))
		if blocks_to_share >= buyable_a_blocks_to_own do panic(fmt.tprintf("Cannot assign", share))
	}

	block_system_assign_share(share.buyableA, share.buyableB, blocks_to_share)
}

handle_contains :: proc(contains: TContains){
	// fmt.println("Handling", share)
	container_blocks_to_own := DB.buyable_data[contains.container].assigned_blocks_amount
	containee_blocks_to_own := DB.buyable_data[contains.containee].assigned_blocks_amount

	if containee_blocks_to_own >= container_blocks_to_own do panic(fmt.tprintf("Invalid contains constraint", contains))

	block_system_assign_contains(contains.container, contains.containee)
}

handle_drag :: proc(drag: TDrag) {
	for level in drag.differential+1..=MAX_SKILL_LEVEL {
		skillA, skillB := LeveledSkill{drag.skillA, LEVEL(level)}, LeveledSkill{drag.skillB, LEVEL(level)-drag.differential}
		
		handle_contains(TContains{skillA, skillB})
	}
}

handle_overlap :: proc(overlap: TOverlap) {
	fmt.println("Handling", overlap)

	for level in 1..=MAX_SKILL_LEVEL {
		skillA, skillB := LeveledSkill{overlap.skillA, LEVEL(level)}, LeveledSkill{overlap.skillB, LEVEL(level)}
		
		handle_share(TShare{skillA, skillB, overlap.strength, true})
	}
}



check_constraints :: proc() {
	{ // Check Contains
		// check_if_contains :: proc(buyableA,buyableB: Buyable) -> bool {
		// 	if buyableA == buyableB do return true
		// 	contraints_arr, ok := DB.contains_constraint[buyableA]
		// 	if !ok do return false
		// 	for containee in contraints_arr {
		// 		if check_if_contains(containee, buyableB) do return true
		// 	}
		// 	return false
		// }
		// for container, containee_arr in DB.contains_constraint {
		// 	for containee in containee_arr {
		// 		if check_if_contains(containee, container) do panic(fmt.tprint("Containee:", containee, "unlocks Container:", container))
		// 	}
		// }	
	}
	{ // Check Share Constraints
		for share in DB.share_constraints {
			if share.strength > 100 do panic(fmt.tprint(share, "Strength is not a percentage"))
			if share.buyableA == share.buyableB do panic(fmt.tprint(share, "Cannot Share with itself."))
		}
	}
	{ // Check Overlap Constraints
		for overlap in DB.overlap_constraints {
			if overlap.strength > 100 do panic(fmt.tprint(overlap, "Strength is not a percentage"))
			if overlap.skillA == overlap.skillB do panic(fmt.tprint(overlap, "Cannot Overlap with itself."))
		}
	}
}

handle_constraints :: proc() {
    for share in DB.share_constraints do handle_share(share)
	for overlap in DB.overlap_constraints do handle_overlap(overlap)
	for contains in DB.contains_constraint do handle_contains(contains)
	for drag in DB.drag_constraint do handle_drag(drag)
}
