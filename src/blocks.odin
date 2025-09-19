#+feature dynamic-literals
package main

import "core:math"
import "core:fmt"
import "base:runtime"
import "core:mem"

MAX_BLOCKS_AMOUNT :: 10_000
BLOCK_SYSTEM_ALLOCATED_MEM :: runtime.Megabyte

block_system_alloc: mem.Allocator
block_system_arena: mem.Arena
block_system_buffer: []byte

block_system: ^BlockSystem

BlockSystem :: struct {
    blocks          : Blocks,
}

Block :: struct {
    bought      : bool,
	owned_by	: [dynamic]Buyable,
}

Blocks :: [dynamic]Block
BlocksSize :: u32


init_block_system_alloc :: proc() -> Error {
	block_system_buffer = make([]byte, BLOCK_SYSTEM_ALLOCATED_MEM) or_return
	mem.arena_init(&block_system_arena, block_system_buffer)
	block_system_alloc = mem.arena_allocator(&block_system_arena)

    return nil
}

block_system_allocate :: proc() -> Error {
    context.allocator = block_system_alloc

    block_system = new(BlockSystem)

    return nil
}

block_system_assign :: proc(buyable: Buyable, blocks_to_assign: BlocksSize) {
    context.allocator = block_system_alloc

    b_data := &DB.buyable_data[buyable]

    for block_idx in 0..<blocks_to_assign {
        new_block := Block{owned_by={buyable}}
        append(&block_system.blocks, new_block)
    }
}

query_blocks_from_buyable :: proc(buyable: Buyable, query_amount: BlocksSize) -> []^Block {
    query := make([]^Block, query_amount)
    query_curr_idx : BlocksSize = 0
    for &block in block_system.blocks {
        if query_curr_idx == query_amount do break

        for block_owner in block.owned_by {
            if block_owner == buyable {
                query[query_curr_idx] = &block
                query_curr_idx += 1
            }
        }
    }
    return query
}

query_all_blocks_from_buyable :: proc(buyable: Buyable) -> []^Block {
    blocks := DB.buyable_data[buyable].blocks_left_to_assign
    return query_blocks_from_buyable(buyable, blocks)
}

block_system_assign_share :: proc(buyableA, buyableB: Buyable, blocks_to_share : BlocksSize) {
    context.allocator = block_system_alloc
    fmt.println("Sharing", buyableA, buyableB)
    {// Create a new Shared Group
        query_a := query_blocks_from_buyable(buyableA, blocks_to_share)
        query_b := query_blocks_from_buyable(buyableB, blocks_to_share)
        defer delete(query_a)
        defer delete(query_b)
        
        for relative_block_idx in 0..<blocks_to_share {
            query_block_a := query_a[relative_block_idx]
            query_block_b := query_b[relative_block_idx]
            defer {
                delete(query_block_a.owned_by)
                delete(query_block_b.owned_by)
                query_block_b.owned_by = nil
                query_block_a.owned_by = nil
            }
            new_block : Block
            for owner in query_block_b.owned_by do append(&new_block.owned_by, owner)
            for owner in query_block_a.owned_by do append(&new_block.owned_by, owner)
            append(&block_system.blocks, new_block)
        }          
    }
}
