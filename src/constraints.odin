package main

import "core:slice/heap"
import "core:slice"
import "core:sort"
import "core:fmt"

TPartialShare :: struct {
	buyable_to_share_with: Buyable,
	strength: STRENGTH,
}
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

MAX_SHARE_DIFF :: 0.1

Discounts :: proc(buyableA, buyableB: Buyable, strength: STRENGTH) {
    append(&DB.share_constraints, TShare{buyableA, buyableB, strength, false, .MinimizingOverlap})
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
	for level in differential+1..=MAX_SKILL_LEVEL {
		lskillA, lskillB := LeveledSkill{skillA, LEVEL(level)}, LeveledSkill{skillB, LEVEL(level)-differential}
		append(&DB.contains_constraint, TContains{lskillA, lskillB})
	}
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

		assert((0 <= fudged_strength_a && fudged_strength_a <= 1.0) && (0 <= fudged_strength_b && fudged_strength_b <= 1.0) && share_a_diff < 0.10 && share_b_diff < 0.10, fmt.tprint("Cannot fudge", share))
	}
	else {
		blocks_to_share = BlocksSize(f64(share.strength) / 100 * f64(buyable_b_blocks_to_own))
		assert(blocks_to_share < buyable_a_blocks_to_own, fmt.tprintf("Cannot assign", share, "because it requires more blocks to share than buyableA can own"))
	}

	block_system_assign_share(share.buyableA, share.buyableB, blocks_to_share, share.strategy)
}


pre_process_share_constraints :: proc() {
	// @static share_graph : map[Buyable][dynamic]Buyable
	defer {
		for _, related in DB.share_graph do delete(related)
		delete(DB.share_graph)
	}
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
}


check_shares_are_valid :: proc() {
	{ // Check Share Constraints
		for share in DB.share_constraints {
			assert(share.strength >= 0 && share.strength <= 100, fmt.tprint(share, "Strength is not a percentage"))
			assert(share.buyableA != share.buyableB, fmt.tprint(share, "Cannot Share with itself."))
			assert(share.buyableA in DB.buyable_data, fmt.tprintln(share.buyableA, "not built."))
			assert(share.buyableB in DB.buyable_data, fmt.tprintln(share.buyableB, "not built."))
		}
	}

}

check_contains_are_valid :: proc() {
	{ // Check Contains Constraints
		for contains in DB.contains_constraint {
			container_blocks_to_own := DB.buyable_data[contains.container].blocks_to_be_assigned
			containee_blocks_to_own := DB.buyable_data[contains.containee].blocks_to_be_assigned

			assert(containee_blocks_to_own < container_blocks_to_own, fmt.tprint("Invalid contains constraint", contains, "containee has", containee_blocks_to_own, "blocks and container only has", container_blocks_to_own) )
			assert(contains.container in DB.buyable_data, fmt.tprintln(contains.container, "not built."))
			assert(contains.containee in DB.buyable_data, fmt.tprintln(contains.containee, "not built."))
		}
	}
}

