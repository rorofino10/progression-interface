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
    LevelUp,
}

print_buyable_blocks :: proc(buyable: Buyable) {
    buyable_data := DB.buyable_data[buyable]
    owned_block_amount := BlocksSize(len(buyable_data.owned_blocks))
    fmt.print(buyable_data.owned_amount, "/", owned_block_amount, "")
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
                if owned_block_is_bought(block) do fmt.print("\x1b[42m \x1b[0m")
                else do fmt.print("\x1b[31m█\x1b[0m")
            }
    }

    fmt.print('\n')
}

print_player_state :: proc() {


    { // Print Owned Skills
        // fmt.println("Owned Skills:")

        // for skill_id, level in DB.owned_skills {
        //     fmt.print(" ",skill_id, level, ": ")
        //     print_buyable_blocks(LeveledSkill{skill_id, level})
        // } 
        fmt.println("Main Skills:")
        for skill_id, slot in DB.owned_main_skills {
            level := DB.owned_skills[skill_id]
            slot_cap := DB.skill_rank_cap[DB.unit_level-1][slot]
            fmt.print(" SLOT:", slot,"CAP:", slot_cap, skill_id, level, ": ")
            print_buyable_blocks(LeveledSkill{skill_id, level+1})
        }

        fmt.println("Extra Skills:")
        extra_slot_cap := DB.skill_rank_cap[DB.unit_level-1][MAIN_SKILLS_AMOUNT]
        for skill_id in DB.owned_extra_skills {
            level := DB.owned_skills[skill_id]
            fmt.print(" CAP:", extra_slot_cap, skill_id, level, ": ")
            print_buyable_blocks(LeveledSkill{skill_id, level+1})
        }
    }

    { // Print Owned Skills
        fmt.println("Owned Perks:")

        for perk in DB.owned_perks {
            fmt.print(" ",perk, ": ")
            print_buyable_blocks(perk)
        } 
    }

}

print_buyables :: proc(){
    fmt.println("Buyables:")
    for buyable, buyable_data in DB.buyable_data {
        switch b in buyable {
            case LeveledSkill:
                max_skill_owned, owned := DB.owned_skills[b.id]
                if (!owned && b.level == 1) || b.level == max_skill_owned + 1 {
                    fmt.print('\t')
                    fmt.print(b.id, b.level, ": ")
                    print_buyable_blocks(buyable)
                }
            case PerkID:
                if !player_has_perk(b) {
                    fmt.print('\t')
                    fmt.print(b,": ")
                    print_buyable_blocks(buyable)
                }
                
        }
    }
}

print_state :: proc(){
	print_buyables()
	print_player_state()
    fmt.println("Unused points:", DB.unused_points)
    fmt.println("Level:", DB.unit_level)
}

parse_action :: proc(action_str: string) -> Action {
    action, r_err := reflect.enum_from_name(Action, action_str)
    return action
}

parse_perk :: proc(s: string) -> PerkID {
    perk_id, r_err := reflect.enum_from_name(PerkID, s)
    return perk_id
}

parse_skill :: proc(skill_id_str: string) -> SkillID {
    skill_id, r_err := reflect.enum_from_name(SkillID, skill_id_str)
    return skill_id
}

run_cli :: proc() {
    
    // Clear Screen
    // fmt.print("\x1b[2J\x1b[H")
    print_state()

    scanner: bufio.Scanner
    stdin := os.stream_from_handle(os.stdin,)
    bufio.scanner_init(&scanner, stdin, context.temp_allocator)

    for {
        
        fmt.printf("> ")
        if !bufio.scanner_scan(&scanner) {
            break
        }
        line := bufio.scanner_text(&scanner)
        if line == "q" {break}
        words := strings.split(line, " ", context.temp_allocator)

        action := parse_action(words[0])

        // Clear Screen
        fmt.print("\x1b[2J\x1b[H")

        switch action {
            case .Refund:
                buyable := parse_perk(words[1])
                refunded, err := refund_buyable(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Refunded:", refunded)

            case .Raise:
                buyable := parse_skill(words[1])
                spent, err := raise_skill(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Cost:", spent)
            case .Buy:
                buyable := parse_perk(words[1])
                spent, err := buy_perk(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Cost:", spent)
            case .LevelUp:
                err := level_up()
                if err != nil do fmt.println(err)
            case .NotRecognized:
                fmt.println("Action Not Recognized")
        }

        print_state()
    }
    
    if err := bufio.scanner_error(&scanner); err != nil {
        fmt.eprintln("error scanning input: %v", err)
    }
    free_all(context.temp_allocator)

}
