package main

import "core:strings"
import "core:fmt"
import "core:os"
import "core:strconv"

check_if_nested_pgn :: proc(browser: ^Browser) -> bool{
    in_header := false
    for char in browser.pgn_creation_window.textbox_string_raw{
        if char == '(' && !in_header{
            return true
        }
        else if char == '['{
            in_header = true
        }
        else if char == ']'{
            in_header = false
        }
    }
    return false 
}

lookup_bracket_pair_at_depth_lvl :: proc(str: string, cur_depth_lvl, desired_depth_lvl: int) -> int{
    assert(str[0] == '(', "if you pass a string to this funciton the first char should be a (")

    opened_brackets := 1
    bracket_pair_at_depth_lvl := 0
    cur_depth_lvl := cur_depth_lvl

    for c in str[1:]{
        if c == '('{
            opened_brackets += 1
            cur_depth_lvl += 1

            if cur_depth_lvl == desired_depth_lvl{
                bracket_pair_at_depth_lvl += 1
            }
        }
        else if c == ')'{
            opened_brackets -= 1
            cur_depth_lvl -= 1

            if opened_brackets == 0{
                return bracket_pair_at_depth_lvl
            }
        }
    }

    //the function should break when we get to the closing bracket pair for the first char in str
    //if that didn't happen it means the given string's opened and closed brackets don't match 
    assert(false)
    return -1
}

find_duplicate_in_name_postfixes :: proc(names: []string, name: string) -> bool{
    for n in names{
        if n == name{
            return true
        }
    }
    return false
}

sort_postfix_names :: proc(names: ^[dynamic]string){
    swapped := true
    for i := 0; i < len(names) - 1; i += 1{
        swapped = false

        for j := 0; j < len(names) - i - 1; j += 1{
            if strings.count(names[j], "_") > strings.count(names[j + 1], "_"){
                tmp := names[j]
                names[j] = names[j + 1]
                names[j + 1] = tmp
                swapped = true
            }
        }

        if !swapped{
            break
        }
    }
}

//calculating:
//last_square_bracket_index
//amount of bracket pairs for each depth lvl
//name postfixes for each cut pgn
nested_pgn_prepass :: proc(str, filename: string, allocator := context.allocator) -> (int, [dynamic]int, [dynamic]string){
    cur_depth_lvl := -1
    depth_lvls := make([dynamic]int, allocator)

    //check if every bracket opening has a closing
    opened_brackets := 0
    in_header := false
    last_square_bracket_idx := 0

    b := strings.builder_make(allocator)

    name_postfixes := make([dynamic]string, allocator)

    strings.write_string(&b, filename)
    strings.write_string(&b, "_main")
    append(&name_postfixes, strings.clone(strings.to_string(b), allocator))

    strings.builder_reset(&b)
    strings.write_string(&b, filename)

    for char, i in str{
        if char == '['{
            in_header = true
        }
        else if char == ']'{
            in_header = false
            last_square_bracket_idx = i + 1
        }
        else if char == '(' && !in_header{
            opened_brackets += 1

            cur_depth_lvl += 1
            if cur_depth_lvl >= len(depth_lvls){
                append(&depth_lvls, 1)
            }
            else{
                depth_lvls[cur_depth_lvl] += 1
            }

            idx := i + 1
            strings.write_rune(&b, '_')
            strings.write_rune(&b, rune(str[idx]))
            idx += 1
            for !(lexer_is_number(str[idx]) || lexer_is_letter(str[idx])){
                idx += 1
            }
            for str[idx] != ' ' && str[idx] != ')'{
                strings.write_rune(&b, rune(str[idx]))
                idx += 1
            }

            for find_duplicate_in_name_postfixes(name_postfixes[:], strings.to_string(b)){
                assert(false, "add funcitonality for dealing with duplicate names")
            }
            append(&name_postfixes, strings.clone(strings.to_string(b), allocator))
        }
        else if char == ')' && !in_header{
            opened_brackets -= 1
            cur_depth_lvl -= 1

            postfix := strings.clone(strings.to_string(b), context.temp_allocator)
            if idx := strings.last_index(postfix, "_"); idx != -1{
                postfix = postfix[:idx] 

                /*
                if alt_idx := strings.last_index(postfix, "_alt"); alt_idx != -1{
                    postfix = postfix[:alt_idx]
                }
                    */
                strings.builder_reset(&b)
                strings.write_string(&b, postfix)
            }
            else{
                strings.builder_reset(&b)
            }
        }
    }

    if opened_brackets != 0{
        last_square_bracket_idx = -1        
    }

    sort_postfix_names(&name_postfixes)
    
    return last_square_bracket_idx, depth_lvls, name_postfixes
}

