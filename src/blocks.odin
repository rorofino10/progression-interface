package main

import "base:runtime"
import "core:mem"

MAX_BLOCKS_AMOUNT :: 10_000
BLOCK_SYSTEM_ALLOCATED_MEM :: runtime.Megabyte

block_system_alloc: mem.Allocator
block_system_arena: mem.Arena
block_system_buffer: []byte

block_system: BlockSystem

range_len :: proc(range: BlockRange) -> BlocksSize {
    return range.end - range.start + 1
}

BlockRange :: struct {
    start   : BlocksSize,
    end     : BlocksSize,
}

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

    DB.buyable_data[buyable] = BuyableData{
        owned_blocks_range = BlockRange{start=block_system.last_block_ptr, end=block_system.last_block_ptr+blocks_to_assign-1}
    }
    for owned_block_idx in DB.buyable_data[buyable].owned_blocks_range.start ..= DB.buyable_data[buyable].owned_blocks_range.end {
        append(&block_system.blocks[owned_block_idx].owned_by, buyable)
    }
    block_system.last_block_ptr += blocks_to_assign
}
