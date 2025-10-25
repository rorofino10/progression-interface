#+feature dynamic-literals
package main

import "core:reflect"
import "core:slice"
import "core:mem"
import "core:container/queue"
import "core:fmt"
import "core:math/rand"
LEVEL :: distinct u32
STRENGTH :: distinct u8

// CONSTANT
MAX_UNIT_LEVEL :: 100
MAIN_SKILLS_AMOUNT :: 6
MAX_FUDGE :: 10
// Artificial list size limits
// skill_slot_name := [MAIN_SKILLS_AMOUNT]string{"Primary 1", "Primary 2", "Major 1"}

Points :: BlocksSize

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
	slot		: u32,
}

Perks :: bit_set[PerkID]

PerkData :: struct {
	display			: string,	
	blocks			: BlocksSize,
	prereqs			: []PRE_REQ_ENTRY,
	buyable_state	: PerkBuyableState,
	skills_reqs		: []SKILL_REQ_ENTRY,
}

PerkBuyableState :: enum {
	UnmetRequirements,
	Buyable,
	Free,
	Owned,
}

Skill :: LeveledSkill

SKILL_REQ_OR_GROUP :: []LeveledSkill

SKILL_REQ_ENTRY :: union {
	LeveledSkill,
	SKILL_REQ_OR_GROUP
}

SkillReqsOr :: proc(entries: ..LeveledSkill) -> SKILL_REQ_OR_GROUP {
	return slice.clone(entries)
}

PRE_REQ_OR_GROUP :: Perks

PRE_REQ_ENTRY :: union {
	PerkID,
	PRE_REQ_OR_GROUP,
}

Or :: proc{PreReqsOr, SkillReqsOr}

PreReqsOr :: proc(entries: ..PerkID) -> (group: PRE_REQ_OR_GROUP) {
	for entry in entries do group += {entry}
	return
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
	UnmetRequirements,
	AlreadyHasBuyable,
}

