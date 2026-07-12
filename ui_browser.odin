package main

import "core:os"
import "core:strings"

import rl "vendor:raylib"

PgnDescription :: struct{
    name: string,
}

Browser :: struct{
    pgns: [dynamic]PgnDescription,
    selected_pgn_index: int,
}

browser_create :: proc() -> Browser{
    browser: Browser
    browser.pgns = make([dynamic]PgnDescription, context.allocator)

    file_infos, err := os.read_all_directory_by_path("res/pgn", context.allocator)
    for file_info in file_infos{
        name := strings.clone(file_info.name)
        append(&browser.pgns, PgnDescription{name})
    }
    os.file_info_slice_delete(file_infos, context.allocator)

    return browser
}

browser_update :: proc(browser: ^Browser){
    if rl.IsKeyPressed(.K) && browser.selected_pgn_index < len(browser.pgns){

    }
}

browser_render :: proc(browser: Browser){
    for name, i in browser.pgns{
        if i == browser.selected_pgn_index{
            rl.DrawRectangleRec({game_size.x * 0.5, 50 + 220 * f32(i), game_size.x * 0.5, 200}, rl.WHITE)
        }
        else{
            rl.DrawRectangleRec({game_size.x * 0.5, 50 + 220 * f32(i), game_size.x * 0.5, 200}, rl.BLACK)
        }
    }
}