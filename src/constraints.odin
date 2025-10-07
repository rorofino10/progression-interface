package main

import "core:sort"
import "core:fmt"
TShare :: struct {
	buyableA: Buyable,
	buyableB: Buyable,
	strength: STRENGTH,
	fudged: bool,
	strategy: ShareStrategy,
}

ShareStrategy :: enum {
	MinimizingOverlap,
	MaximizingOverlap,
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
    append(&DB.share_constraints, TShare{buyableA, buyableB, strength, fudged, .MinimizingOverlap})
}

Overlap :: proc(skillA, skillB : SkillID, strength: STRENGTH) {
    // append(&DB.overlap_constraints, TOverlap{skillA, skillB, strength})
	for level in 1..=MAX_SKILL_LEVEL {
		leveled_skillA, leveled_skillB := LeveledSkill{skillA, LEVEL(level)}, LeveledSkill{skillB, LEVEL(level)}
		
		append(&DB.share_constraints, TShare{leveled_skillA, leveled_skillB, strength, true, .MinimizingOverlap})
	}
}

handle_share :: proc(share: TShare){
	// fmt.println("Handling", share)
	blocks_to_share : BlocksSize
	buyable_a_blocks_to_own := DB.buyable_data[share.buyableA].blocks_to_be_assigned
	buyable_b_blocks_to_own := DB.buyable_data[share.buyableB].blocks_to_be_assigned

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

	block_system_assign_share(share.buyableA, share.buyableB, blocks_to_share, share.strategy)
}

handle_contains :: proc(contains: TContains){
	// fmt.println("Handling", share)
	container_blocks_to_own := DB.buyable_data[contains.container].blocks_to_be_assigned
	containee_blocks_to_own := DB.buyable_data[contains.containee].blocks_to_be_assigned

	if containee_blocks_to_own >= container_blocks_to_own do panic(fmt.tprintf("Invalid contains constraint", contains))

	block_system_assign_contains(contains.container, contains.containee)
}

handle_drag :: proc(drag: TDrag) {
	for level in drag.differential+1..=MAX_SKILL_LEVEL {
		skillA, skillB := LeveledSkill{drag.skillA, LEVEL(level)}, LeveledSkill{drag.skillB, LEVEL(level)-drag.differential}
		
		handle_contains(TContains{skillA, skillB})
	}
}

pre_process_share_constraints :: proc() {
	// @static share_graph : map[Buyable][dynamic]Buyable
	// defer delete(share_graph)
	{ // Build Share Graph
		for share in DB.share_constraints {
			_, ok_a := DB.share_graph[share.buyableA]
			if !ok_a do DB.share_graph[share.buyableA] = make([dynamic]Buyable, 0)
			append(&DB.share_graph[share.buyableA], share.buyableB)

			_, ok_b:= DB.share_graph[share.buyableB]
			if !ok_b do DB.share_graph[share.buyableB] = make([dynamic]Buyable, 0)
			append(&DB.share_graph[share.buyableB], share.buyableA)
		}
	}
	@static seen : map[Buyable]void
	@static curr_path : [dynamic]Buyable
	@static share_cycle_id : map[Buyable]int
	@static last_share_cycle_id := 0
	defer {
		delete(curr_path)
		delete(share_cycle_id)
	}
	{ // Give every buyable a different share_cycle_id
		for buyable, _ in DB.share_graph {
			share_cycle_id[buyable] = last_share_cycle_id
			last_share_cycle_id += 1
		}
	}

	{	// Assign Share Cycle ids
		// I need to keep track of parent because this is an undirected graph
		_share_cycle_finder :: proc(start, curr, parent: Buyable) {
			// fmt.println("Call:", start, curr, parent, curr_path)
			seen[curr] = void{}
			append(&curr_path, curr)
			defer pop(&curr_path)

			for neighbour in DB.share_graph[curr] {
				if neighbour == parent do continue
				if neighbour == start {
					for buyable_in_cycle in curr_path {
						buyable_in_cycle_curr_id := share_cycle_id[buyable_in_cycle]
						share_cycle_id[buyable_in_cycle] = last_share_cycle_id 
						for buyable, id in share_cycle_id {
							if id == buyable_in_cycle_curr_id do share_cycle_id[buyable] = last_share_cycle_id
						}
					}
				}
				if _, already_seen := seen[neighbour]; !already_seen {
					_share_cycle_finder(start, neighbour, curr)
				}
			}
		}

		for buyable, _ in DB.share_graph {
			seen = map[Buyable]void{}
			_share_cycle_finder(buyable, buyable, nil)
			delete(seen)
		}
	}

	{	// Assign Strategy to Share
		for &share in DB.share_constraints {
			if share_cycle_id[share.buyableA] == share_cycle_id[share.buyableB] do share.strategy = .MaximizingOverlap
		}
	}

	for share in DB.share_constraints do fmt.println(share.buyableA, "share with", share.buyableB, share.strategy)
	// fmt.println(share_graph)
}


check_constraints :: proc() {
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

_handle_shares :: proc() {
	@static shares_as_edges_graph : map[TShare][dynamic]TShare
	defer delete(shares_as_edges_graph)
	{	// Build minimizing_share_graph
		for share in DB.share_constraints {
			shares_as_edges_graph[share] = make([dynamic]TShare, 0)
			for other_share in DB.share_constraints {
				if share == other_share do continue
				if share.buyableA == other_share.buyableA || share.buyableA == other_share.buyableB || share.buyableB == other_share.buyableA || share.buyableB == other_share.buyableB {
					append(&shares_as_edges_graph[share], other_share)
				}
			}
		}
	}


	// {	// Print share graph
	// 	fmt.println("Printing Share Graph")
	// 	for share, related_shares in shares_as_edges_graph {
	// 		fmt.println(share.buyableA, share.buyableB)
	// 		fmt.println('\t', related_shares[:])
	// 	}
	// }
	{	// Traverse through the graph
		_handle_share_in_graph :: proc(share: TShare) {
			fmt.println(share)
			if share in seen do return
			seen[share] = void{}
			handle_share(share)
			for related_share in shares_as_edges_graph[share] {
				_handle_share_in_graph(related_share)
			}
		}
		@static seen : map[TShare]void
		defer delete(seen)
		
		for share in DB.share_constraints do if share.strategy == .MaximizingOverlap do _handle_share_in_graph(share)

		for share in DB.share_constraints do if share.strategy == .MinimizingOverlap do _handle_share_in_graph(share)

	}
}

handle_constraints :: proc() {
	_handle_shares()
	for contains in DB.contains_constraint do handle_contains(contains)
	for drag in DB.drag_constraint do handle_drag(drag)
}