RefundError :: enum {
	None,
	Unrefundable,
	BuyableNotOwned,
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

ReduceLevelErrorIrreducibleLevel :: struct{}
ReduceLevelErrorNotEnoughPoints :: struct {
	points_deficit: Points,
}
ReduceLevelErrorExceedsCap :: struct{
	skill_id: SkillID,
}

ReduceLevelError :: union {
	ReduceLevelErrorIrreducibleLevel,
	ReduceLevelErrorNotEnoughPoints,
	ReduceLevelErrorExceedsCap,
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
	blocks_left_to_assign	: BlocksSize,
	blocks_to_be_assigned 	: BlocksSize,
	assigned_blocks_indices	: [dynamic]BlockIndex,
	bought_blocks_amount	: BlocksSize,
}

PlayerLevelState :: struct{
	skill_points_on_level	: Points,
	main_skill_caps			: [MAIN_SKILLS_AMOUNT]LEVEL,
	extra_skill_cap			: LEVEL,
}

Database :: struct {
	skill_id_data	: map[SkillID]SkillData,
	perk_data		: map[PerkID]PerkData,
	buyable_data 	: map[Buyable]BuyableData,

	// Constraint
	contains_constraint : [dynamic]TContains,
	// drag_constraint		: [dynamic]TDrag,
	share_constraints	: [dynamic]TShare,
	// overlap_constraints : [dynamic]TOverlap,

	//
	share_graph : map[Buyable][dynamic]Buyable,

	// Unit
	unit_level				: LEVEL,
	unused_points			: Points,
	owned_main_skills		: [MAIN_SKILLS_AMOUNT]SkillID,
	owned_main_skills_amount: u32,
	owned_extra_skills		: [dynamic]SkillID,
	owned_perks				: Perks,
	owned_skills			: map[SkillID]LEVEL,
	unit_level_cap			: LEVEL,
	player_states			: [MAX_UNIT_LEVEL]PlayerLevelState,
}

DB : Database

Relationship :: proc(A, B: SKILL)
SKILL_TUPLE :: struct {
	a: SKILL,
	b: SKILL,
}
ListOf :: proc(relationship: Relationship, list: [dynamic]SKILL_TUPLE) {
	defer delete(list)
	for tuple in list do relationship(tuple.a, tuple.b)
}

DefineBlockProc :: proc(blockIdx: BlocksSize) -> BlocksSize
BuildSkills :: proc(blocks_proc: DefineBlockProc) {
	for skill_id in SkillID do _build_skill_lambda(skill_id, blocks_proc)
}

_build_skill_default :: proc(skillID: SkillID, skill_data_arr: [MAX_SKILL_LEVEL]BlocksSize) {
	if DB.owned_main_skills_amount < MAIN_SKILLS_AMOUNT {
		DB.owned_main_skills[DB.owned_main_skills_amount] = skillID
		DB.skill_id_data[skillID] = {blocks = skill_data_arr, type = .Main, slot = DB.owned_main_skills_amount}
		DB.owned_main_skills_amount += 1
	}
	else {
		DB.skill_id_data[skillID] = {blocks = skill_data_arr, type = .Extra, slot = u32(len(DB.owned_extra_skills))}
		append(&DB.owned_extra_skills, skillID)
	}
	DB.owned_skills[skillID] = 0
}

_build_skill_lambda :: proc(skillID: SkillID, blockProc: DefineBlockProc){
	blocks_list : [MAX_SKILL_LEVEL]BlocksSize
	for idx in 1..=MAX_SKILL_LEVEL {
		blocks_list[idx-1] = blockProc(BlocksSize(idx))
	}
	_build_skill_default(skillID, blocks_list)
}
// Skill :: proc{_build_skill_default, _build_skill_lambda}

_perk_without_share :: proc(display : string = "", id: PerkID, skill_reqs: [dynamic]SKILL_REQ_ENTRY, pre_reqs: [dynamic]PRE_REQ_ENTRY, blocks: BlocksSize) {
	assert(id not_in DB.perk_data, fmt.tprint("Already built Perk:", id))
	enum_name, ok := reflect.enum_name_from_value(id)
	assert(ok, "Could not get name from PerkID")
	to_display := display == "" ? enum_name : display 
	defer {
		delete(skill_reqs)
		delete(pre_reqs)
	}
	pre_reqs_copy := slice.clone(pre_reqs[:])
	skill_reqs_copy := slice.clone(skill_reqs[:])
	perk_data := PerkData{ display = to_display, blocks = blocks, prereqs = pre_reqs_copy, skills_reqs = skill_reqs_copy }
	DB.perk_data[id] = perk_data
}

Perk :: proc(id: PerkID, skill_reqs: [dynamic]SKILL_REQ_ENTRY = nil, pre_reqs: [dynamic]PRE_REQ_ENTRY = nil, blocks: BlocksSize, shares: [dynamic]TPartialShare = nil, display : string = "") {
	defer delete(shares)

	_perk_without_share(display, id, skill_reqs, pre_reqs, blocks)
	for partial_share in shares {
		switch buyable in partial_share.buyable_to_share_with {
			case LeveledSkill:
				Share(id, buyable.id, buyable.level, partial_share.strength)
			case PerkID:
				Share(id, buyable, partial_share.strength)
		}
	}
}

BuildPlayer :: proc(states: [dynamic]PlayerLevelState) {
	defer delete(states)

	assert(len(states) <= MAX_UNIT_LEVEL)

	DB.unit_level = 1
	DB.unused_points = states[DB.unit_level].skill_points_on_level
	DB.unit_level_cap = LEVEL(len(states))

	for state, idx in states do DB.player_states[idx] = state
}

init_db :: proc() -> Error{
	load_db()
	assert(DB.owned_main_skills_amount == MAIN_SKILLS_AMOUNT)
	_assert_all_perks_all_built()
	block_system_allocate()
	init_query_system_alloc() or_return
	create_buyables()
	verify_constraints()
	return nil
}

_flattened_pre_reqs :: proc(perk: PerkID) -> (flattened_pre_reqs: Perks) {
	pre_reqs := DB.perk_data[perk].prereqs
	for req in pre_reqs {
		switch r in req {
			case PerkID:
				flattened_pre_reqs |= {r}
			case Perks:
				flattened_pre_reqs |= r
		}
	}
	return
}

create_buyables :: proc() {
	{ // Check for cycles in pre_reqs
		

		check_for_cycles :: proc(perk: PerkID, curr_path: Perks, seen: Perks, curr_path_stack: ^[dynamic]PerkID) -> Maybe(PerkID) {
			append(curr_path_stack, perk)
			if perk in curr_path do return perk
			if perk in seen do return nil
			new_seen := seen | {perk}
			new_curr_path := curr_path | {perk}
			for req_perk in _flattened_pre_reqs(perk) {
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
			for req_perk in _flattened_pre_reqs(perk) {
				redundant_perk := check_for_redundancy(req_perk, new_seen, redundant)
				if redundant_perk != nil do return redundant_perk
			}
			return nil
		}
		for perk in PerkID {
			pre_reqs := _flattened_pre_reqs(perk)
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

				repeated_perk, has_cycle := check_for_cycles(perk, {}, {}, &curr_path_stack).?
				
				if has_cycle {
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
					panic(fmt.tprint("Cycle in PreReqs", repeated_perk))
				}
			}
		}
	}
	for perk, perk_data in DB.perk_data {
   		DB.buyable_data[perk] = BuyableData {
			blocks_left_to_assign = perk_data.blocks,
			blocks_to_be_assigned = perk_data.blocks
        }				
	}
	
	for skill_id, skill_data in DB.skill_id_data {
		for blocks_to_assign, level_indexed_from_0 in skill_data.blocks {
			level := level_indexed_from_0 + 1
			skill := LeveledSkill{skill_id, LEVEL(level)}
			DB.buyable_data[skill] = BuyableData {
				blocks_left_to_assign = blocks_to_assign, 
				blocks_to_be_assigned = blocks_to_assign
			}			
		}
	}
	
	

	handle_constraints()

	for buyable, &buyable_data in DB.buyable_data {
		block_system_assign_leftover(buyable)
	}

	recalc_buyable_states()
}

_assert_all_perks_all_built :: proc() {
	for perk in PerkID do assert(perk in DB.perk_data, fmt.tprint(perk, "not built."))
}
