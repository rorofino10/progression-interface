#+feature dynamic-literals
package main

import "core:math"
import "core:fmt"
import "base:runtime"
import "core:mem"

BLOCK_SYSTEM_ALLOCATED_MEM :: 2 * runtime.Megabyte
QUERY_SYSTEM_ALLOCATED_MEM :: 2 * runtime.Megabyte

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
    context.allocator = block_system_alloc

    block_system = new(BlockSystem)
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
    query := make(BlocksIndexQuery, query_amount)
    query_curr_idx : BlocksSize = 0
    for &block, block_idx in block_system.blocks {
        if query_curr_idx == query_amount do break

        for block_owner in block.owned_by {
            if block_owner == buyable {
                query[query_curr_idx] = block_idx
                query_curr_idx += 1
                break
            }
        }
    }
    return query
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

query_all_blocks_from_buyable :: proc(buyable: Buyable) -> BlocksQuery {
    context.allocator = query_system_alloc
    query := make([dynamic]^Block, 0)
    for &block in block_system.blocks {
        for block_owner in block.owned_by {
            if block_owner == buyable {
                append(&query, &block)
                break
            }
        }
    }
    return query[:]
}

buyable_in_list :: proc(list: [dynamic]Buyable, buyable: Buyable) -> bool {
    for elem in list do if elem == buyable do return true

    // Check if same Skill Id Shared
    {
        #partial switch b in buyable {
            case LeveledSkill:
                for elem in list {
                    #partial switch e in elem {
                        case LeveledSkill:
                            if e.id == b.id && e.level != b.level do panic(fmt.tprint("Found", buyable, "and", elem, "sharing same block."))
                    }
                }
        }
    }

    return false
}

block_system_assign_share :: proc(buyableA, buyableB: Buyable, blocks_to_share : BlocksSize) {
    {// Create a new Shared Group
        query_a := query_blocks_indices_from_buyable(buyableA, blocks_to_share)
        query_b := query_blocks_indices_from_buyable(buyableB, blocks_to_share)

        defer free_all(query_system_alloc)
        
        for relative_block_idx in 0..<blocks_to_share {
            query_block_a := &block_system.blocks[query_a[relative_block_idx]]
            query_block_b := &block_system.blocks[query_b[relative_block_idx]]
            defer {
                query_block_b.owned_by = {}
                query_block_a.owned_by = {}
            }
            new_block : Block

            for owner in query_block_a.owned_by do if !buyable_in_list(new_block.owned_by, owner) do append(&new_block.owned_by, owner)
            for owner in query_block_b.owned_by do if !buyable_in_list(new_block.owned_by, owner) do append(&new_block.owned_by, owner)
            append(&block_system.blocks, new_block)
        }          
    }
}
