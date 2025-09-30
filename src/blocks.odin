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

block_system_assign :: proc(buyable: Buyable, blocks_to_assign: BlocksSize) {

    b_data := &DB.buyable_data[buyable]

    for block_idx in 0..<blocks_to_assign {
        new_block := Block{owned_by={buyable}}
        b_data.blocks_left_to_assign -= 1
        b_data.assigned_blocks_amount += 1
        append(&block_system.blocks, new_block)
    }
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
query_blocks_indices_from_buyable_not_owner_by_reqs :: proc(buyable, owner: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if u32(len(query)) == query_amount do break

        if _is_owner_by_reqs(block, owner) do continue
        if _contains(block.owned_by[:], buyable) do append(&query, block_idx)
    }
    assert(u32(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyable))
    return query[:]
}
query_blocks_indices_from_buyable_not_owned_by_reqs :: proc(buyable, owner: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if u32(len(query)) == query_amount do break

        if _is_owned_by_reqs(block, owner) do continue
        if _contains(block.owned_by[:], buyable) do append(&query, block_idx)
    }
    assert(u32(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyable))
    return query[:]
}

query__all_blocks_indices_from_buyable_not_owner_by_reqs :: proc(buyable, owner: Buyable) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0)
    for &block, block_idx in block_system.blocks {
        if _is_owned_by_reqs(block, owner) do continue
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
                append(&query_block_a.owned_by, buyableB)
                b_data_b.blocks_left_to_assign -= 1
                b_data_b.assigned_blocks_amount += 1
            }
        }
        left_over_blocks_to_share : BlocksSize = 0
        if blocks_to_share > b_data_a.assigned_blocks_amount do left_over_blocks_to_share = blocks_to_share - b_data_a.assigned_blocks_amount
        for relative_block_idx in 0..<left_over_blocks_to_share {
            new_block : Block

            append(&new_block.owned_by, buyableA)
            append(&new_block.owned_by, buyableB)
            b_data_b.blocks_left_to_assign -= 1
            b_data_b.assigned_blocks_amount += 1
            b_data_a.blocks_left_to_assign -= 1
            b_data_a.assigned_blocks_amount += 1
            append(&block_system.blocks, new_block)
        }          
    }
}

block_system_assign_contains :: proc(buyableA, buyableB: Buyable){
    {//
        query_b := query__all_blocks_indices_from_buyable_not_owner_by_reqs(buyableB, buyableA)
        blocks_to_contain := BlocksSize(len(query_b))
        query_a := query_blocks_indices_from_buyable_not_owned_by_reqs(buyableA, buyableB, blocks_to_contain)
        defer free_all(query_system_alloc)

        removal_list := make([dynamic]int, 0)
        defer delete(removal_list)
        
        for relative_block_idx in 0..<blocks_to_contain {
            query_block_a := &block_system.blocks[query_a[relative_block_idx]]
            query_block_b := &block_system.blocks[query_b[relative_block_idx]]

            // add to removal list
            append(&removal_list, query_a[relative_block_idx])
            append(&removal_list, query_b[relative_block_idx])
            new_block : Block

            for owner in query_block_a.owned_by do if _should_add_to_owned(new_block.owned_by, owner) do append(&new_block.owned_by, owner)
            for owner in query_block_b.owned_by do if _should_add_to_owned(new_block.owned_by, owner) do append(&new_block.owned_by, owner)
            append(&block_system.blocks, new_block)
        }          
        // sort.merge_sort(removal_list[:])
        for idx_to_remove in removal_list {
            delete(block_system.blocks[idx_to_remove].owned_by)
            // ordered_remove(&block_system.blocks, idx_to_remove)
            block_system.blocks[idx_to_remove].owned_by = nil
        }
    }
}

_is_owned_by_reqs :: proc(block: Block, buyable: Buyable) -> bool {
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
                            if o.id == id && o.level > level do return true
                    }
                }
        }
    }
    return false
}
_is_owner_by_reqs :: proc(block: Block, buyable: Buyable) -> bool {
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
                            if o.id == id && o.level < level do return true
                    }
                }
        }
    }
    return false
}

_should_add_to_owned :: proc(list: [dynamic]Buyable, buyable: Buyable) -> bool {
    if _contains(list[:], buyable) do return false
    // Check if same Skill Id Shared
    {
        #partial switch b in buyable {
            case LeveledSkill:
                for elem in list {
                    #partial switch e in elem {
                        case LeveledSkill:
                            if e.id == b.id && e.level != b.level do panic(fmt.tprint("Found", buyable, "and", elem, "sharing same block. List:", list))
                    }
                }
        }
    }
    return true
} 
