package main

import "core:strconv"
import "core:strings"
import "core:os"
import "core:bufio"
import "core:fmt"
import "core:reflect"

Action :: enum {
    NotRecognized,
    Buy,
    Refund,
    LevelUp,
}

print_buyable_blocks :: proc(buyable: Buyable) {
    buyable_data := DB.buyable_data[buyable]
    fmt.print(buyable_data.bought_amount, "/", BlocksSize(len(buyable_data.owned_blocks)), "")
    switch {
        // Already Bought
        case buyable_data.bought:
            for block in buyable_data.owned_blocks do fmt.print("\x1b[44m \x1b[0m")
        // Free
        case BlocksSize(len(buyable_data.owned_blocks)) == buyable_data.bought_amount:
            fmt.print("FREE! ")
            for block in buyable_data.owned_blocks do fmt.print("\x1b[43m \x1b[0m")
        case:
            for block in buyable_data.owned_blocks {
                if block.bought do fmt.print("\x1b[42m \x1b[0m")
                else do fmt.print("\x1b[31m█\x1b[0m")
            }
    }

    fmt.print('\n')
}

print_player_state :: proc() {


    { // Print Owned Skills
        fmt.println("Owned Skills:")

        for skill_id, level in player.owned_skills {
            fmt.print(" ",skill_id, level, ": ")
            print_buyable_blocks(LeveledSkill{skill_id, level})
        } 
    }

    { // Print Owned Skills
        fmt.println("Owned Perks:")

        for perk in player.owned_perks {
            fmt.print(" ",perk, ": ")
            print_buyable_blocks(perk)
        } 
    }

}

print_buyables :: proc(){
    fmt.println("Buyables:")
    for buyable, buyable_data in DB.buyable_data {
        fmt.print('\t')
        switch b in buyable {
            case LeveledSkill:
                fmt.print(b.id, b.level, ": ")
            case PerkID:
                fmt.print(b,": ")
        }
        print_buyable_blocks(buyable)
    }
}

print_state :: proc(){

	print_buyables()
	print_player_state()
    fmt.println("Unused points:", player.unused_points)
    fmt.println("Level:", player.level)
}

parse_action :: proc(s: string) -> Action {
    switch s {
        case "buy":
            return .Buy
        case "refund":
            return .Refund
        case "levelup":
            return .LevelUp
    }
    return .NotRecognized
}

parse_perk :: proc(s: string) -> PerkID {
    switch s {
        case "Aim":
            return .Aim
        case "Knife_Master":
            return .Knife_Master
        case "Trip":
            return .Trip
        case "Sight":
            return .Sight
    }
    return nil
}

parse_skill :: proc(skill_id_str: string, skill_level_str: string) -> LeveledSkill {
    skill_id : SkillID
    skill_level : LEVEL
    skill_id_upper_str, _ := strings.to_upper(skill_id_str, context.temp_allocator)
    switch skill_id_upper_str {
        case "MELEE":
            skill_id = .Melee
        case "ATHLETICS":
            skill_id = .Athletics
    }
    skill_level_uint, _ := strconv.parse_uint(skill_level_str)
    skill_level = LEVEL(skill_level_uint)
    return LeveledSkill{skill_id, skill_level}
}

run_cli :: proc() {
    
    // Clear Screen
    // fmt.print("\x1b[2J\x1b[H")
    print_state()

    scanner: bufio.Scanner
    stdin := os.stream_from_handle(os.stdin)
    bufio.scanner_init(&scanner, stdin)

    for {
        
        fmt.printf("> ")
        if !bufio.scanner_scan(&scanner) {
            break
        }
        line := bufio.scanner_text(&scanner)
        if line == "q" {break}
        words := strings.split(line, " ", context.temp_allocator)

        action := parse_action(words[0])

        buyable : Buyable
        switch {
            case len(words) == 2:
                buyable = parse_perk(words[1])
            case len(words) > 2:
                action = parse_action(words[0])
                buyable = parse_skill(words[1], words[2])
        }


        // Clear Screen
        fmt.print("\x1b[2J\x1b[H")

        switch action {
            case .Refund:
                refund_buyable(buyable)
            case .Buy:
                buy_buyable(buyable)
                spent, err := buy_buyable(buyable)
                if err != nil do fmt.println(err)
                else do fmt.println("Cost of", buyable, spent)
            case .LevelUp:
                level_up()
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
