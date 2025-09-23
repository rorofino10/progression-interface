package main

import "core:strconv"
import "core:strings"
import "core:os"
import "core:bufio"
import "core:fmt"
import "core:reflect"

SKILL_NAME_LENGTH :: 13

Action :: enum {
    NotRecognized,
    Raise,
    RaiseTo,
    Buy,
    Refund,
    ReduceTo,
    Reduce,
    Blocks,
    LevelUp,
    SetPoints,
}

print_buyable_blocks :: proc(buyable: Buyable) {
    buyable_data := DB.buyable_data[buyable]
    owned_blocks := query_all_blocks_from_buyable(buyable)
    fmt.println(owned_blocks)
    defer free_all(query_system_alloc)
    owned_block_amount := buyable_data.assigned_blocks_amount
    fmt.print(f32(buyable_data.bought_blocks_amount)/f32(owned_block_amount)*100, "%", " ", sep="")
    fmt.print(buyable_data.bought_blocks_amount, "/", owned_block_amount, " ", sep="")
    switch {
        // Already Bought
        case buyable_data.is_owned:
            for block in owned_blocks do fmt.print("\x1b[44m \x1b[0m")
        // Free
        case owned_block_amount == buyable_data.bought_blocks_amount:
            for block in owned_blocks do fmt.print("\x1b[43m \x1b[0m")
        case:
            for block in owned_blocks {
                if block.bought do fmt.printf("\x1b[42m%d\x1b[0m", len(block.owned_by))
                else do fmt.printf("\x1b[41m%d\x1b[0m", len(block.owned_by))
            }
    }

    fmt.print('\n')
}

print_skill_progress :: proc(skillID: SkillID, level_cap: LEVEL) {
    skill_id_data := DB.skill_id_data[skillID]
    skill_level := DB.owned_skills[skillID]
    next_skill := LeveledSkill{skillID, skill_level+1}

    buyable_data := DB.buyable_data[next_skill]
    owned_block_amount := buyable_data.assigned_blocks_amount
    
    switch skill_id_data.raisable_state {
        case .Free:
            fmt.print("\x1b[43m")
        case .Raisable:
            fmt.print("\x1b[42m")
        case .NotEnoughPoints:
            fmt.print("\x1b[41m")
        case .Capped:
            fmt.print("\x1b[44m")
    }
    for level in 1..=skill_level do fmt.print(" ")
    fmt.print("\x1b[100m")
    for level in skill_level+1..=min(level_cap, MAX_SKILL_LEVEL) do fmt.print(" ")
    fmt.print("\x1b[45m")
    for level in min(level_cap, MAX_SKILL_LEVEL)+1..=MAX_SKILL_LEVEL do fmt.print(" ")
    fmt.print("\x1b[0m")

    fmt.print(f32(buyable_data.bought_blocks_amount)/f32(owned_block_amount)*100, "%", " ", sep="")
    fmt.print(buyable_data.bought_blocks_amount, "/", owned_block_amount, " \n", sep="")
}

print_blocks_state :: proc() {
    fmt.println("Blocks: ")
    for block in block_system.blocks {
        // fmt.printf("\x1b[41;97m%d\x1b[0m", len(block.owned_by))
        switch block.bought {
            
            case true:
                fmt.printf("\x1b[42m%d\x1b[0m", len(block.owned_by))
            case false:
                fmt.printf("\x1b[41m%d\x1b[0m", len(block.owned_by))
        }
    }
    fmt.print('\n')
}

