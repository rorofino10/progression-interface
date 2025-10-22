#+feature dynamic-literals
package main

import "core:sort"
import "core:math"
import "core:fmt"
import "base:runtime"
import "core:mem"

BLOCK_SYSTEM_ALLOCATED_MEM :: 10 * runtime.Megabyte
QUERY_SYSTEM_ALLOCATED_MEM :: 10 * runtime.Megabyte

block_system_alloc: mem.Allocator
block_system_arena: mem.Arena
block_system_buffer: []byte

block_system: ^BlockSystem

query_system_alloc: mem.Allocator
query_system_arena: mem.Arena
query_system_buffer: []byte

BlockSystem :: struct {
    blocks          : Blocks,
}

Block :: struct {
    bought      : bool,
	owned_by	: [dynamic]Buyable,
}

Blocks :: [dynamic]Block
BlocksSize :: int
BlocksQuery :: []^Block
BlocksIndexQuery :: []int

init_block_system_alloc :: proc() -> Error {
	block_system_buffer = make([]byte, BLOCK_SYSTEM_ALLOCATED_MEM) or_return
	mem.arena_init(&block_system_arena, block_system_buffer)
	block_system_alloc = mem.arena_allocator(&block_system_arena)

    return nil
}

init_query_system_alloc :: proc() -> Error {
	query_system_buffer = make([]byte, QUERY_SYSTEM_ALLOCATED_MEM) or_return
	mem.arena_init(&query_system_arena, query_system_buffer)
	query_system_alloc = mem.arena_allocator(&query_system_arena)
    return nil
}

block_system_allocate :: proc() {
    block_system = new(BlockSystem)
    block_system.blocks = make([dynamic]Block, 0, 1_000_000)
}

query_blocks_indices_from_buyable :: proc(buyable: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if BlocksSize(len(query)) == query_amount do break

        if _contains(block.owned_by[:], buyable) do append(&query, block_idx)
    }
    assert(BlocksSize(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyable))
    return query[:]
}

query_blocks_indices_from_buyable_that_dont_clash_with_buyable :: proc(buyableA, buyableB: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if BlocksSize(len(query)) == query_amount do break

        if _contains(block.owned_by[:], buyableA) && !_block_clashes_with_buyable(block, buyableB) do append(&query, block_idx)
    }
    assert(BlocksSize(len(query)) == query_amount, fmt.tprint("Queried for", query_amount, "got", len(query), buyableA))
    return query[:]
}

query_all_blocks_indices_from_buyable_that_dont_clash_with_buyable :: proc(buyableA, buyableB: Buyable) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0)
    for &block, block_idx in block_system.blocks {
        if _contains(block.owned_by[:], buyableA) && !_block_clashes_with_buyable(block, buyableB) do append(&query, block_idx)
    }
    return query[:]
}

query_blocks_indices_from_buyable_that_dont_require_buyable :: proc(buyableA, buyableB: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if BlocksSize(len(query)) == query_amount do break

        if _contains(block.owned_by[:], buyableA) && _block_requires_buyable(block, buyableB) do append(&query, block_idx)
    }
    assert(BlocksSize(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyableA))
    return query[:]
}
query_blocks_indices_from_buyable_that_buyable_doesnt_require :: proc(buyableA, buyableB: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if BlocksSize(len(query)) == query_amount do break

        if _contains(block.owned_by[:], buyableA) && !_buyable_requires_block(block, buyableB) do append(&query, block_idx)
    }
    assert(BlocksSize(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyableA))
    return query[:]
}
query_blocks_indices_from_buyable_not_assigned_to_buyable :: proc(buyableA, buyableB: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if BlocksSize(len(query)) == query_amount do break

        if _contains(block.owned_by[:], buyableA) && !_contains(block.owned_by[:], buyableB) do append(&query, block_idx)
    }
    assert(BlocksSize(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyableA))
    return query[:]
}

query_all_blocks_indices_from_buyable_that_buyable_doesnt_require :: proc(buyable, owner: Buyable) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0)
    for &block, block_idx in block_system.blocks {
        if _contains(block.owned_by[:], buyable) && !_buyable_requires_block(block, owner) do append(&query, block_idx)
    }
    return query[:]    
}

