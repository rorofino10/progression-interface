package main

import "core:strconv"
import "core:strings"
import "core:os"
import "core:bufio"
import "core:fmt"
import "core:reflect"

Action :: enum {
    NotRecognized,
    Raise,
    Buy,
    Refund,
    Reduce,
    Blocks,
    LevelUp,
    SetPoints,
}

print_buyable_blocks :: proc(buyable: Buyable) {
    buyable_data := DB.buyable_data[buyable]
    owned_block_amount := BlocksSize(len(buyable_data.owned_blocks))
    fmt.print(f32(buyable_data.owned_amount)/f32(owned_block_amount)*100, "%", " ", sep="")
    fmt.print(buyable_data.owned_amount, "/", owned_block_amount, " ", sep="")
    switch {
        // Already Bought
        case buyable_data.is_owned:
            for _ in 0..<owned_block_amount do fmt.print("\x1b[44m \x1b[0m")
        // Free
        case owned_block_amount == buyable_data.owned_amount:
            fmt.print("FREE! ")
            for _ in 0..<owned_block_amount do fmt.print("\x1b[43m \x1b[0m")
        case:
            for block in buyable_data.owned_blocks {
                if block.bought do fmt.print("\x1b[42m \x1b[0m")
                else do fmt.print("\x1b[31m█\x1b[0m")
            }
    }

    fmt.print('\n')
}

print_skill_progress :: proc(skillID: SkillID, level_cap: LEVEL) {
    skill_id_data := DB.skill_id_data[skillID]
    skill_level := DB.owned_skills[skillID]
    next_skill := LeveledSkill{skillID, skill_level+1}

    buyable_data := DB.buyable_data[next_skill]
    owned_block_amount := BlocksSize(len(buyable_data.owned_blocks))
    
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
    for level in skill_level+1..=level_cap do fmt.print(" ")
    fmt.print("\x1b[0m\n")
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
            slot_cap := DB.skill_rank_cap[DB.unit_level-1][slot]

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
            fmt.print(skill_id, level)
            fmt.print("\x1b[0m\t\t")
            // fmt.print("", skill_slot_name[slot], ":" ,"CAP:", slot_cap, skill_id, level, ": ")
            // fmt.print(skill_id_data.raisable_state)
            print_skill_progress(skill_id, slot_cap)
            // print_buyable_blocks(LeveledSkill{skill_id, level+1})
        }

        // Extra Skills
        extra_slot_cap := DB.skill_rank_cap[DB.unit_level-1][MAIN_SKILLS_AMOUNT]
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
            fmt.print(skill_id, level)
            fmt.print("\x1b[0m\n")
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
                }
                fmt.print(perk)
                fmt.print("\x1b[0m ")
                
                buyable_data := DB.buyable_data[perk]
                owned_block_amount := BlocksSize(len(buyable_data.owned_blocks))
                fmt.printfln("%.0f%%",f32(buyable_data.owned_amount)/f32(owned_block_amount)*100)
        }
    }
}

print_state :: proc(){
	print_player_state()
    fmt.println("Unused points:", DB.unused_points)
    fmt.println("Level:", DB.unit_level)
}

parse_action :: proc(action_str: string) -> Action {
    str := strings.to_pascal_case(action_str, context.temp_allocator)
    action, r_err := reflect.enum_from_name(Action, str)
    return action
}

parse_perk :: proc(perk_id_str: string) -> PerkID {
    str := strings.to_pascal_case(perk_id_str, context.temp_allocator)
    perk_id, r_err := reflect.enum_from_name(PerkID, str)
    return perk_id
}

parse_skill :: proc(skill_id_str: string) -> SkillID {
    str := strings.to_pascal_case(skill_id_str, context.temp_allocator)
    skill_id, r_err := reflect.enum_from_name(SkillID, str)
    return skill_id
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
        if !bufio.scanner_scan(&scanner) {
            break
        }
        line := bufio.scanner_text(&scanner)
        if line == "q" {break}
        words := strings.split(line, " ", context.temp_allocator)

        action := parse_action(words[0])
        args := words[1:]
        // Clear Screen
        fmt.print("\x1b[2J\x1b[H")

        switch action {
            case .Refund:
                buyable := parse_perk(args[0])
                refunded, err := refund_perk(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Refunded:", refunded)
            case .Reduce:
                buyable := parse_skill(args[0])
                refunded, err := reduce_skill(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Refunded:", refunded)
            case .Blocks:
                if len(args) == 0 do print_blocks_state()
                else {
                    for arg in args {
                        perk := parse_perk(arg)
                        print_buyable_blocks(perk)
                    }
                }
            case .Raise:
                buyable := parse_skill(args[0])
                spent, err := raise_skill(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Cost:", spent)
            case .Buy:
                buyable := parse_perk(args[0])
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