print_player_state :: proc() {


    { // Print Owned Skills
        fmt.println("Skills:")
        // Main Skills
        for skill_id, slot in DB.owned_main_skills {
            skill_id_data := DB.skill_id_data[skill_id]
            level := DB.owned_skills[skill_id]
            slot_cap := DB.player_states[DB.unit_level].main_skill_caps[slot]
            
            fmt.print("[",skill_slot_name[slot],"]\t", sep="")
            switch skill_id_data.raisable_state {
                case .Free:
                    fmt.print("\x1b[43m")
                case .Raisable:
                    fmt.print("\x1b[42m")
                case .NotEnoughPoints:
                    fmt.print("\x1b[41m")
                case .Capped:
                    fmt.print("\x1b[44m")
            }
            skill_id_str, _ := reflect.enum_name_from_value(skill_id)
            fmt.print(skill_id_str)
            for pad in len(skill_id_str)..<SKILL_NAME_LENGTH+1 do fmt.print(' ')
            fmt.print(level)
            fmt.print(" \x1b[0m ")
            // fmt.print("", skill_slot_name[slot], ":" ,"CAP:", slot_cap, skill_id, level, ": ")
            // fmt.print(skill_id_data.raisable_state)
            print_skill_progress(skill_id, slot_cap)
            // print_buyable_blocks(LeveledSkill{skill_id, level+1})
        }

        // Extra Skills
        extra_slot_cap := DB.player_states[DB.unit_level].extra_skill_cap
        for skill_id in DB.owned_extra_skills {
            skill_id_data := DB.skill_id_data[skill_id]
            level := DB.owned_skills[skill_id]

            fmt.print("[EXTRA]\t\t")
            switch skill_id_data.raisable_state {
                case .Free:
                    fmt.print("\x1b[43m")
                case .Raisable:
                    fmt.print("\x1b[42m")
                case .NotEnoughPoints:
                    fmt.print("\x1b[41m")
                case .Capped:
                    fmt.print("\x1b[44m")
            }
            skill_id_str, _ := reflect.enum_name_from_value(skill_id)
            fmt.print(skill_id_str)
            for pad in len(skill_id_str)..<SKILL_NAME_LENGTH+1 do fmt.print(' ')
            fmt.print(level)
            fmt.print(" \x1b[0m ")
            print_skill_progress(skill_id, extra_slot_cap)

        }
    }

    { // Print Perks
        fmt.println("Perks:")
        for perk, perk_val in DB.perk_data {
                switch perk_val.buyable_state {
                    case .Buyable:
                        fmt.print("\x1b[42m")
                    case .UnmetRequirements:
                        fmt.print("\x1b[41m")
                    case .Owned:
                        fmt.print("\x1b[44m")
                    case .Free:
                        fmt.print("\x1b[43m")
                }
                fmt.print(perk)
                fmt.print("\x1b[0m ")
                
                buyable_data := DB.buyable_data[perk]
                owned_block_amount := buyable_data.assigned_blocks_amount
                fmt.printfln("%.0f%%",f32(buyable_data.bought_blocks_amount)/f32(owned_block_amount)*100)
        }
    }
}

print_state :: proc(){
	print_player_state()
    fmt.println("Unused points:", DB.unused_points)
    fmt.println("Level:", DB.unit_level)
}

parse_action :: proc(action_str: string) -> (Action, bool) {
    str := strings.to_pascal_case(action_str, context.temp_allocator)
    action, ok := reflect.enum_from_name(Action, str)
    if !ok do return .NotRecognized, ok
    return action, ok
}

parse_perk :: proc(perk_id_str: string) -> (PerkID, bool) {
    str := strings.to_pascal_case(perk_id_str, context.temp_allocator)
    perk_id, ok := reflect.enum_from_name(PerkID, str)
    if !ok do return .Aim, ok
    return perk_id, ok
}

parse_skill_id :: proc(skill_id_str: string) -> (SkillID, bool) {
    str := strings.to_pascal_case(skill_id_str, context.temp_allocator)
    skill_id, ok := reflect.enum_from_name(SkillID, str)
    if !ok do return .Melee, ok
    return skill_id, ok
}

parse_skill :: proc(skill_id_str, skill_level_str: string, ) -> (LeveledSkill, bool) {
    str := strings.to_pascal_case(skill_id_str, context.temp_allocator)
    skill_id, id_ok := reflect.enum_from_name(SkillID, str)
    if !id_ok do return {}, id_ok
    level, level_ok := strconv.parse_uint(skill_level_str)
    if !level_ok do return {}, level_ok
    return LeveledSkill{skill_id, LEVEL(level)}, true
}

