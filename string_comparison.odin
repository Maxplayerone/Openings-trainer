package main

import "core:strconv"
import "core:os"

ComparisonResult :: enum{
    RightBigger,
    LeftBigger,
    Exact,
}

compare_strings :: proc(a, b: string) -> ComparisonResult{
    min_len := len(a) > len(b) ? len(b) : len(a)

    for i := 0; i < min_len; i += 1{
        if a[i] > b[i]{
            return .LeftBigger
        }
        else if b[i] > a[i]{
            return .RightBigger
        }
    }

    //if the string are the same but the right one is longer then left then b is further alphabetically
    //example:
    //left_string_is_further_alphabetically("hell", "hello") -> false
    if len(b) > len(a){
        return .RightBigger
    }
    else if len(a) > len(b){
        return .LeftBigger
    }
    else{
        return .Exact
    }
}


//return value is the index at which the number starts
//return -1 if there is not any postfix number
read_string_postfix_number :: proc(s: string) -> int{
    if !lexer_is_number(s[len(s) - 1]){
        return -1
    }

    index := len(s) - 1
    for lexer_is_number(s[index]){
        index -= 1
    }
    return index + 1
}

remove_extension_from_string :: proc(s: string) -> string{
    index := len(s) - 1
    for s[index] != '.'{

        //the string doesn't have an extension
        if index == 0{
            return s
        }

        index -= 1
    }
    return s[:index] 
}

//if both strings are the same and end in number 
compare_strings_with_number_postfix_maybe :: proc(a, b: string) -> ComparisonResult{
    a := remove_extension_from_string(a)
    b := remove_extension_from_string(b)

    a_starting_index := read_string_postfix_number(a)
    b_starting_index := read_string_postfix_number(b)

    //if one or both of the strings doesn't contain postfix number then we just do a normal comparison
    if a_starting_index == -1 || b_starting_index == -1{
        return compare_strings(a, b)
    }

    a_without_postfix_number := a[:a_starting_index]
    b_without_postfix_number := b[:b_starting_index]

    res := compare_strings(a_without_postfix_number, b_without_postfix_number)
    //both numbers have a postfix number but the strings aren't the same so we will just do a normal comparison 
    if res != .Exact{
        return res
    }

    a_postfix_number, ok1 := strconv.parse_int(a[a_starting_index:])
    if !ok1{
        assert(false)
    }
    b_postfix_number, ok2 := strconv.parse_int(b[b_starting_index:])
    if !ok2{
        assert(false)
    }


    if a_postfix_number > b_postfix_number{
        return .LeftBigger
    }
    else if b_postfix_number > a_postfix_number{
        return .RightBigger
    }
    else{
        return .Exact
    }
}

sort_strings :: proc(strings: []string, allocator := context.allocator) -> [dynamic]string{
    sorted := make([dynamic]string, allocator)
    append(&sorted, ..strings[:])

    swapped := true
    for i := 0; i < len(sorted) - 1; i += 1{
        swapped = false
        for j := 0; j < len(sorted) - i - 1; j += 1{
            if compare_strings_with_number_postfix_maybe(sorted[j], sorted[j + 1]) == .LeftBigger{
                tmp := sorted[j]
                sorted[j] = sorted[j + 1]
                sorted[j + 1] = tmp
            }

            swapped = true
        }

        if !swapped{
            break
        }
    }

    return sorted
}

sort_file_infos :: proc(file_infos: []os.File_Info, allocator := context.allocator) -> [dynamic]os.File_Info{
    sorted := make([dynamic]os.File_Info, allocator)
    append(&sorted, ..file_infos[:])

    swapped := true
    for i := 0; i < len(sorted) - 1; i += 1{
        swapped = false
        for j := 0; j < len(sorted) - i - 1; j += 1{
            if compare_strings_with_number_postfix_maybe(sorted[j].name, sorted[j + 1].name) == .LeftBigger{
                tmp := sorted[j]
                sorted[j] = sorted[j + 1]
                sorted[j + 1] = tmp
            }

            swapped = true
        }

        if !swapped{
            break
        }
    }

    return sorted
}
