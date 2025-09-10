package main

TShare :: struct {
	buyableA: Buyable,
	buyableB: Buyable,
	strength: STRENGTH,
}

TOverlap :: struct {
	skillA: SkillID,
	skillB: SkillID,
	strength: STRENGTH,
}

Contains :: proc(buyableA, buyableB: Buyable) {
	_, ok := DB.contains_constraint[buyableA]
	if !ok {
		DB.contains_constraint[buyableA] = make(DynBuyables, 0)
	}
	append(&DB.contains_constraint[buyableA], buyableB)
}

Drags :: proc(skillA, skillB: SkillID, drag: LEVEL) {
	_, ok := DB.drag_constraint[skillA]
	if !ok {
		DB.drag_constraint[skillA] = {}
	}
	drag_constraint_from := &DB.drag_constraint[skillA]
	_, ok = drag_constraint_from[skillB]
	if !ok {
		drag_constraint_from[skillB] = {}
	}
	drag_constraint_from[skillB] = drag
}

Share :: proc(buyableA, buyableB: Buyable, strength: STRENGTH) {
    append(&DB.share_constraints, TShare{buyableA, buyableB, strength})
}

Overlap :: proc(skillA, skillB : SkillID, strength: STRENGTH) {
    append(&DB.overlap_constraints, TOverlap{skillA, skillB, strength})
}

handle_share :: proc(share: TShare) {
	link_buyables(share.buyableA, share.buyableB, share.strength)
}

handle_overlap :: proc(overlap: TOverlap) {
	for level in 1..=MAX_SKILL_LEVEL {
		skillA, skillB := LeveledSkill{overlap.skillA, LEVEL(level)}, LeveledSkill{overlap.skillB, LEVEL(level)}

		link_buyables(skillA, skillB, overlap.strength)
	}
}

check_constraints :: proc() -> Error {
	{ // Check Share Constraints
		for share in DB.share_constraints {
			has_one_perk := false
			#partial switch _ in share.buyableA {
			case PerkID:
				has_one_perk = true
			}
			#partial switch _ in share.buyableB {
			case PerkID:
				has_one_perk = true
			}
			if !has_one_perk do return .ShareMissingPerk
			if share.strength > 100 do return .StrengthIsNotPercentage
		}
	}
	{ // Check Overlap Constraints
		for overlap in DB.overlap_constraints {
			if overlap.strength > 100 do return .StrengthIsNotPercentage
			if overlap.skillA == overlap.skillB do return .CannotOverlapWithItself
		}
	}
	return nil
}

handle_constraints :: proc() {
    for share in DB.share_constraints {
        handle_share(share)
    }
    for overlap in DB.overlap_constraints {
        handle_overlap(overlap)
    }
}
