#+feature dynamic-literals
package main

import "core:slice"
import "core:mem"
import "core:container/queue"
import "core:fmt"
import "core:math/rand"
LEVEL :: distinct u32
STRENGTH :: distinct u8

// CONSTANT
MAX_SKILL_LEVEL :: 10
MAX_UNIT_LEVEL :: 30
MAIN_SKILLS_AMOUNT :: 6
// Artificial list size limits
MAX_SKILL_REQS :: 10

skill_slot_name := [MAIN_SKILLS_AMOUNT]string{"Primary 1", "Primary 2", "Major 1", "Major 2", "Major 3", "Major 4"}
// skill_slot_name := [MAIN_SKILLS_AMOUNT]string{"Primary 1", "Primary 2", "Major 1"}

DatabaseError :: enum {
	None,
	LoadError,
	MissingMainSkills,
}

LeveledSkill :: struct {
	id:    SkillID,
	level: LEVEL,
}

SkillType :: enum {
	Main,
	Extra
}

SkillRaisableState :: enum {
	NotEnoughPoints,
	Raisable,
	Capped,
	Free,
}

SkillData :: struct {
	blocks	: [MAX_SKILL_LEVEL]BlocksSize,
	raisable_state : SkillRaisableState,
	type	: SkillType,
	idx		: u32,
}

Perks :: bit_set[PerkID]

PerkBuyableState :: enum {
	UnmetRequirements,
	Buyable,
	Owned,
}

PerkData :: struct {
	blocks:      BlocksSize,
	prereqs:     Perks,
	buyable_state: PerkBuyableState,
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
	CapReached,
	NotEnoughPoints,
	MissingRequiredSkills,
	MissingRequiredPerks,
	MissingRequiredUnitLevel,
	AlreadyHasSkill,
}

RefundError :: enum {
	None,
	BuyableNotOwned,
	RequiredByAnotherBuyable,
}

ReduceError :: enum {
	None,
	CannotReduceSkill,
	RequiredByAnotherBuyable,
}

CycleInPreReqsError :: struct {
	repeated_perk:      PerkID,
}

ShareFudgeError :: struct {
	share: TShare
}

OverlapFudgeError :: struct {
	overlap: TOverlap,
	level: LEVEL,
}


BuyableCreationError :: union {
	CycleInPreReqsError,
	ShareFudgeError,
	OverlapFudgeError,
}

LevelUpError :: enum {
	None,
	MAX_LEVEL_REACHED,
}

Error :: union #shared_nil {
	DatabaseError,
	BuyableCreationError,
	BuyError,
	ConstraintError,
	LevelUpError,
	mem.Allocator_Error,
}

Buyable :: union {
	PerkID,
	LeveledSkill,
}

Buyables :: []Buyable
DynBuyables :: [dynamic]Buyable

BuyableData :: struct {
	assigned_blocks_amount 	: BlocksSize,
	owned_amount			: BlocksSize,
	is_owned				: bool,
	is_upgradeable			: bool,
	spent					: BlocksSize,
}



Database :: struct {
	skill_id_data	: map[SkillID]SkillData,
	perk_data		: map[PerkID]PerkData,
	buyable_data 	: map[Buyable]BuyableData,

	// Constraint
	contains_constraint : map[Buyable]DynBuyables,
	drag_constraint		: map[SkillID]map[SkillID]LEVEL,
	share_constraints	: [dynamic]TShare,
	overlap_constraints : [dynamic]TOverlap,

	// Unit
	unit_level				: LEVEL,
	unused_points			: u32,
	owned_main_skills		: [MAIN_SKILLS_AMOUNT]SkillID,
	owned_main_skills_amount: u32,
	owned_extra_skills		: [dynamic]SkillID,
	owned_perks				: Perks,
	owned_skills			: map[SkillID]LEVEL,
	points_gain				: [MAX_UNIT_LEVEL]u32,
	unit_level_cap			: LEVEL,
	skill_rank_cap			: [MAX_UNIT_LEVEL][MAIN_SKILLS_AMOUNT+1]LEVEL
}

DB : Database

BuildMainSkillStartingLevel :: proc(skillID: SkillID, starting_level: LEVEL, skill_data_arr: [MAX_SKILL_LEVEL]BlocksSize) {
	assert(DB.owned_main_skills_amount < MAIN_SKILLS_AMOUNT)
	DB.owned_main_skills[DB.owned_main_skills_amount] = skillID
	DB.skill_id_data[skillID] = {blocks = skill_data_arr, type = .Main, idx = DB.owned_main_skills_amount}
	DB.owned_skills[skillID] = starting_level
	DB.owned_main_skills_amount += 1
}

BuildMainSkillDefault :: proc(skillID: SkillID, skill_data_arr: [MAX_SKILL_LEVEL]BlocksSize) {
	assert(DB.owned_main_skills_amount < MAIN_SKILLS_AMOUNT)
	DB.owned_main_skills[DB.owned_main_skills_amount] = skillID
	DB.skill_id_data[skillID] = {blocks = skill_data_arr, type = .Main, idx = DB.owned_main_skills_amount}
	DB.owned_skills[skillID] = 0
	DB.owned_main_skills_amount += 1
}

BuildMainSkill :: proc{BuildMainSkillDefault, BuildMainSkillStartingLevel}

BuildExtraSkill :: proc(skillID: SkillID, skill_data_arr: [MAX_SKILL_LEVEL]BlocksSize) {
	DB.skill_id_data[skillID] = {blocks = skill_data_arr, type = .Extra, idx = u32(len(DB.owned_extra_skills))}
	append(&DB.owned_extra_skills, skillID)
	DB.owned_skills[skillID] = 0
}

