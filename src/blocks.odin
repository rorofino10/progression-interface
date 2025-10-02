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
BlocksSize :: u32
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
        if u32(len(query)) == query_amount do break

        if _contains(block.owned_by[:], buyable) do append(&query, block_idx)
    }
    assert(u32(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyable))
    return query[:]
}
query_blocks_from_buyable_that_arent_already_owned_by :: proc(buyableA, buyableB: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if u32(len(query)) == query_amount do break

        if _contains(block.owned_by[:], buyableA) && _buyable_already_owns_block(block, buyableB) do append(&query, block_idx)
    }
    assert(u32(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyableA))
    return query[:]
}
query_blocks_indices_from_buyable_that_dont_own :: proc(buyableA, buyableB: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if u32(len(query)) == query_amount do break

        if _contains(block.owned_by[:], buyableA) && !_block_owns_buyable(block, buyableB) do append(&query, block_idx)
    }
    assert(u32(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyableA))
    return query[:]
}

query_all_blocks_from_buyable_that_arent_already_owned_by :: proc(buyable, owner: Buyable) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0)
    for &block, block_idx in block_system.blocks {
        if _block_owns_buyable(block, owner) do continue
        if _contains(block.owned_by[:], buyable) do append(&query, block_idx)
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


_contains :: proc(list: []$T, value: T) -> bool {
    for elem in list do if elem == value do return true
    return false
}


block_system_assign_leftover :: proc(buyable: Buyable) {

    buyable_data := &DB.buyable_data[buyable]
    blocks_to_assign := buyable_data.blocks_left_to_assign

    for block_idx in 0..<blocks_to_assign {
        new_block := Block{owned_by={buyable}}
        append(&block_system.blocks, new_block)
    }

    buyable_data.blocks_left_to_assign = 0
    buyable_data.assigned_blocks_amount += blocks_to_assign

}

_add_buyables_as_owner_of_block :: proc(block: ^Block, buyables: ..Buyable) {
    for buyable in buyables {
        _assert_buyable_wont_clash_in_block(block, buyable)
        buyable_data := &DB.buyable_data[buyable]
        buyable_data.blocks_left_to_assign -= 1
        buyable_data.assigned_blocks_amount += 1
        append(&block.owned_by, buyable)
    }
}

block_system_assign_share :: proc(buyableA, buyableB: Buyable, blocks_to_share : BlocksSize) {
    // fmt.println("Handling Share", buyableA, buyableB, blocks_to_share)
    b_data_a := &DB.buyable_data[buyableA]
    b_data_b := &DB.buyable_data[buyableB]

    {   // Query Blocks of A, assign them B.
        blocks_of_a_to_be_shared_amount := min(b_data_a.assigned_blocks_amount, blocks_to_share)
        query_a := query_blocks_indices_from_buyable(buyableA, blocks_of_a_to_be_shared_amount)
        defer free_all(query_system_alloc)

        for assigned_block_of_a_idx in query_a {
            query_block_a := &block_system.blocks[assigned_block_of_a_idx]
         
            if _should_add_to_owned(query_block_a.owned_by, buyableB) {
                _add_buyables_as_owner_of_block(query_block_a, buyableB)
            }
        }}
    {   // Create new blocks for both
        left_over_blocks_to_share : BlocksSize = 0
        if blocks_to_share > b_data_a.assigned_blocks_amount do left_over_blocks_to_share = blocks_to_share - b_data_a.assigned_blocks_amount
        for relative_block_idx in 0..<left_over_blocks_to_share {
            new_block : Block

            _add_buyables_as_owner_of_block(&new_block, buyableA, buyableB)
            append(&block_system.blocks, new_block)
        }          
    }
}

block_system_assign_contains :: proc(buyableA, buyableB: Buyable){
    fmt.println("Handling", buyableA, "contains", buyableB)
    b_data_a := &DB.buyable_data[buyableA]
    b_data_b := &DB.buyable_data[buyableB]
    {   // Give already assigned blocks from B a block of A 
        // assignable_blocks_from_a := query_blocks_indices_from_buyable_that_dont_already_own(buyableA, buyableB)
        partial_assignment_b := query_all_blocks_from_buyable_that_arent_already_owned_by(buyableB, buyableA)
        defer free_all(query_system_alloc)
        partial_assignment_b_amount := BlocksSize(len(partial_assignment_b))
        if b_data_a.blocks_left_to_assign < partial_assignment_b_amount do panic(fmt.tprintln("Not enough blocks to assign contains between", buyableA, "->", buyableB))

        for partially_assigned_block_idx in partial_assignment_b {
            block := block_system.blocks[partially_assigned_block_idx]
            // fmt.println("Partial assigning", block, buyableA)
            _add_buyables_as_owner_of_block(&block, buyableA)
        }
        print_buyable_blocks_by_query(buyableA)
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

        for relative_block_idx in 0..<new_blocks_to_assign {
            new_block : Block

            _add_buyables_as_owner_of_block(&new_block, buyableA, buyableB)
            append(&block_system.blocks, new_block)
        }

        partial_assignment_a := query_blocks_indices_from_buyable_that_dont_own(buyableA, buyableB, old_blocks_to_assign)
        defer free_all(query_system_alloc)

        for assigned_block_idx_of_a in partial_assignment_a {
            assigned_block := block_system.blocks[assigned_block_idx_of_a]
            _add_buyables_as_owner_of_block(&assigned_block, buyableB)
        }
    }
}

_block_owns_buyable :: proc(block: Block, buyable: Buyable) -> bool {
    { // Check if a req is already owned
        switch b in buyable {
            case PerkID:
                b_perk_data := DB.perk_data[b]
                for owner in block.owned_by {
                    #partial switch o in owner {
                        case PerkID:
                            if o in b_perk_data.prereqs do return true
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
_buyable_already_owns_block :: proc(block: Block, buyable: Buyable) -> bool {
    { // Check if a req is already owned
        // if _contains(block.owned_by[:], buyable) do return true
        switch b in buyable {
            case PerkID:
                for owner in block.owned_by {
                    #partial switch o in owner {
                        case PerkID:
                            perk_data := DB.perk_data[o]
                            if b in perk_data.prereqs do return true
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
                            if skill_owner.id == b.id && skill_owner.level != b.level do panic(fmt.tprint("Found", buyable, "and", block_owner, "sharing same block", block))
                    }
                }
        }   
}
