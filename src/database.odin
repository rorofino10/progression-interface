package main

import "core:container/queue"
import "core:fmt"
import "core:math/rand"
LEVEL :: distinct u32
STRENGTH :: distinct u8

// CONSTANT
MAX_SKILL_LEVEL :: 3

// Artificial list size limits
MAX_SKILL_REQS :: 10

DatabaseError :: enum {
	None,
	LoadError,
}

LeveledSkill :: struct {
	id:    SkillID,
	level: LEVEL,
}

SkillData :: struct {
	blocks: BlocksSize,
	required_level: LEVEL,
}


Perks :: bit_set[PerkID]

PerkData :: struct {
	blocks:      BlocksSize,
	prereqs:     Perks,
	skills_reqs: [MAX_SKILL_REQS]LeveledSkill,
}


void :: struct {}

ConstraintError :: enum {
	None,
	ShareMissingPerk,
	StrengthIsNotPercentage,
	CannotOverlapWithItself,
}

BuyError :: enum {
	None,
	NotEnoughPoints,
	MissingRequiredSkills,
	MissingRequiredPerks,
	MissingRequiredUnitLevel,
	AlreadyHasSkill,
}

RefundError :: enum {
	None,
	BuyableNotOwned,
}

CycleInPreReqsError :: struct {
	repeated_perk:      PerkID,
}


BuyableCreationError :: union {
	CycleInPreReqsError,
}

Error :: union #shared_nil {
	BuyableCreationError,
	BuyError,
	ConstraintError,
}

Block :: struct {
	bought		: bool,
	linked_to	: [dynamic]^Block,
	owned_by	: Buyable
}

Blocks :: []Block
BlocksSize :: u32

Buyable :: union {
	PerkID,
	LeveledSkill,
}

Buyables :: []Buyable
DynBuyables :: [dynamic]Buyable

BuyableData :: struct {
	owned_blocks	: Blocks,
	bought_amount	: BlocksSize,
	bought			: bool,
	spent			: BlocksSize,
}



Database :: struct {
	skill_id_data	: map[SkillID][MAX_SKILL_LEVEL]SkillData,
	perk_data		: map[PerkID]PerkData,
	buyable_data 	: map[Buyable]BuyableData,

	// Constraint
	contains_constraint: map[Buyable]DynBuyables,
	drag_constraint	: map[SkillID]map[SkillID]LEVEL,
	share_constraints	: [dynamic]TShare,
	overlap_constraints : [dynamic]TOverlap,
}
DB : Database


Skill :: proc(skillID: SkillID, skill_data: [MAX_SKILL_LEVEL]SkillData) {
	DB.skill_id_data[skillID] = skill_data
}

DefineBlockProc :: proc(blockIdx: BlocksSize) -> (BlocksSize, LEVEL)

SkillByProc :: proc(skillID: SkillID, blockProc: DefineBlockProc){
	blocks_list : [MAX_SKILL_LEVEL]SkillData
	for idx in 1..=MAX_SKILL_LEVEL {
		blocks, level := blockProc(BlocksSize(idx))
		blocks_list[idx-1].blocks = blocks
		blocks_list[idx-1].required_level = level
	}
	Skill(skillID, blocks_list)
}

Perk :: proc(perkID: PerkID, blocks: BlocksSize, pre_reqs: Perks, skill_reqs: [dynamic]LeveledSkill) {
	defer delete(skill_reqs)

    assert(len(skill_reqs) <= MAX_SKILL_REQS)
	perk_data := PerkData{ blocks = blocks, prereqs = pre_reqs }
	for skill_req, idx in skill_reqs do perk_data.skills_reqs[idx] = skill_req
	DB.perk_data[perkID] = perk_data
}



init_db :: proc() -> Error{
	load_db()
	check_constraints() or_return
	create_buyables() or_return
	handle_constraints()
	return nil
}