run_cli :: proc() {
    
    // Clear Screen
    // fmt.print("\x1b[2J\x1b[H")
    print_state()

    scanner: bufio.Scanner
    stdin := os.stream_from_handle(os.stdin,)
    bufio.scanner_init(&scanner, stdin, context.allocator)

    for {
        
        fmt.printf("> ")
        if !bufio.scanner_scan(&scanner) do break
        line := bufio.scanner_text(&scanner)
        if line == "q" do break
        words := strings.split(line, " ", context.temp_allocator)

        action, ok := parse_action(words[0])
        if !ok do action = .NotRecognized
        args := words[1:]
        // Clear Screen
        fmt.print("\x1b[2J\x1b[H")

        switch action {
            case .Refund:
                if len(args)!=1 {fmt.println("Invalid Arguments");break}
                buyable, ok := parse_perk(args[0])
                if !ok {fmt.println("Invalid Argument");break}

                refunded, err := refund_perk(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Refunded:", refunded)
            case .Reduce:
                if len(args)!=1 {fmt.println("Invalid Arguments");break}
                buyable, ok := parse_skill_id(args[0])
                if !ok {fmt.println("Invalid Argument");break}

                refunded, err := reduce_skill(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Refunded:", refunded)
            case .ReduceTo:
                if len(args)!=2 {fmt.println("Invalid Arguments");break}
                buyable, ok := parse_skill(args[0], args[1])
                if !ok {fmt.println("Could not parse Skill");break}

                refunded, err := reduce_to_skill(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Refunded:", refunded)
            case .Blocks:
                if len(args) == 0 do print_blocks_state()
                else if args[0] == "all" {
                    for buyable, _ in DB.buyable_data {fmt.print(buyable,"");print_buyable_blocks(buyable)}
                }
                else {
                    for arg in args {
                        switch strings.to_lower(arg, context.temp_allocator) {
                            case "perks": for perk in DB.perk_data {fmt.print(perk,);print_buyable_blocks(perk)}; continue
                            case "skills": for skill, level in DB.owned_skills {if level != 0 {fmt.print(skill,level,"");print_buyable_blocks(LeveledSkill{skill, level})}}; continue
                        }
                        perk, ok := parse_perk(arg)
                        if ok {print_buyable_blocks(perk);continue}
                        skill_id, s_ok := parse_skill_id(arg)
                        skill := LeveledSkill{skill_id, DB.owned_skills[skill_id]+1}
                        if s_ok {print_buyable_blocks(skill);continue}
                    }
                }
            case .Raise:
                if len(args)!=1 {fmt.println("Invalid Arguments");break}
                buyable, ok := parse_skill_id(args[0])
                if !ok {fmt.println("Invalid Argument");break}

                spent, err := raise_skill(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Cost:", spent)
            case .RaiseTo:
                if len(args)!=2 {fmt.println("Invalid Arguments");break}
                buyable, ok := parse_skill(args[0], args[1])
                if !ok {fmt.println("Could not parse Skill");break}

                spent, err := raise_to_skill(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Cost:", spent)
            case .Buy:
                if len(args)!=1 {fmt.println("Invalid Arguments");break}
                buyable, ok := parse_perk(args[0])
                if !ok {fmt.println("Invalid Argument");break}

                spent, err := buy_perk(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Cost:", spent)
            case .LevelUp:
                err := level_up()
                if err != nil do fmt.println(err)
            case .SetPoints:
                points, ok := strconv.parse_int(args[0])
                if !ok do fmt.println("Error parsing Int")
                else do DB.unused_points = u32(points)
            case .NotRecognized:
                fmt.println("Action Not Recognized")
        }

        print_state()
        free_all(context.temp_allocator)
    }
    
    if err := bufio.scanner_error(&scanner); err != nil {
        fmt.eprintln("error scanning input: %v", err)
    }

}
