package main

import "core:fmt"
import "base:runtime"
import "core:mem"

MAX_BLOCKS_AMOUNT :: 10_000
BLOCK_SYSTEM_ALLOCATED_MEM :: runtime.Megabyte

block_system_alloc: mem.Allocator
block_system_arena: mem.Arena
block_system_buffer: []byte

block_system: BlockSystem

BlockSystem :: struct {
    blocks          : Blocks,
    last_block_ptr  : BlocksSize,
}

Block :: struct {
    bought      : bool,
	owned_by	: [dynamic]Buyable,
}

Blocks :: []Block
BlocksSize :: u32


init_block_system_alloc :: proc() -> Error {
	block_system_buffer = make([]byte, BLOCK_SYSTEM_ALLOCATED_MEM) or_return
	mem.arena_init(&block_system_arena, block_system_buffer)
	block_system_alloc = mem.arena_allocator(&block_system_arena)

    return nil
}

block_system_allocate :: proc() -> Error {
    context.allocator = block_system_alloc

    block_system.blocks = make(Blocks, MAX_BLOCKS_AMOUNT)

    return nil
}

block_system_assign :: proc(buyable: Buyable, blocks_to_assign: BlocksSize) {
    context.allocator = block_system_alloc

    b_data := &DB.buyable_data[buyable]

    for block_idx in block_system.last_block_ptr..=block_system.last_block_ptr+blocks_to_assign-1 {
        append(&block_system.blocks[block_idx].owned_by, buyable)
    }

    block_system.last_block_ptr += blocks_to_assign
}

query_blocks_from_buyable :: proc(buyable: Buyable, query_amount: BlocksSize) -> []^Block {
    query := make([]^Block, query_amount)
    query_curr_idx : BlocksSize = 0
    for block_idx in 0..<block_system.last_block_ptr {
        if query_curr_idx == query_amount do break

        block := &block_system.blocks[block_idx]
        for block_owner in block.owned_by {
            if block_owner == buyable {
                query[query_curr_idx] = block
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

block_system_assign_share :: proc(buyableA, buyableB: Buyable, strength: STRENGTH) {

    context.allocator = block_system_alloc

    b_data_a := &DB.buyable_data[buyableA]
    b_data_b := &DB.buyable_data[buyableB]

	blocks_to_share_a := BlocksSize(f32(b_data_a.blocks_left_to_assign) * f32(strength) / 100)
	blocks_to_share_b := BlocksSize(f32(b_data_b.blocks_left_to_assign) * f32(strength) / 100)

    blocks_to_assign := max(blocks_to_share_a, blocks_to_share_a)

    {// Create a new Shared Group
        // Query blocks
        query_a := query_blocks_from_buyable(buyableA, blocks_to_share_a)
        query_b := query_blocks_from_buyable(buyableB, blocks_to_share_b)
        defer delete(query_b)
        defer delete(query_a)
        
        for block_idx, relative_block_idx in block_system.last_block_ptr..=block_system.last_block_ptr+blocks_to_assign-1 {

            query_block_a := query_a[relative_block_idx]
            query_block_b := query_b[relative_block_idx]
            defer {
                delete(query_block_a.owned_by)
                delete(query_block_b.owned_by)
                query_block_a.owned_by = nil
                query_block_b.owned_by = nil
            }
            for owner in query_block_a.owned_by {
                append(&block_system.blocks[block_idx].owned_by, owner)
            }
            for owner in query_block_b.owned_by {
                append(&block_system.blocks[block_idx].owned_by, owner)
            }
        }          
    }

    block_system.last_block_ptr += blocks_to_assign
}

// I have to share 