create_buyables :: proc() -> BuyableCreationError {
	{ // Check for cycles in pre_reqs
		
		@static seen : Perks
		@static curr_path_stack : [dynamic]PerkID
		defer delete(curr_path_stack)

		check_for_cycles :: proc(perk: PerkID, curr_path: Perks) -> Maybe(PerkID) {
			append(&curr_path_stack, perk)
			if perk in curr_path do return perk
			if perk in seen do return nil
			seen |= {perk}
			new_curr_path := curr_path | {perk}
			for req_perk in DB.perk_data[perk].prereqs {
				repeated_perk := check_for_cycles(req_perk, new_curr_path)
				if repeated_perk != nil do return repeated_perk
				pop(&curr_path_stack)
			}
			return nil
		}

		@static redundant : Perks
		check_for_redundancy :: proc(perk: PerkID) -> Maybe(PerkID) {
			append(&curr_path_stack, perk)
			if perk in redundant do return perk
			if perk in seen do return nil
			seen |= {perk}
			for req_perk in DB.perk_data[perk].prereqs {
				redundant_perk := check_for_redundancy(req_perk)
				if redundant_perk != nil do return redundant_perk
			}
			return nil
		}
		for perk in PerkID {
			pre_reqs := DB.perk_data[perk].prereqs
			{ // Check redundancy
				seen = {}
				for req_perk in pre_reqs {
					redundant = pre_reqs - {req_perk}
					redundant_perk, is_redundant := check_for_redundancy(perk).?
					if is_redundant do fmt.println("[WARN]:", perk, "has redundant", redundant_perk)
				}
			}
			{ // Check for cycles

				seen = {}
				repeated_perk, ok := check_for_cycles(perk, {}).?
				
				if ok {
					i:=0
					for ; i<len(curr_path_stack); i+=1 {
						if curr_path_stack[i] == repeated_perk do break
					}
					for idx in i..<len(curr_path_stack)-1 {
						path_perk := curr_path_stack[idx]
						fmt.print(path_perk, "-> ")
					}
					last_path_perk := curr_path_stack[len(curr_path_stack)-1]
					fmt.println(last_path_perk)
					return CycleInPreReqsError{repeated_perk}
				}
			}
		}
	}


	for perk, perk_data in DB.perk_data {
		DB.buyable_data[perk] = BuyableData {
			owned_blocks = make(Blocks, perk_data.blocks),
		}
		for &block in DB.buyable_data[perk].owned_blocks {
			block.owned_by = perk
		}
	}

	for skill_id, levels_data in DB.skill_id_data {
		for data, level_indexed_from_0 in levels_data {
			blocks := data.blocks
			level := level_indexed_from_0 + 1
			skill := LeveledSkill{skill_id, LEVEL(level)}
			DB.buyable_data[skill] = BuyableData {
				owned_blocks = make(Blocks, blocks),
			}
			for &block in DB.buyable_data[skill].owned_blocks {
				block.owned_by = skill
			}
		}
	}

	return nil
}

link_buyables :: proc(buyableA, buyableB: Buyable, strength: STRENGTH) {
	buyable_a_data := DB.buyable_data[buyableA]
	buyable_b_data := DB.buyable_data[buyableB]

	{ 	// Shuffle blocks to link random blocks
		rand.shuffle(buyable_a_data.owned_blocks)
		rand.shuffle(buyable_b_data.owned_blocks)
	}

	{ 	// Link A -> B
		len_shared_blocks_from_a_to_b := int(
			f32(len(buyable_b_data.owned_blocks)) * f32(strength) / 100,
		)
		for block_idx in 0 ..< len_shared_blocks_from_a_to_b {
			block_idx_mod := block_idx % len(buyable_a_data.owned_blocks)
			append(
				&buyable_a_data.owned_blocks[block_idx_mod].linked_to,
				&buyable_b_data.owned_blocks[block_idx],
			)
		}
	}
	{ 	// Link B -> A
		len_shared_blocks_from_b_to_a := int(
			f32(len(buyable_a_data.owned_blocks)) * f32(strength) / 100,
		)
		for block_idx in 0 ..< len_shared_blocks_from_b_to_a {
			block_idx_mod := block_idx % len(buyable_b_data.owned_blocks)
			append(
				&buyable_b_data.owned_blocks[block_idx_mod].linked_to,
				&buyable_a_data.owned_blocks[block_idx],
			)
		}
	}
}

