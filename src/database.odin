package main

import "core:mem"
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
	mem.Allocator_Error
}

Buyable :: union {
	PerkID,
	LeveledSkill,
}

Buyables :: []Buyable
DynBuyables :: [dynamic]Buyable

BuyableData :: struct {
	blocks_left_to_assign : BlocksSize,
	owned_blocks		: DynOwnedBlocks,
	bought_amount		: BlocksSize,
	bought				: bool,
	spent				: BlocksSize,
}



Database :: struct {
	skill_id_data	: map[SkillID][MAX_SKILL_LEVEL]BlocksSize,
	perk_data		: map[PerkID]PerkData,
	buyable_data 	: map[Buyable]BuyableData,

	// Constraint
	contains_constraint : map[Buyable]DynBuyables,
	drag_constraint		: map[SkillID]map[SkillID]LEVEL,
	share_constraints	: [dynamic]TShare,
	overlap_constraints : [dynamic]TOverlap,
}

DB : Database

Skill :: proc(skillID: SkillID, skill_data_arr: [MAX_SKILL_LEVEL]BlocksSize) {
	DB.skill_id_data[skillID] = skill_data_arr
}

DefineBlockProc :: proc(blockIdx: BlocksSize) -> BlocksSize

SkillByProc :: proc(skillID: SkillID, blockProc: DefineBlockProc){
	blocks_list : [MAX_SKILL_LEVEL]BlocksSize
	for idx in 1..=MAX_SKILL_LEVEL {
		blocks_list[idx-1] = blockProc(BlocksSize(idx))
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
	block_system_allocate() or_return
	create_buyables() or_return
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
        	owned_blocks = make(DynOwnedBlocks, 0),
			blocks_left_to_assign = perk_data.blocks, 
        }				
	}
	
	for skill_id, levels_data in DB.skill_id_data {
		for blocks_to_assign, level_indexed_from_0 in levels_data {
			level := level_indexed_from_0 + 1
			skill := LeveledSkill{skill_id, LEVEL(level)}
			DB.buyable_data[skill] = BuyableData {
				owned_blocks = make(DynOwnedBlocks, 0),
				blocks_left_to_assign = blocks_to_assign, 
			}			
		}
	}
	
	handle_constraints()

	for buyable, buyable_data in DB.buyable_data {
		block_system_assign(buyable, buyable_data.blocks_left_to_assign)
	}


	return nil
}

