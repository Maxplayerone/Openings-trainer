package main

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:os"
import rl "vendor:raylib"

game_size := [2]f32{2000, 1500}

GameState :: enum{
    Browser, 
    Board,
}

game_state: GameState = .Browser

main :: proc(){
    //setup
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(i32(game_size.x), i32(game_size.y), "gaem") 
    rl.SetWindowMinSize(400, 300);
    rl.SetTargetFPS(60)

    target := rl.LoadRenderTexture(i32(game_size.x), i32(game_size.y))
    rl.SetTextureFilter(target.texture, .BILINEAR)

    //board
    board := board_create()

    //ui
    browser, ok := browser_create()
    if !ok{
        assert(false)
    }

    /*
    buf, err := os.read_entire_file_from_path("caro-kann.pgn", context.temp_allocator)
    assert(err == nil)
    browser.pgn_creation_window.textbox_string_raw = string(buf) 
    write_nested_pgn(&browser)
    moves, ok2 := read_pgn("caro-kann_3exd5_4Nf3_4g6", board.pieces[:])
    if !ok2{
        fmt.println("not ok")
        assert(false)
    }
    board.moves = moves
    */

    for !rl.WindowShouldClose(){

        scale := min(f32(rl.GetScreenWidth()) / game_size.x, f32(rl.GetScreenHeight()) / game_size.y)
        virtual_mouse := get_virtual_mouse(game_size, scale)

        dt := f64(rl.GetFrameTime())

        switch game_state{
            case .Browser:
                if browser_response := browser_update(&browser, virtual_mouse, dt); browser_response != -1{
                    game_state = .Board

                    delete(board.moves)

                    b := strings.builder_make()
                    defer strings.builder_destroy(&b)
                    strings.write_string(&b, "res/pgn/")
                    switch browser.nodes[browser_response].type{
                        case .Directory:
                        case .SingleNode:
                            strings.write_string(&b, browser.nodes[browser_response].name)
                        case .DirectoryChild:
                            //find parent
                            for i := browser_response - 1; i > -1; i -= 1{
                                if browser.nodes[i].type == .Directory{
                                    strings.write_string(&b, browser.nodes[i].name)
                                    strings.write_rune(&b, '/')
                                    strings.write_string(&b, browser.nodes[browser_response].name)
                                }
                            }
                    }

                    moves, picked_white, success := read_pgn(strings.to_string(b), board.pieces[:])
                    if !success{
                        assert(false)
                    }
                    board.moves = moves
                    board.is_white = picked_white
                    board.is_player_move = picked_white

                    if !picked_white{
                        read_fen("res/fen/default_black.fen", &board.pieces)
                        for i in 0..<len(board.moves){
                            if board.moves[i].from < 64{
                                board.moves[i].from = 63 - board.moves[i].from
                                board.moves[i].to = 63 - board.moves[i].to
                            }
                        }
                    }
                }
            case .Board:
                if board_update(&board, virtual_mouse, dt){
                    game_state = .Browser
                }
        }

        rl.BeginTextureMode(target)
        rl.ClearBackground({74, 125, 208, 255})
        
        switch game_state{
            case .Browser:
                browser_render(&browser)
            case .Board:
                board_render(&board, virtual_mouse) 
        }

        rl.EndTextureMode()

        render_framebuffer(target, game_size, scale)
        free_all(context.temp_allocator)
    }

    rl.UnloadRenderTexture(target)
    rl.CloseWindow()

    //(NOTE): for the next project think more about putting dynamic memory in arenas and freeing the whole arena at once
    delete(board.moves)

    strings.builder_destroy(&browser.pgn_creation_window.filename_builder)
    if browser.pgn_creation_window.is_open{
        for str in browser.pgn_creation_window.splitted_strings{
            delete(str)
        }
    }
    delete(browser.pgn_creation_window.splitted_strings)
    for node in browser.nodes{
        delete(node.name)
    }
    delete(browser.nodes)
    strings.builder_destroy(&browser.nested_pgn_infobox_builder)

	for key, value in tracking_allocator.allocation_map {
		fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
	}
}