query_all_blocks_indices_from_buyable :: proc(buyable: Buyable) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0)
    query_curr_idx : BlocksSize = 0
    for &block, block_idx in block_system.blocks do if _contains(block.owned_by[:], buyable) do append(&query, block_idx)
    return query[:]
}


query_blocks_from_buyable :: proc(buyable: Buyable, query_amount: BlocksSize) -> BlocksQuery {
    context.allocator = query_system_alloc
    query := make(BlocksQuery, query_amount)
    query_curr_idx : BlocksSize = 0
    for &block in block_system.blocks {
        if query_curr_idx == query_amount do break

        for block_owner in block.owned_by {
            if block_owner == buyable {
                query[query_curr_idx] = &block
                query_curr_idx += 1
                break
            }
        }
    }
    return query
}

assign_all_blocks_to_buyables :: proc() {
    for &block in block_system.blocks {
        for block_owner in block.owned_by {
            assigned_blocks := &(&DB.buyable_data[block_owner]).assigned_blocks
            append(assigned_blocks, &block)
        }
    }
}
 
query_all_blocks_from_buyable :: proc(buyable: Buyable) -> BlocksQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]^Block, 0)
    for &block in block_system.blocks do if _contains(block.owned_by[:], buyable) do append(&query, &block)
    return query[:]
}

block_system_assign_leftover :: proc(buyable: Buyable) {

    buyable_data := &DB.buyable_data[buyable]
    blocks_to_assign := buyable_data.blocks_left_to_assign

    for block_idx in 0..<blocks_to_assign do _create_new_block_with_owners(buyable)
}

_create_new_block_with_owners :: proc(buyables: ..Buyable) {
    new_block : Block
    for buyable in buyables {
        assert(DB.buyable_data[buyable].blocks_left_to_assign > 0, "No blocks left to assign")
        _assert_buyable_wont_clash_in_block(&new_block, buyable)
        buyable_data := &DB.buyable_data[buyable]
        buyable_data.blocks_left_to_assign -= 1
        buyable_data.assigned_blocks_amount += 1
        append(&new_block.owned_by, buyable)
    }
    append(&block_system.blocks, new_block)
}

_add_buyables_as_owner_of_block_idx :: proc(block_idx: int, buyables: ..Buyable) {
    for buyable in buyables {
        assert(DB.buyable_data[buyable].blocks_left_to_assign > 0, "No blocks left to assign")
        _assert_buyable_wont_clash_in_block_idx(block_idx, buyable)
        buyable_data := &DB.buyable_data[buyable]
        buyable_data.blocks_left_to_assign -= 1
        buyable_data.assigned_blocks_amount += 1
        append(&block_system.blocks[block_idx].owned_by, buyable)
    }
}

_assign_share_minimizing_overlap :: proc(buyableA, buyableB: Buyable, blocks_to_share: BlocksSize) {
    fmt.println("Assigning Minimizing Overlap", buyableA, buyableB, blocks_to_share)

    b_data_a := &DB.buyable_data[buyableA]
    b_data_b := &DB.buyable_data[buyableB]
    already_shared_blocks_amount : BlocksSize
    {   // Calc already_shared_blocks_amount
        query_b := query_all_blocks_indices_from_buyable(buyableB)
        defer free_all(query_system_alloc)
        for assigned_block_idx in query_b {
            queried_block := block_system.blocks[assigned_block_idx]
            if _contains(queried_block.owned_by[:], buyableA) do already_shared_blocks_amount += 1
        }
    }
    amount_of_blocks_left_to_share := blocks_to_share - already_shared_blocks_amount
    {   // Try to create the maximum amount of new blocks
        max_amount_of_blocks_to_create := min(amount_of_blocks_left_to_share, b_data_a.blocks_left_to_assign, b_data_b.blocks_left_to_assign)
        for _ in 0..<max_amount_of_blocks_to_create {
            _create_new_block_with_owners(buyableA, buyableB)
            amount_of_blocks_left_to_share -= 1
        }
    }
    {   // Assign obligatory overlap
        if amount_of_blocks_left_to_share > 0 {
            query_a := query_blocks_indices_from_buyable_that_dont_clash_with_buyable(buyableA, buyableB, amount_of_blocks_left_to_share)
            defer free_all(query_system_alloc)
            for assigned_block_idx in query_a {
                queried_block := &block_system.blocks[assigned_block_idx]
                _add_buyables_as_owner_of_block_idx(assigned_block_idx, buyableB)
                amount_of_blocks_left_to_share -= 1
            }
        }
    }
}

