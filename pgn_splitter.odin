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

remove_defects_from_builder :: proc(b: ^strings.Builder, allocator := context.allocator){
    str := strings.clone(strings.to_string(b^), allocator)
    strings.builder_reset(b)

    i := 0
    last_move_count := -1

    //(NOTE): I might be wrong about how to remove defects from pgn's that have the same move three times but it 
    //seems like you those situations you have to remove the middle move
    seen_same_move_count_count := 1 

    moves_indicies_btw_move_counts := [3]int{-1, -1, -1}
    for i < len(str){
        //checking if it's a move count
        if i + 1 < len(str) && lexer_is_number(str[i]){
            tmp_idx := i + 1
            for lexer_is_number(str[tmp_idx]){
                tmp_idx += 1
            }
            //reading move count
            if str[tmp_idx] == '.'{
                new_last_move_count, ok := strconv.parse_int(str[i:tmp_idx])
                if !ok{
                    fmt.println("Couldn't read move count. The string we've tried to parse is:", str[i:tmp_idx])
                    assert(false)
                }

                //remove defect
                if new_last_move_count == last_move_count{
                    seen_same_move_count_count += 1

                    fmt.println(seen_same_move_count_count)
                    for str[tmp_idx] == '.'{
                        tmp_idx += 1
                    }
                    i = tmp_idx
                }
                else{
                    last_move_count = new_last_move_count
                    seen_same_move_count_count = 1
                }
            }
        }

        strings.write_rune(b, rune(str[i]))
        i += 1
    }
}

write_nested_pgn :: proc(browser: ^Browser){
    str := browser.pgn_creation_window.textbox_string_raw
    filename := strings.to_string(browser.pgn_creation_window.filename_builder)
    last_square_bracket_idx, desired_depth_levels, name_postfixes := nested_pgn_prepass(str, "caro-kann", context.temp_allocator)
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
        err := os.write_entire_file_from_string(name_postfixes[name_postfixes_idx], strings.to_string(b))
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

            err := os.write_entire_file_from_string(name_postfixes[name_postfixes_idx], strings.to_string(b))
            name_postfixes_idx += 1
            assert(err == nil)
            strings.builder_reset(&b)
            strings.write_string(&b, str[:last_square_bracket_idx])
        }
    }
}
