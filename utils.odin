package main

import rl "vendor:raylib"
import "core:fmt"
import "core:math/rand"

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

rect_expand :: proc(rect: rl.Rectangle, expand_factor: f32) -> rl.Rectangle{
    return rl.Rectangle{rect.x - expand_factor, rect.y - expand_factor, rect.width + 2 * expand_factor, rect.height + 2 * expand_factor}
}

fit_and_center_text_in_rect :: proc(text: cstring, rect: rl.Rectangle, wanted_size: i32, color := rl.WHITE, min_size: i32 = 20, padding: f32 = 20.0) -> i32{
    actual_size := wanted_size
    for f32(rl.MeasureText(text, actual_size)) > rect.width - 2 * padding{
        actual_size -= 1
        assert(actual_size > min_size, "The text is too long for the rect")
    }
    center_text_in_rect(text, rect, actual_size, color)
    return actual_size
}

center_text_in_rect :: proc(text: cstring, rect: rl.Rectangle, text_size: i32, color := rl.WHITE){
    pos := get_center_of_text_in_rect(text, rect, text_size)
    rl.DrawText(text, pos.x, pos.y, text_size, color)
}

//return the position the text should be in so it is centered in the given rect
get_center_of_text_in_rect :: proc(text: cstring, rect: rl.Rectangle, text_size: i32) -> [2]i32{
    text_size := rl.Vector2{
        f32(rl.MeasureText(text, text_size)), 
        f32(text_size), //this feels wrong and problematic. But rl.GetFontDefault().baseSize is also not correct and this seems like close enough 
    }
    return {i32(rect.x + (rect.width - text_size.x) / 2), i32(rect.y + (rect.height - text_size.y) / 2)}
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

FrameTimer :: struct{
    cur_frame: int,
    max_frame: int,
}

frame_timer_create :: proc(max_frame: int) -> FrameTimer{
    return FrameTimer{cur_frame = 0, max_frame = max_frame}
}

frame_timer_update :: proc(frame_timer: ^FrameTimer){
    frame_timer.cur_frame += 1
}

frame_timer_is_finished :: proc(timer: FrameTimer) -> bool{
    return timer.cur_frame >= timer.max_frame
}

frame_timer_reset :: proc(timer: ^FrameTimer){
    timer.cur_frame = 0
}

get_color :: proc(index: int, alpha := 255) -> rl.Color{
    index := index % 16
    switch index{
        case 0:
            color := rl.YELLOW
            color.a = u8(alpha)
            return color
        case 1:
            color := rl.GOLD
            color.a = u8(alpha)
            return color
        case 2:
            color := rl.ORANGE
            color.a = u8(alpha)
            return color
        case 3:
            color := rl.PINK
            color.a = u8(alpha)
            return color
        case 4:
            color := rl.RED
            color.a = u8(alpha)
            return color
        case 5:
            color := rl.MAROON
            color.a = u8(alpha)
            return color
        case 6:
            color := rl.GREEN
            color.a = u8(alpha)
            return color
        case 7:
            color := rl.LIME
            color.a = u8(alpha)
            return color
        case 8:
            color := rl.DARKGREEN
            color.a = u8(alpha)
            return color
        case 9:
            color := rl.SKYBLUE
            color.a = u8(alpha)
            return color
        case 10:
            color := rl.BLUE
            color.a = u8(alpha)
            return color
        case 11:
            color := rl.DARKBLUE
            color.a = u8(alpha)
            return color
        case 12:
            color := rl.PURPLE
            color.a = u8(alpha)
            return color
        case 13:
            color := rl.VIOLET
            color.a = u8(alpha)
            return color
        case 14:
            color := rl.DARKPURPLE
            color.a = u8(alpha)
            return color
        case 15:
            color := rl.BEIGE
            color.a = u8(alpha)
            return color
    }
    return rl.Color{rl.BROWN.r, rl.BROWN.g, rl.BROWN.b, u8(alpha)}
}