_assign_share_maximizing_overlap :: proc(buyableA, buyableB: Buyable, blocks_to_share: BlocksSize) {
    fmt.println("Assigning Maximizing Overlap", buyableA, buyableB, blocks_to_share)

    b_data_a := &DB.buyable_data[buyableA]
    b_data_b := &DB.buyable_data[buyableB]

    already_shared_blocks_amount : BlocksSize
    {   // Calc already_shared_blocks_amount
        query_b := query_all_blocks_indices_from_buyable(buyableB)
        defer free_all(query_system_alloc)
        for assigned_block_idx in query_b {
            queried_block := block_system.blocks[assigned_block_idx]
            if _contains(queried_block.owned_by[:], buyableA) do already_shared_blocks_amount += 1
        }
    }

    if already_shared_blocks_amount >= blocks_to_share do return
    amount_of_blocks_left_to_share := blocks_to_share - already_shared_blocks_amount
    {   // Query Blocks of A, assign them to B.
        query_a := query_all_blocks_indices_from_buyable_that_dont_clash_with_buyable(buyableA, buyableB)
        defer free_all(query_system_alloc)
        queried_blocks_to_share_amount := min(BlocksSize(len(query_a)), amount_of_blocks_left_to_share)
        for relative_idx in 0..<queried_blocks_to_share_amount {
            assigned_block_of_a_idx := query_a[relative_idx]
         
            _add_buyables_as_owner_of_block_idx(assigned_block_of_a_idx, buyableB)
            amount_of_blocks_left_to_share -= 1
        }}
    {   // Create new blocks for both
        for _ in 0..<amount_of_blocks_left_to_share do _create_new_block_with_owners(buyableA, buyableB)
    }
}

block_system_assign_share :: proc(first_buyable, second_buyable: Buyable, blocks_to_share : BlocksSize, strategy: ShareStrategy) {
    
    buyableA, buyableB : Buyable
    {   // Assign correct ordering, first goes the most partially assigned buyable
        data_from_first := &DB.buyable_data[first_buyable]
        data_from_second := &DB.buyable_data[second_buyable]
        if data_from_first.assigned_blocks_amount >= data_from_second.assigned_blocks_amount do buyableA, buyableB = first_buyable, second_buyable
        else do buyableA, buyableB = second_buyable, first_buyable
    }
    switch strategy {
        case .MinimizingOverlap:
            _assign_share_minimizing_overlap(buyableA, buyableB, blocks_to_share)
        case .MaximizingOverlap:
            _assign_share_maximizing_overlap(buyableA, buyableB, blocks_to_share)
    }

}

block_system_assign_contains :: proc(buyableA, buyableB: Buyable){
    fmt.println("Handling", buyableA, "contains", buyableB)

    b_data_a := &DB.buyable_data[buyableA]
    b_data_b := &DB.buyable_data[buyableB]
    {   // Give already assigned blocks from B a block of A 
        // assignable_blocks_from_a := query_blocks_indices_from_buyable_that_dont_already_own(buyableA, buyableB)
        partial_assignment_b := query_all_blocks_indices_from_buyable_that_buyable_doesnt_require(buyableB, buyableA)
        defer free_all(query_system_alloc)
        partial_assignment_b_amount := BlocksSize(len(partial_assignment_b))
        assert(b_data_a.blocks_left_to_assign >= partial_assignment_b_amount, fmt.tprintln("Not enough blocks to assign contains between", buyableA, "->", buyableB))

        for partially_assigned_block_idx in partial_assignment_b {
            _add_buyables_as_owner_of_block_idx(partially_assigned_block_idx, buyableA)
        }
    }
    {   // Create new blocks for B that are to be owned by A, prioritizing new blocks of A
        new_blocks_to_assign, old_blocks_to_assign : BlocksSize
        if b_data_b.blocks_left_to_assign <= b_data_a.blocks_left_to_assign {
            new_blocks_to_assign = b_data_b.blocks_left_to_assign
        }
        else {
            new_blocks_to_assign = b_data_a.blocks_left_to_assign
            old_blocks_to_assign = b_data_b.blocks_left_to_assign - new_blocks_to_assign
        }

        for relative_block_idx in 0..<new_blocks_to_assign do _create_new_block_with_owners(buyableA, buyableB)

        partial_assignment_a := query_blocks_indices_from_buyable_that_dont_clash_with_buyable(buyableA, buyableB, old_blocks_to_assign)
        defer free_all(query_system_alloc)

        for assigned_block_idx_of_a in partial_assignment_a do _add_buyables_as_owner_of_block_idx(assigned_block_idx_of_a, buyableB)
    }
    if b_data_b.blocks_left_to_assign > 0 do panic(fmt.tprintln(buyableB, "not contained by", buyableA))
}