move_count_to_num :: proc(tok: Token) -> int{
    assert(tok.type == .MoveCount)
    num, ok := strconv.parse_int(tok.lexeme[:len(tok.lexeme)-1])
    assert(ok)
    return num
}

remove_defects_from_builder :: proc(b: ^strings.Builder, allocator := context.allocator){
    str := strings.clone(strings.to_string(b^), allocator)
    strings.builder_reset(b)
    lexer := Lexer{input=str}

    tokens := make([dynamic]Token, allocator)
    cur_tok_idx := 0

    for tok := lexer_next_token(&lexer); tok.type != .EOF; tok = lexer_next_token(&lexer){
        append(&tokens, tok)
    }
    append(&tokens, Token{.EOF, "eof", 67})

    for tokens[cur_tok_idx].type == .Metadata{
        strings.write_string(b, tokens[cur_tok_idx].lexeme)
        strings.write_rune(b, '\n')
        cur_tok_idx += 1
    }

    MoveInfo :: struct{
        move_lexeme: string,
        same_number_count: int,
    }

    for tokens[cur_tok_idx].type == .MoveCount{
        move_btw_movecounts: [4]MoveInfo
        mbmc_idx := 0
        same_number_count := 0
        cur_move_count := move_count_to_num(tokens[cur_tok_idx])
        cur_tok_idx += 1

        //calculate info about moves between two differently numbered move counts
        inner: for{
            switch tokens[cur_tok_idx].type{
                case .Error:
                case .Metadata:
                case .Promotion, .Checkmate, .Check:
                    assert(false)
                case .EOF, .FinalVerdict:
                    break inner
                case .MoveCount:
                    next_move_count := move_count_to_num(tokens[cur_tok_idx])
                    if next_move_count != cur_move_count{
                        break inner
                    }
                    else{
                        same_number_count += 1
                    }
                case .Castles, .Capture, .CaptureAmbiguity, .PieceIndicator:
                    move_len := len(tokens[cur_tok_idx].lexeme)
                    starting_idx := tokens[cur_tok_idx].idx

                    if tokens[cur_tok_idx].type == .PieceIndicator{
                        assert(tokens[cur_tok_idx + 1].type == .MoveCoordinates)
                        move_len += 2
                        cur_tok_idx += 1
                    }
                    if cur_tok_idx + 1 < len(tokens) && (tokens[cur_tok_idx + 1].type == .Check || tokens[cur_tok_idx + 1].type == .Checkmate) {
                        move_len += 1
                        cur_tok_idx += 1
                    }
                    else if cur_tok_idx + 1 < len(tokens) && tokens[cur_tok_idx + 1].type == .Promotion{
                        move_len += 2
                        cur_tok_idx += 1
                    }
                    move_btw_movecounts[mbmc_idx] = MoveInfo{
                        move_lexeme = str[starting_idx:starting_idx+move_len],
                        same_number_count = same_number_count,
                    }
                    mbmc_idx += 1
                case .MoveCoordinates:
                    if tokens[cur_tok_idx - 1].type != .PieceIndicator{
                        move_len := 2
                        starting_idx := tokens[cur_tok_idx].idx

                        if cur_tok_idx + 1 < len(tokens) && (tokens[cur_tok_idx + 1].type == .Check || tokens[cur_tok_idx + 1].type == .Checkmate) {
                            move_len += 1
                            cur_tok_idx += 1
                        }
                        else if cur_tok_idx + 1 < len(tokens) && tokens[cur_tok_idx + 1].type == .Promotion{
                            move_len += 2
                            cur_tok_idx += 1
                        }
                        move_btw_movecounts[mbmc_idx] = MoveInfo{
                            move_lexeme = str[starting_idx:starting_idx+move_len],
                            same_number_count = same_number_count,
                        }
                        mbmc_idx += 1
                    }
            }
            cur_tok_idx += 1
        } 

        //write to the builder based on the results
        strings.write_int(b, cur_move_count)
        strings.write_string(b, ". ")
        if mbmc_idx == 1{
            strings.write_string(b, move_btw_movecounts[0].move_lexeme)
            strings.write_rune(b, ' ')
        }
        else if mbmc_idx == 2 &&
        ((move_btw_movecounts[0] .same_number_count == 0 && move_btw_movecounts[1].same_number_count == 0) ||
        (move_btw_movecounts[0].same_number_count == 0 && move_btw_movecounts[1].same_number_count == 1)){
            strings.write_string(b, move_btw_movecounts[0].move_lexeme)
            strings.write_rune(b, ' ')
            strings.write_string(b, move_btw_movecounts[1].move_lexeme)
            strings.write_rune(b, ' ')
        }
        else if mbmc_idx == 3 && move_btw_movecounts[0].same_number_count == 0 && move_btw_movecounts[1].same_number_count == 0 && move_btw_movecounts[2].same_number_count == 1{
            strings.write_string(b, move_btw_movecounts[0].move_lexeme)
            strings.write_rune(b, ' ')
            strings.write_string(b, move_btw_movecounts[2].move_lexeme)
            strings.write_rune(b, ' ')
        }
        else if mbmc_idx == 3 && move_btw_movecounts[0].same_number_count == 0 && move_btw_movecounts[1].same_number_count == 1 && move_btw_movecounts[2].same_number_count == 1{
            strings.write_string(b, move_btw_movecounts[1].move_lexeme)
            strings.write_rune(b, ' ')
            strings.write_string(b, move_btw_movecounts[2].move_lexeme)
            strings.write_rune(b, ' ')
        }
        else if mbmc_idx == 3 && move_btw_movecounts[0].same_number_count == 0 && move_btw_movecounts[1].same_number_count == 1 && move_btw_movecounts[2].same_number_count == 2{
            strings.write_string(b, move_btw_movecounts[0].move_lexeme)
            strings.write_rune(b, ' ')
            strings.write_string(b, move_btw_movecounts[2].move_lexeme)
            strings.write_rune(b, ' ')
        }
        else if mbmc_idx == 4{
            assert(move_btw_movecounts[0].same_number_count == 0)
            assert(move_btw_movecounts[1].same_number_count == 1)
            assert(move_btw_movecounts[2].same_number_count == 1)
            assert(move_btw_movecounts[3].same_number_count == 2)

            strings.write_string(b, move_btw_movecounts[1].move_lexeme)
            strings.write_rune(b, ' ')
            strings.write_string(b, move_btw_movecounts[3].move_lexeme)
            strings.write_rune(b, ' ')
        }
        else{
            fmt.println("We don't handle this situation:")
            fmt.println("move_btw_movecounts:")
            for mbmc in move_btw_movecounts{
                fmt.println(mbmc)
            }
            assert(false)
        }
    }

    if tokens[cur_tok_idx].type == .FinalVerdict{
        strings.write_string(b, tokens[cur_tok_idx].lexeme)
    }
}