DefineBlockProc :: proc(blockIdx: BlocksSize) -> BlocksSize

BuildMainSkillLambda :: proc(skillID: SkillID, blockProc: DefineBlockProc){
	blocks_list : [MAX_SKILL_LEVEL]BlocksSize
	for idx in 1..=MAX_SKILL_LEVEL {
		blocks_list[idx-1] = blockProc(BlocksSize(idx))
	}
	BuildMainSkill(skillID, blocks_list)
}

BuildExtraSkillLambda :: proc(skillID: SkillID, blockProc: DefineBlockProc){
	blocks_list : [MAX_SKILL_LEVEL]BlocksSize
	for idx in 1..=MAX_SKILL_LEVEL {
		blocks_list[idx-1] = blockProc(BlocksSize(idx))
	}
	BuildExtraSkill(skillID, blocks_list)
}

BuildPerk :: proc(perkID: PerkID, blocks: BlocksSize, pre_reqs: Perks, skill_reqs: [dynamic]LeveledSkill) {
	defer delete(skill_reqs)

    assert(len(skill_reqs) <= MAX_SKILL_REQS)
	perk_data := PerkData{ blocks = blocks, prereqs = pre_reqs }
	for skill_req, idx in skill_reqs do perk_data.skills_reqs[idx] = skill_req
	DB.perk_data[perkID] = perk_data
}

level_up :: proc() -> LevelUpError {
	if DB.unit_level >= DB.unit_level_cap do return .MAX_LEVEL_REACHED
	DB.unit_level += 1
	DB.unused_points += DB.points_gain[DB.unit_level-1]
	
	recalc_buyable_states()
	return nil
}

BuildPlayer :: proc(points_gain: [dynamic]u32, rank_caps: [dynamic][MAIN_SKILLS_AMOUNT+1]LEVEL) {
	defer delete(points_gain)
	defer delete(rank_caps)

	assert(len(points_gain) <= MAX_UNIT_LEVEL)
	assert(len(points_gain) == len(rank_caps))

	DB.unit_level = 1
	DB.unit_level_cap = LEVEL(len(points_gain))

	for gain, idx in points_gain do DB.points_gain[idx] = gain
	for caps, level in rank_caps do DB.skill_rank_cap[level] = caps

	DB.unused_points = points_gain[0]
}

init_db :: proc() -> Error{
	load_db()
	if DB.owned_main_skills_amount != MAIN_SKILLS_AMOUNT do return DatabaseError.MissingMainSkills
	assert(DB.owned_main_skills_amount == MAIN_SKILLS_AMOUNT)
	check_constraints() or_return
	block_system_allocate() or_return
	init_query_system_alloc() or_return
	create_buyables() or_return
	return nil
}

create_buyables :: proc() -> BuyableCreationError {
	{ // Check for cycles in pre_reqs
		

		check_for_cycles :: proc(perk: PerkID, curr_path: Perks, seen: Perks, curr_path_stack: ^[dynamic]PerkID) -> Maybe(PerkID) {
			append(curr_path_stack, perk)
			if perk in curr_path do return perk
			if perk in seen do return nil
			new_seen := seen | {perk}
			new_curr_path := curr_path | {perk}
			for req_perk in DB.perk_data[perk].prereqs {
				repeated_perk := check_for_cycles(req_perk, new_curr_path, new_seen, curr_path_stack)
				if repeated_perk != nil do return repeated_perk
				pop(curr_path_stack)
			}
			return nil
		}

		check_for_redundancy :: proc(perk: PerkID, seen: Perks, redundant: Perks) -> Maybe(PerkID) {
			if perk in redundant do return perk
			if perk in seen do return nil
			new_seen := seen | {perk}
			for req_perk in DB.perk_data[perk].prereqs {
				redundant_perk := check_for_redundancy(req_perk, new_seen, redundant)
				if redundant_perk != nil do return redundant_perk
			}
			return nil
		}
		for perk in PerkID {
			pre_reqs := DB.perk_data[perk].prereqs
			{ // Check redundancy

				for req_perk in pre_reqs {
					curr_path_stack : [dynamic]PerkID
					defer delete(curr_path_stack)
					redundant := pre_reqs - {req_perk}
					redundant_perk, is_redundant := check_for_redundancy(req_perk, {perk}, redundant).?
					if is_redundant do fmt.println("[WARN]:", perk, "has redundant", redundant_perk)
				}
			}
			{ // Check for cycles

				curr_path_stack : [dynamic]PerkID
				defer delete(curr_path_stack)

				repeated_perk, ok := check_for_cycles(perk, {}, {}, &curr_path_stack).?
				
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
			assigned_blocks_amount = perk_data.blocks, 
        }				
	}
	
	for skill_id, skill_data in DB.skill_id_data {
		for blocks_to_assign, level_indexed_from_0 in skill_data.blocks {
			level := level_indexed_from_0 + 1
			skill := LeveledSkill{skill_id, LEVEL(level)}
			DB.buyable_data[skill] = BuyableData {
				assigned_blocks_amount = blocks_to_assign, 
			}			
		}
	}
	
	
	for buyable, buyable_data in DB.buyable_data {
		block_system_assign(buyable, buyable_data.assigned_blocks_amount)
	}
	
	handle_constraints() or_return

	// for buyable, &buyable_data in DB.buyable_data {
	// 	buyable_data.owned_blocks = slice.clone(query_all_blocks_from_buyable(buyable))
	// 	free_all(query_system_alloc)
	// }
	
	recalc_buyable_states()
	return nil
}

