#+feature dynamic-literals
package main

import "core:fmt"
import "core:math/rand"
MAX_SKILL_LEVEL :: 3

DatabaseError :: enum {
	None,
	LoadError,
}

SkillID :: enum u8 {
	Melee,
	Athletics,
}

LeveledSkill :: struct {
	id:    SkillID,
	level: u32,
}

SkillData :: struct {
	blocks: u32,
}

PerkID :: enum u8 {
	Trip,
	Aim,
	Sight,
}

PerkData :: struct {
	skills_reqs: [dynamic]LeveledSkill,
	prereqs:     bit_set[PerkID],
	blocks:      u32,
}


void :: struct {}

ShareError :: enum {
	None,
	MissingPerk,
	StrengthIsNotPercentage,
}

OverlapError :: enum {
	None, 
	CannotOverlapWithItself,
	StrengthIsNotPercentage,
}

BuyError :: enum {
	None,
	NotEnoughPoints,
	MissingRequiredSkills,
	MissingRequiredPerks,
	AlreadyHasSkill,
}

CycleInPreReqsError :: struct {
	cycle_in:      PerkID,
	repeated_perk: PerkID,
}


BuyableCreationError :: union {
	CycleInPreReqsError,
}

Error :: union #shared_nil {
	BuyableCreationError,
	BuyError,
	ShareError,
}

Block :: struct {
	bought:    bool,
	linked_to: [dynamic]^Block,
}

Buyable :: union {
	PerkID,
	LeveledSkill,
}


BuyableData :: struct {
	owned_blocks: []Block,
	bought:       bool,
}


player_has_perk :: proc(perk: PerkID) -> bool {
	return perk in player.owned_perks
}
player_has_skill :: proc(skill: LeveledSkill) -> bool {
	_, ok := player.owned_skills[skill]
	return ok
}

skill_data: map[LeveledSkill]SkillData
perk_data: map[PerkID]PerkData
buyable_data : map[Buyable]BuyableData
buyable_contains : map[Buyable][dynamic]Buyable
buyable_drags : map[SkillID]map[SkillID]u32

load_db :: proc() -> Error {
	skill_data[{.Melee, 1}] 	= { blocks = 1 }
	skill_data[{.Melee, 2}] 	= { blocks = 2 }
	skill_data[{.Melee, 3}] 	= { blocks = 3 }
	skill_data[{.Athletics, 1}] = { blocks = 1 }
	skill_data[{.Athletics, 2}] = { blocks = 2 }
	skill_data[{.Melee, 3}] 	= { blocks = 3 }

	perk_data[.Trip] = PerkData {
		blocks      = 4,
		prereqs     = {},
		skills_reqs = [dynamic]LeveledSkill{{.Melee, 1}},
	}
	perk_data[.Aim] = PerkData {
		blocks      = 8,
		prereqs     = {.Trip},
		skills_reqs = [dynamic]LeveledSkill{{.Melee, 1}},
	}
	perk_data[.Sight] = PerkData {
		blocks      = 2,
		skills_reqs = [dynamic]LeveledSkill{{.Melee, 1}},
	}
	// add_containee(Perk.Trip, Perk.Aim)
	// add_containee(Skill{name = .Melee, level = 1}, Perk.Trip)
	// add_drag(.Melee, .Athletics, 1)
	create_buyables() or_return
	add_share(.Trip, .Aim, 50) or_return
	return nil
}

create_buyables :: proc() -> BuyableCreationError {
	check_for_cycles :: proc(perk: PerkID, seen: bit_set[PerkID]) -> Maybe(PerkID) {
		if perk in seen do return perk
		new_seen := seen | {perk}
		for req_perk in perk_data[perk].prereqs {
			repeated_perk := check_for_cycles(req_perk, new_seen)
			if repeated_perk != nil do return repeated_perk
		}
		return nil
	}

	for perk in PerkID {
		// Verify that there are no cycles in reqs
		repeated_perk, ok := check_for_cycles(perk, {}).?
		if ok do return CycleInPreReqsError{perk, repeated_perk}
		perk_val := perk_data[perk]
		buyable_data[perk] = BuyableData {
			owned_blocks = make([]Block, perk_val.blocks),
		}
	}
	for skill in skill_data {
		skill_val := skill_data[skill]
		buyable_data[skill] = BuyableData {
			owned_blocks = make([]Block, skill_val.blocks),
		}}
	return nil
}


add_containee :: proc(buyableA, buyableB: Buyable) {
	_, ok := buyable_contains[buyableA]
	if !ok {
		buyable_contains[buyableA] = make([dynamic]Buyable, 0)
	}
	append(&buyable_contains[buyableA], buyableB)
}

add_drag :: proc(skillA, skillB: SkillID, drag: u32) {
	_, ok := buyable_drags[skillA]
	if !ok {
		buyable_drags[skillA] = {}
	}
	buyable_drags_from := &buyable_drags[skillA]
	_, ok = buyable_drags_from[skillB]
	if !ok {
		buyable_drags_from[skillB] = {}
	}
	buyable_drags_from[skillB] = drag
}

link_buyables :: proc(buyableA, buyableB: Buyable, strength: u8) {
	buyable_a_data := buyable_data[buyableA]
	buyable_b_data := buyable_data[buyableB]

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

add_share :: proc(buyableA: Buyable, buyableB: Buyable, strength: u8) -> ShareError {
	{ 	// Check if atleast one is Perk
		has_one_perk := false
		#partial switch _ in buyableA {
		case PerkID:
			has_one_perk = true
		}
		#partial switch _ in buyableB {
		case PerkID:
			has_one_perk = true
		}
		if !has_one_perk do return .MissingPerk
	}
	// have some sort of sampling
	if strength > 100 do return .StrengthIsNotPercentage

	link_buyables(buyableA, buyableB, strength)

	return .None
}

add_overlap :: proc(skillIDA, skillIDB: SkillID, strength: u8) -> OverlapError {
	if strength > 100 do return .StrengthIsNotPercentage
	if skillIDA == skillIDB do return .CannotOverlapWithItself

	for level in 0..<MAX_SKILL_LEVEL {
		skillA, skillB := LeveledSkill{skillIDA, u32(level)}, LeveledSkill{skillIDB, u32(level)}

		link_buyables(skillA, skillB, strength)
	}

	return .None	
}
