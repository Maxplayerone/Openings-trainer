package main

import "core:fmt"
import "core:mem"
import "core:strings"
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
                    strings.write_string(&b, browser.nodes[browser_response].name)

                    moves, success := read_pgn(strings.to_string(b), board.pieces[:])
                    if !success{
                        assert(false)
                    }
                    board.moves = moves
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

	for key, value in tracking_allocator.allocation_map {
		fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
	}
}