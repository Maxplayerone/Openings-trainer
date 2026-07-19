package main

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

game_size := [2]f32{2000, 1500}

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
    moves, success := read_pgn("res/pgn/a1.pgn", board.pieces[:])
    if !success{
        assert(false)
    }
    board.moves = moves

    //ui
    browser, ok := browser_create()
    if !ok{
        assert(false)
    }

    for !rl.WindowShouldClose(){

        scale := min(f32(rl.GetScreenWidth()) / game_size.x, f32(rl.GetScreenHeight()) / game_size.y)
        virtual_mouse := get_virtual_mouse(game_size, scale)

        dt := f64(rl.GetFrameTime())

        //board_update(&board, virtual_mouse, dt)
        browser_update(&browser)

        rl.BeginTextureMode(target)
        rl.ClearBackground({74, 125, 208, 255})
        
        //board_render(&board, virtual_mouse) 
        browser_render(&browser)

        rl.EndTextureMode()

        render_framebuffer(target, game_size, scale)
        free_all(context.temp_allocator)
    }

    rl.UnloadRenderTexture(target)
    rl.CloseWindow()

    delete(board.moves)

    for node in browser.nodes{
        switch n in node{
            case SingleNode:
                delete(n.name)
            case Directory:
                delete(n.name)
                for child in n.children{
                    delete(child.name)
                }
                delete(n.children)
        }
    }
    delete(browser.nodes)

	for key, value in tracking_allocator.allocation_map {
		fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
	}
}