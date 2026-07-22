package main

import rl "vendor:raylib"

min :: proc(a, b: f32) -> f32{
    if a > b{
        return b
    }
    return a
}

max :: proc(a, b: f32) -> f32{
    if a > b{
        return a
    }
    return b
}

collission_mouse_rect :: proc(rect: rl.Rectangle, mouse: rl.Vector2) -> bool {
	return(
		mouse.x >= rect.x &&
		mouse.x <= rect.x + rect.width &&
		mouse.y >= rect.y &&
		mouse.y <= rect.y + rect.height
	)
}

to_rect :: proc(pos: rl.Vector2, size: f32) -> rl.Rectangle{
    return rl.Rectangle{pos.x, pos.y, size, size}
}

get_virtual_mouse :: proc(game_size: [2]f32, scale: f32) -> rl.Vector2{
    mouse := rl.GetMousePosition()
    virtual_mouse := rl.Vector2{0.0, 0.0}
    virtual_mouse.x = (mouse.x - (f32(rl.GetScreenWidth()) - (game_size.x * scale)) * 0.5)/scale
    virtual_mouse.y = (mouse.y - (f32(rl.GetScreenHeight()) - (game_size.y * scale)) * 0.5)/scale
    virtual_mouse = rl.Vector2Clamp(virtual_mouse, {0.0, 0.0}, {game_size.x, game_size.y})
    return virtual_mouse
}

render_framebuffer :: proc(target: rl.RenderTexture2D, game_size: [2]f32, scale: f32){
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    rl.DrawTexturePro(target.texture, 
        {0.0, 0.0, f32(target.texture.width), f32(-target.texture.height)}, 
        {(f32(rl.GetScreenWidth()) - game_size.x * scale) * 0.5, (f32(rl.GetScreenHeight()) - game_size.y * scale) * 0.5, game_size.x * scale, game_size.y * scale, },
        {0.0, 0.0},
        0.0,
        rl.WHITE,
    )
    rl.EndDrawing()
}

Timer :: struct{
    max_time: f64,
    cur_time: f64
}

timer_create :: proc(max_time: f64, finished_at_the_start := false) -> Timer{
    if finished_at_the_start{
        return Timer{max_time = max_time, cur_time = max_time}
    }
    else{
        return Timer{max_time = max_time, cur_time = 0.0}
    }
}

timer_update :: proc(timer: ^Timer, dt: f64){
    timer.cur_time += dt
}

timer_is_finised :: proc(timer: Timer) -> bool{
    return timer.cur_time >= timer.max_time
}

timer_reset :: proc(timer: ^Timer){
    timer.cur_time = 0.0
}

timer_percentage_time_elapsed :: proc(timer: Timer) -> f64{
    return timer.cur_time / timer.max_time
}