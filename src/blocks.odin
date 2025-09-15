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

BlockGroup :: struct {
    blocks : [dynamic]^Block,
}

OwnedBlock :: union {
    ^Block,
    ^BlockGroup,
}

Block :: struct {
    bought      : bool,
	owned_by	: [dynamic]Buyable,
}

Blocks :: []Block
DynOwnedBlocks :: [dynamic]OwnedBlock
BlocksSize :: u32

owned_block_is_bought :: proc(block: OwnedBlock) -> bool {
    switch b in block {
        case ^Block:
            return b.bought
        case ^BlockGroup:
            for single_block in b.blocks {
                if !single_block.bought do return false 
            }
            return true
    }
    return false
}

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
        append(&b_data.owned_blocks, &block_system.blocks[block_idx])
        append(&block_system.blocks[block_idx].owned_by, buyable)
    }

    b_data.blocks_left_to_assign = 0
    block_system.last_block_ptr += blocks_to_assign
}

block_system_assign_share :: proc(buyableA, buyableB: Buyable, blocks_share_a, blocks_share_b, blocks_share: BlocksSize) {
    context.allocator = block_system_alloc

    b_data_a := &DB.buyable_data[buyableA]
    b_data_b := &DB.buyable_data[buyableB]

    { // From A
        for block_idx in block_system.last_block_ptr..=block_system.last_block_ptr+blocks_share_a-1 {
            append(&b_data_a.owned_blocks, &block_system.blocks[block_idx])
            append(&block_system.blocks[block_idx].owned_by, buyableA)
        }
        b_data_a.blocks_left_to_assign -= blocks_share_a
    }
    { // From B
        for block_idx in block_system.last_block_ptr..=block_system.last_block_ptr+blocks_share_b-1 {
            append(&b_data_b.owned_blocks, &block_system.blocks[block_idx])
            append(&block_system.blocks[block_idx].owned_by, buyableB)
        }
        b_data_b.blocks_left_to_assign -= blocks_share_b
    }
    block_system.last_block_ptr += blocks_share

}

// I have to share 
