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
query_blocks_indices_from_buyable_where_block_not_owns_buyable :: proc(buyableA, buyableB: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if u32(len(query)) == query_amount do break

        if _block_is_owner_of_buyable(block, buyableB) do continue
        if _contains(block.owned_by[:], buyableA) do append(&query, block_idx)
    }
    assert(u32(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyableA))
    return query[:]
}

query_blocks_all_indices_from_buyable_where_block_not_owns_buyable :: proc(buyableA, buyableB: Buyable) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    // TODO: make this more performant
    query := make([dynamic]int, 0)
    for &block, block_idx in block_system.blocks {
        if _block_is_owner_of_buyable(block, buyableB) do continue
        if _contains(block.owned_by[:], buyableA) do append(&query, block_idx)
    }
    return query[:]    
}

query_blocks_indices_from_buyable_where_buyable_not_owns_block :: proc(buyableA, buyableB: Buyable, query_amount: BlocksSize) -> BlocksIndexQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]int, 0, query_amount)
    for &block, block_idx in block_system.blocks {
        if u32(len(query)) == query_amount do break

        if _block_is_owned_by_buyable(block, buyableB) do continue
        if _contains(block.owned_by[:], buyableA) do append(&query, block_idx)
    }
    assert(u32(len(query)) == query_amount, fmt.tprint(len(query), query_amount, buyableA))
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
    fmt.println("Handling share between", buyableA, buyableB)
    block_to_assign := blocks_to_share
    {
        query_a := query_blocks_indices_from_buyable(buyableA, blocks_to_share)
        defer free_all(query_system_alloc)

        for block_idx in query_a {
            if _contains(block_system.blocks[block_idx].owned_by[:], buyableB) do block_to_assign -= 1
        }
    }
    fmt.println("To share", block_to_assign)

    {// Assign B blocks to A, minimizing
        query_a := query_blocks_indices_from_buyable(buyableA, block_to_assign)
        query_b := query_blocks_indices_from_buyable(buyableB, block_to_assign)
        defer free_all(query_system_alloc)

        for relative_block_idx in 0..<block_to_assign {
            query_block_a := &block_system.blocks[query_a[relative_block_idx]]
            query_block_b := &block_system.blocks[query_b[relative_block_idx]]

            for owner in query_block_b.owned_by do append(&query_block_a.owned_by, owner)

            query_block_b.owned_by = nil
        }          
    }
}

block_system_assign_contains :: proc(buyableA, buyableB: Buyable){
    // fmt.println("Handling containts", buyableA, buyableB, blocks_supposed_to_share)
    // print_buyable_blocks_by_query(buyableA)
    // print_buyable_blocks_by_query(buyableB)
    
    // blocks_to_share := blocks_supposed_to_share
    // for relative_block_idx in 0..<blocks_supposed_to_share {
    //     query_block_b := block_system.blocks[query_b[relative_block_idx]]
    //     if _block_is_owned_by_buyable(query_block_b, buyableA) do blocks_to_share -= 1
    // }
    // free_all(query_system_alloc)
    // // fmt.println(blocks_to_share, blocks_supposed_to_share)
    // {// Create a new Shared Group
    //     query_a := query_blocks_indices_from_buyable_not_owned_by_reqs(buyableA, buyableB, blocks_to_share)
    //     query_b := query_blocks_indices_from_buyable_not_owner_by_reqs(buyableB, buyableA, blocks_to_share)
    //     defer free_all(query_system_alloc)

    //     removal_list := make([dynamic]int, 0)
    //     defer delete(removal_list)
        
    //     for relative_block_idx in 0..<blocks_to_share {
    //         query_block_a := &block_system.blocks[query_a[relative_block_idx]]
    //         query_block_b := &block_system.blocks[query_b[relative_block_idx]]

    //         // add to removal list
    //         append(&removal_list, query_a[relative_block_idx])
    //         append(&removal_list, query_b[relative_block_idx])
    //         new_block : Block

    //         for owner in query_block_a.owned_by do if _should_add_to_owned(new_block.owned_by, owner) do append(&new_block.owned_by, owner)
    //         for owner in query_block_b.owned_by do if _should_add_to_owned(new_block.owned_by, owner) do append(&new_block.owned_by, owner)
    //         append(&block_system.blocks, new_block)
    //     }          
    //     // sort.merge_sort(removal_list[:])
    //     for idx_to_remove in removal_list {
    //         delete(block_system.blocks[idx_to_remove].owned_by)
    //         // ordered_remove(&block_system.blocks, idx_to_remove)
    //         block_system.blocks[idx_to_remove].owned_by = nil
    //     }
    // }
}

_block_is_owner_of_buyable :: proc(block: Block, buyable: Buyable) -> bool {
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
                    switch o in owner {
                        case LeveledSkill:
                            if o.id == id && o.level >= level do return true
                        case PerkID:
                            perk_data := DB.perk_data[o]
                            // if _contains(perk_data.skills_reqs[:], b) do return true
                    }
                }
        }
    }
    return false
}
_block_is_owned_by_buyable :: proc(block: Block, buyable: Buyable) -> bool {
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
                    switch o in owner {
                        case LeveledSkill:
                            if o.id == id && o.level <= level do return true
                        case PerkID:
                            perk_data := DB.perk_data[o]
                            // if _contains(perk_data.skills_reqs[:], b) do return true
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