_handle_shares :: proc() {
	@static shares_as_edges_graph : map[TShare][dynamic]TShare
	defer {
		for share, related in shares_as_edges_graph do delete(related) 
		delete(shares_as_edges_graph)
	}
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

_contains_comp :: proc(containsA, containsB: TContains) -> bool {
	containerA, containerB := containsA.container, containsB.container
	switch cA in containerA {
		case PerkID:
			switch cB in containerB {
				case PerkID:
					return cA < cB
				case LeveledSkill:
					return false
			}
		case LeveledSkill:
			switch cB in containerB {
				case PerkID:
					return true
				case LeveledSkill:
					if cA.level != cB.level do return cA.level > cB.level
					else do return cA.id < cB.id
			}
	}
	return false
}

_handle_contains :: proc(){
	@static contains_map : map[Buyable]map[Buyable]TContains
	@static contains_graph : map[Buyable][dynamic]Buyable
	@static reverse_contains_graph : map[Buyable][dynamic]Buyable
	defer {
		for container, related in contains_map do delete(related)
		delete(contains_map)
		for contains, related in contains_graph do delete(related)
		delete(contains_graph)
		for contains, related in reverse_contains_graph do delete(related)
		delete(reverse_contains_graph)
	}
	{	// Build Contains Graph
		for contains in DB.contains_constraint {
			if contains.container not_in contains_map do contains_map[contains.container] = make(map[Buyable]TContains)
			(&contains_map[contains.container])[contains.containee] = contains
			if contains.container not_in contains_graph do contains_graph[contains.container] = make([dynamic]Buyable)
			append(&contains_graph[contains.container], contains.containee)
			if contains.containee not_in reverse_contains_graph do reverse_contains_graph[contains.containee] = make([dynamic]Buyable)
			append(&reverse_contains_graph[contains.containee], contains.container)
		}
	}
	{ // Traverse through contains
		@static seen : map[Buyable]void
		defer delete(seen)

		_process_from_buyable :: proc(start: Buyable){
			fmt.println("Processing from", start)
			contains_heap: [dynamic]TContains
			defer delete(contains_heap)
			for container in reverse_contains_graph[start] do append(&contains_heap, contains_map[container][start])
			heap.make(contains_heap[:], _contains_comp)
			for len(contains_heap) != 0 {
				contains_to_process := contains_heap[0]
				defer {
					heap.pop(contains_heap[:], _contains_comp)
					pop(&contains_heap)
				}

				block_system_assign_contains(contains_to_process.container, contains_to_process.containee)
				if contains_to_process.container not_in seen && contains_to_process.container in reverse_contains_graph {
					for new_container in reverse_contains_graph[contains_to_process.container] {
						append(&contains_heap, contains_map[new_container][contains_to_process.container])	
						heap.push(contains_heap[:], _contains_comp)
					}
				}
				seen[contains_to_process.container] = void{}
			}
		}
		for contains in DB.contains_constraint do if contains.containee not_in contains_graph do _process_from_buyable(contains.containee)
	}
}

handle_constraints :: proc() {
	check_shares_are_valid()
	pre_process_share_constraints()
	_handle_shares()

	check_contains_are_valid()
	_handle_contains()
}


verify_constraints :: proc() {
	for share in DB.share_constraints {
		b_data_a, b_data_b := DB.buyable_data[share.buyableA], DB.buyable_data[share.buyableB]
		
		shared_blocks_in_a, shared_blocks_in_b : BlocksSize
		for assigned_block_idx in b_data_a.assigned_blocks_indices do if slice.contains(block_system.blocks[assigned_block_idx].owned_by[:], share.buyableB) do shared_blocks_in_a += 1
		for assigned_block_idx in b_data_b.assigned_blocks_indices do if slice.contains(block_system.blocks[assigned_block_idx].owned_by[:], share.buyableA) do shared_blocks_in_b += 1
		assert(shared_blocks_in_a == shared_blocks_in_b, fmt.tprintln("Shared blocks in A", shared_blocks_in_a, "not equal to shared_blocks_in_b", shared_blocks_in_b, "in share", share))

		representative_percentage_in_a := f64(shared_blocks_in_a) / f64(b_data_a.assigned_blocks_amount) * 100
		representative_percentage_in_b := f64(shared_blocks_in_b) / f64(b_data_b.assigned_blocks_amount) * 100
		
		if share.fudged {
			is_shared_correctly_in_a := representative_percentage_in_a >= f64(share.strength) 
			is_shared_correctly_in_a ||= abs(f64(share.strength) - representative_percentage_in_a) <= MAX_FUDGE

			is_shared_correctly_in_b := representative_percentage_in_b >= f64(share.strength) 
			is_shared_correctly_in_b ||= abs(f64(share.strength) - representative_percentage_in_b) <= MAX_FUDGE

			assert(is_shared_correctly_in_a, fmt.tprintln("Invalid share percentage got:", representative_percentage_in_a, "wanted", share.strength, "in share", share))
			assert(is_shared_correctly_in_b, fmt.tprintln("Invalid share percentage got:", representative_percentage_in_b, "wanted", share.strength, "in share", share))
		}
		else {
			is_shared_correctly := abs(representative_percentage_in_b - f64(share.strength)) <= MAX_SHARE_DIFF
			assert(is_shared_correctly, fmt.tprintln("Invalid share percentage got:", representative_percentage_in_b, "wanted", share.strength, "in share", share))
		}
	}

	for contains in DB.contains_constraint {
		b_data_container, b_data_containee := DB.buyable_data[contains.container], DB.buyable_data[contains.containee]
		for assigned_block_idx in b_data_containee.assigned_blocks_indices {
			assert(_buyable_requires_block(block_system.blocks[assigned_block_idx], contains.container), fmt.tprintln("Assigned block", assigned_block_idx, "of", contains.containee, "isn't contained by", contains.container))
		}
	}
}