write_nested_pgn :: proc(browser: ^Browser) -> int{
    str := browser.pgn_creation_window.textbox_string_raw
    pgns_count := 0

    filename := strings.clone(strings.to_string(browser.pgn_creation_window.filename_builder), context.temp_allocator)
    strings.builder_reset(&browser.pgn_creation_window.filename_builder)
    strings.write_string(&browser.pgn_creation_window.filename_builder, "res/pgn/")
    strings.write_string(&browser.pgn_creation_window.filename_builder, filename)
    err := os.make_directory(strings.to_string(browser.pgn_creation_window.filename_builder))
    assert(err == nil)

    last_square_bracket_idx, desired_depth_levels, name_postfixes := nested_pgn_prepass(str, filename, context.temp_allocator)

    name_postfixes_idx := 0

    b := strings.builder_make(context.temp_allocator)
    strings.write_string(&b, str[:last_square_bracket_idx])
    //writing the root level pgn
    {
        opened_brackets := 0
        for c in str[last_square_bracket_idx:]{
            if c == '('{
                opened_brackets += 1
            }
            else if c == ')'{
                opened_brackets -= 1
                continue
            }

            if opened_brackets > 0{
                continue
            }
            strings.write_rune(&b, c)
        }

        remove_defects_from_builder(&b, context.temp_allocator)

        strings.builder_reset(&browser.pgn_creation_window.filename_builder)
        strings.write_string(&browser.pgn_creation_window.filename_builder, "res/pgn/")
        strings.write_string(&browser.pgn_creation_window.filename_builder, filename)
        strings.write_rune(&browser.pgn_creation_window.filename_builder, '/')
        strings.write_string(&browser.pgn_creation_window.filename_builder, name_postfixes[name_postfixes_idx])
        err := os.write_entire_file_from_string(strings.to_string(browser.pgn_creation_window.filename_builder), strings.to_string(b))
        pgns_count += 1
        name_postfixes_idx += 1
        assert(err == nil)
        strings.builder_reset(&b)
        strings.write_string(&b, str[:last_square_bracket_idx])
    }

    //(NOTE): jezeli bedziesz musial poprawiac ten kod, bo cos nie dziala
    //to proponuje podzielić ten loop tak żebyś oddzielnie parsował depth = 1, czyli aaaaaa (ten tekst (aaaaa) ten tekst) aaaa (ten tekst) aaaa
    //bo działa to trochę inaczej niż parsowanie multiply-nested części pgn'a.
    //singly nested polega tylko na sprawdzeniu czy bracket_count jest zgodny z desired_bracket_count
    //a multiply nested polega na sprawdzeniu czy dana "rodzina par" powiększy bracket_count >= desired_bracket_count

    //podzielenie kodu nie zmniejszy jego szybkości, a zapewne uprości kilka if statementów
    for i in 0..<len(desired_depth_levels){
        desired_depth_lvl := i + 1

        for desired_bracket_count in 1..=desired_depth_levels[i]{

            cur_depth_lvl := 0
            bracket_count := 0
            ignore := false

            in_correct_root := false
            correct_root_depth_lvl := -1

            for c, i in str[last_square_bracket_idx:]{
                if c == '('{
                    cur_depth_lvl += 1

                    if cur_depth_lvl == desired_depth_lvl{
                        bracket_count += 1
                    }

                    if cur_depth_lvl > desired_depth_lvl || (cur_depth_lvl == desired_depth_lvl && bracket_count != desired_bracket_count){
                        ignore = true
                    }
                    if bracket_count + lookup_bracket_pair_at_depth_lvl(str[last_square_bracket_idx + i:], cur_depth_lvl, desired_depth_lvl) < desired_bracket_count{
                        if cur_depth_lvl < correct_root_depth_lvl{
                            in_correct_root = false
                        }
                        ignore = true
                    }
                    else{
                        in_correct_root = true
                        correct_root_depth_lvl = cur_depth_lvl
                    }
                    continue //skipping writing '(' into the builder
                }
                else if c == ')'{
                    if cur_depth_lvl == desired_depth_lvl && bracket_count == desired_bracket_count{
                        break
                    }

                    cur_depth_lvl -= 1

                    if (cur_depth_lvl == 0) || (in_correct_root  && cur_depth_lvl <= desired_depth_lvl) || (cur_depth_lvl == desired_depth_lvl && bracket_count == desired_bracket_count){
                        ignore = false
                        continue
                    }
                }

                if ignore{
                    continue
                }
                strings.write_rune(&b, c)
            }

            remove_defects_from_builder(&b, context.temp_allocator)

            strings.builder_reset(&browser.pgn_creation_window.filename_builder)
            strings.write_string(&browser.pgn_creation_window.filename_builder, "res/pgn/")
            strings.write_string(&browser.pgn_creation_window.filename_builder, filename)
            strings.write_rune(&browser.pgn_creation_window.filename_builder, '/')
            strings.write_string(&browser.pgn_creation_window.filename_builder, name_postfixes[name_postfixes_idx])
            err := os.write_entire_file_from_string(strings.to_string(browser.pgn_creation_window.filename_builder), strings.to_string(b))

            pgns_count += 1
            name_postfixes_idx += 1
            assert(err == nil)
            strings.builder_reset(&b)
            strings.write_string(&b, str[:last_square_bracket_idx])
        }
    }

    strings.builder_reset(&browser.pgn_creation_window.filename_builder)
    strings.write_string(&browser.pgn_creation_window.filename_builder, filename)
    return pgns_count
}