_block_clashes_with_buyable :: proc(block: Block, buyable: Buyable) -> bool {
    { // Check if a req is already owned
        switch b in buyable {
            case PerkID:
                b_perk_data := DB.perk_data[b]
                for owner in block.owned_by {
                    #partial switch o in owner {
                        case PerkID:
                            if o == b do return true
                    }
                }
            case LeveledSkill:
                id := b.id
                level := b.level
                for owner in block.owned_by {
                    #partial switch o in owner {
                        case LeveledSkill:
                            if o.id == id do return true
                    }
                }
        }
    }  
    return false
} 


_buyable_requires_block :: proc(block: Block, buyable: Buyable) -> bool {
    { // Check if a req is already owned
        switch b in buyable {
            case PerkID:
                b_perk_data := DB.perk_data[b]
                for owner in block.owned_by {
                    #partial switch o in owner {
                        case PerkID:
                            if o in _flattened_pre_reqs(b) do return true
                        case LeveledSkill:
                            for req_entry in b_perk_data.skills_reqs {
                                switch r_entry in req_entry {
                                    case LeveledSkill:
                                        if r_entry == buyable do return true
                                    case SKILL_REQ_OR_GROUP:
                                        for req_in_or_group in r_entry {
                                            if req_in_or_group == buyable do return true
                                        }
                                }
                            }
                    }
                }
            case LeveledSkill:
                id := b.id
                level := b.level
                for owner in block.owned_by {
                    #partial switch o in owner {
                        case LeveledSkill:
                            if o.id == id && o.level <= level do return true
                    }
                }
        }
    }
    return false
}

_block_requires_buyable :: proc(block: Block, buyable: Buyable) -> bool {
    { // Check if a req is already owned
        switch b in buyable {
            case PerkID:
                for owner in block.owned_by {
                    #partial switch o in owner {
                        case PerkID:
                            if b in _flattened_pre_reqs(o) do return true
                    }
                }
            case LeveledSkill:
                id := b.id
                level := b.level
                for owner in block.owned_by {
                    #partial switch o in owner {
                        case LeveledSkill:
                            if o.id == id && o.level >= level do return true
                    }
                }
        }
    }
    return false
}

_should_add_to_owned :: proc(list: [dynamic]Buyable, buyable: Buyable) -> bool {
    return !_contains(list[:], buyable)
} 

_assert_buyable_wont_clash_in_block :: proc(block: ^Block, buyable: Buyable) {
        #partial switch b in buyable {
            case LeveledSkill:
                for block_owner in block.owned_by {
                    #partial switch skill_owner in block_owner {
                        case LeveledSkill:
                            assert(skill_owner.id != b.id || skill_owner.level == b.level, fmt.tprint("Found", buyable, "and", block_owner, "sharing same block", block))
                    }
                }
        }   
}
_assert_buyable_wont_clash_in_block_idx :: proc(block_idx: int, buyable: Buyable) {
    block := &block_system.blocks[block_idx]
    _assert_buyable_wont_clash_in_block(block, buyable)
}

_contains :: proc(list: []$T, value: T) -> bool {
    for elem in list do if elem == value do return true
    return false
}
