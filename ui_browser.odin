package main

import "core:os"
import "core:strings"
import "core:fmt"
import "base:runtime"
import vmem "core:mem/virtual"

import rl "vendor:raylib"

NodeType :: enum{
    SingleNode,
    Directory,
    DirectoryChild,
}

Node :: struct{
    name: string, 
    type: NodeType,
    is_selected: bool,
    is_open: bool,
    child_count: int,
}

MAX_VISIBLE_NODE_AMOUNT :: 12

Button :: struct{
    cur_color: rl.Color,
    color_normal: rl.Color,
    color_hovered: rl.Color,
    rect: rl.Rectangle,
    texture: rl.Texture2D,
}

PgnCreationWindow :: struct{
    background: rl.Rectangle,

    blinking_underscore_timer: FrameTimer,
    show_underscore: bool,

    filename_box: rl.Rectangle,
    filename_text_size: i32,
    filename_box_is_focused: bool,
    filename_builder: strings.Builder,
    max_filename_length: int,

    textbox: rl.Rectangle,
    textbox_text_size: i32,
    textbox_is_focused: bool,
    textbox_string_raw: string,
    splitted_strings: [dynamic]cstring,
    textbox_cur_line: int,

    color_sel_circles_pos: [2]rl.Vector2,
    color_sel_circles_color: [2]rl.Color,
    selected_circle: int,
    color_sel_circle_radius: f32,

    create_rect: rl.Rectangle,
    create_cur_color: rl.Color,
    create_normal_color: rl.Color,
    create_hovered_color: rl.Color,

    is_open: bool,
}

Browser :: struct{
    nodes: [dynamic]Node,
    visible_nodes_indicies: [MAX_VISIBLE_NODE_AMOUNT]int,
    pivot: int,
    how_long_held_movement_keys: Timer,

    create_pgn_button: Button,

    pgn_creation_window: PgnCreationWindow,
}

load_nodes :: proc(browser: ^Browser) -> bool{
    for node in browser.nodes{
        delete(node.name)
    }
    clear(&browser.nodes)
    path := "res/pgn"
    file_infos, err := os.read_all_directory_by_path(path, context.allocator)
    defer os.file_info_slice_delete(file_infos, context.allocator)

    file_infos_sorted := sort_file_infos(file_infos)
    defer delete(file_infos_sorted)

    if err != nil{
        fmt.println(err)
        return false
    }

    b := strings.builder_make()
    defer strings.builder_destroy(&b)

    for file_info in file_infos_sorted{
        name := strings.clone(file_info.name)

        if file_info.type == .Directory{
            strings.builder_reset(&b)

            strings.write_string(&b, path)
            strings.write_string(&b, "/")
            strings.write_string(&b, file_info.name)

            directory_infos, err := os.read_all_directory_by_path(strings.to_string(b), context.allocator)
            defer os.file_info_slice_delete(directory_infos, context.allocator)

            dir_infos_sorted := sort_file_infos(directory_infos)
            defer delete(dir_infos_sorted)

            if err != nil{
                fmt.println(err)
                return false
            }

            append(&browser.nodes, Node{name = name, type = .Directory})
            dir_index := len(browser.nodes) - 1

            for directory_file_info in dir_infos_sorted{
                child_name := strings.clone(directory_file_info.name)

                if directory_file_info.type == .Directory{
                    fmt.println("[browser_create] cannot have a directory inside a directory")
                    return false
                }

                browser.nodes[dir_index].child_count += 1
                append(&browser.nodes, Node{name = child_name, type = .DirectoryChild})
            }
            for i in (dir_index + 1)..<len(browser.nodes){
                browser.nodes[i].child_count = browser.nodes[dir_index].child_count
            }
        }
        else{
            append(&browser.nodes, Node{name = name, type = .SingleNode})
        }
    }

    assert(len(browser.nodes) >= MAX_VISIBLE_NODE_AMOUNT, " if there are less than MAX_VISIBLE_NODE_AMOUNT files than problems arise. You should probably fix it some time")

    browser.nodes[0].is_selected = true
    refresh_visible_nodes(browser)
    return true
}

browser_create :: proc() -> (Browser, bool){
    browser: Browser
    browser.nodes = make([dynamic]Node, context.allocator)

    if ok := load_nodes(&browser); !ok{
        return {}, false
    }

    browser.how_long_held_movement_keys = timer_create(0.5)
    browser.create_pgn_button = Button{
        color_normal = rl.BLACK,
        color_hovered = rl.DARKGRAY,
        rect = rl.Rectangle{40, game_size.y - 40 - 150, 150, 150},
        //texture = rl.LoadTexture("res/textures/menu"),
    }
    browser.create_pgn_button.cur_color = browser.create_pgn_button.color_normal

    //making creation window
    browser.pgn_creation_window.background = rl.Rectangle{game_size.x * 0.2, game_size.y * 0.03, game_size.x * 0.6, game_size.y * 0.92}
    bg := browser.pgn_creation_window.background
    browser.pgn_creation_window.filename_box = rl.Rectangle{bg.x + bg.width * 0.1, bg.y + bg.height * 0.03, bg.width * 0.8, bg.height * 0.08}

    browser.pgn_creation_window.textbox = rl.Rectangle{bg.x + bg.width * 0.1, bg.y + bg.height * 0.14, bg.width * 0.8, bg.height * 0.65}
    browser.pgn_creation_window.textbox_text_size = 30

    browser.pgn_creation_window.filename_text_size = 50
    browser.pgn_creation_window.filename_builder = strings.builder_make(context.allocator)
    browser.pgn_creation_window.max_filename_length = 30
    browser.pgn_creation_window.blinking_underscore_timer = frame_timer_create(20)

    center_point_btw_circles := rl.Vector2{bg.x + bg.width * 0.5, bg.y + bg.height * 0.84}
    dist_btw_circles := f32(100)
    browser.pgn_creation_window.color_sel_circles_pos[0] = {center_point_btw_circles.x - dist_btw_circles, center_point_btw_circles.y}
    browser.pgn_creation_window.color_sel_circles_pos[1] = {center_point_btw_circles.x + dist_btw_circles, center_point_btw_circles.y}
    browser.pgn_creation_window.color_sel_circle_radius = 40.0
    browser.pgn_creation_window.color_sel_circles_color[0] = rl.WHITE
    browser.pgn_creation_window.color_sel_circles_color[1] = rl.BLACK

    browser.pgn_creation_window.create_rect = rl.Rectangle{bg.x + bg.width * 0.35, bg.y + bg.height * 0.9, bg.width * 0.3, bg.height * 0.08}
    browser.pgn_creation_window.create_normal_color = rl.BLACK
    browser.pgn_creation_window.create_hovered_color = rl.DARKGRAY
    browser.pgn_creation_window.create_cur_color = browser.pgn_creation_window.create_normal_color

    return browser, true
}

browser_update :: proc(browser: ^Browser, virtual_mouse: rl.Vector2, dt: f64) -> int{
    if browser.pgn_creation_window.is_open{

        frame_timer_update(&browser.pgn_creation_window.blinking_underscore_timer)
        if frame_timer_is_finished(browser.pgn_creation_window.blinking_underscore_timer){
            frame_timer_reset(&browser.pgn_creation_window.blinking_underscore_timer)
            browser.pgn_creation_window.show_underscore = !browser.pgn_creation_window.show_underscore
        }

        //--------create_rect
        if collission_mouse_rect(browser.pgn_creation_window.create_rect, virtual_mouse){
            browser.pgn_creation_window.create_cur_color = browser.pgn_creation_window.create_hovered_color
        }
        else{
            browser.pgn_creation_window.create_cur_color = browser.pgn_creation_window.create_normal_color
        }

        if rl.IsMouseButtonPressed(.LEFT) && collission_mouse_rect(browser.pgn_creation_window.create_rect, virtual_mouse) || 
          rl.IsKeyPressed(.ENTER) && !browser.pgn_creation_window.filename_box_is_focused{

            if check_if_nested_pgn(browser){
                write_nested_pgn(browser)
            }
            else{
                write_pgn(browser)
            }

            strings.builder_reset(&browser.pgn_creation_window.filename_builder)
            for str in browser.pgn_creation_window.splitted_strings{
                delete(str)
            }
            browser.pgn_creation_window.is_open = false

            //(NOTE): this is not the best way to do it because we are clearing the whole nodes array
            //if there will be a performance problem with adding a new pgn we should look into this function
            ok := load_nodes(browser)
            assert(ok)
        }

        //-----filename_box
        if rl.IsMouseButtonPressed(.LEFT){
            browser.pgn_creation_window.filename_box_is_focused = collission_mouse_rect(browser.pgn_creation_window.filename_box, virtual_mouse)
        }
        
        if browser.pgn_creation_window.filename_box_is_focused{

            key := rune(rl.GetKeyPressed()) //the function registers any letters are big letters (a and A returns the same KeyboardKey.A) 
            if len(browser.pgn_creation_window.filename_builder.buf) < browser.pgn_creation_window.max_filename_length && 
              (key >= 'A' && key <= 'Z' || key >= '0' && key <= '9' || key == '-'){

                if rl.IsKeyDown(.LEFT_SHIFT) && key == '-'{
                    strings.write_rune(&browser.pgn_creation_window.filename_builder, '_')
                }
                else if !rl.IsKeyDown(.LEFT_SHIFT) && key >= 'A' && key <= 'Z'{
                    strings.write_rune(&browser.pgn_creation_window.filename_builder, key - ('A' - 'a'))
                }
                else{
                    strings.write_rune(&browser.pgn_creation_window.filename_builder, key)
                }
            }

            if rl.IsKeyPressed(.BACKSPACE){
                if rl.IsKeyDown(.LEFT_CONTROL){
                    strings.builder_reset(&browser.pgn_creation_window.filename_builder)
                }
                else{
                    strings.pop_rune(&browser.pgn_creation_window.filename_builder)
                }
            }

            //exiting out of filename_box focused state
            if rl.IsKeyPressed(.ENTER){
                browser.pgn_creation_window.filename_box_is_focused = false
            }
        }

        //--------textbox 
        if rl.IsMouseButtonPressed(.LEFT){
            browser.pgn_creation_window.textbox_is_focused = collission_mouse_rect(browser.pgn_creation_window.textbox, virtual_mouse)
        }

        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.V){
            pgn_string := string(rl.GetClipboardText())
            browser.pgn_creation_window.textbox_string_raw = pgn_string
            browser.pgn_creation_window.splitted_strings = split_textbox_string(pgn_string, browser^)
        }

        if browser.pgn_creation_window.textbox_is_focused{
            if rl.IsKeyPressed(.DOWN) && browser.pgn_creation_window.textbox_cur_line + 1 < len(browser.pgn_creation_window.splitted_strings){
                browser.pgn_creation_window.textbox_cur_line += 1
                timer_reset(&browser.how_long_held_movement_keys)
            }
            if rl.IsKeyDown(.DOWN) && browser.pgn_creation_window.textbox_cur_line + 1 < len(browser.pgn_creation_window.splitted_strings){
                timer_update(&browser.how_long_held_movement_keys, dt)
                if timer_is_finised(browser.how_long_held_movement_keys){
                    browser.pgn_creation_window.textbox_cur_line += 1
                }
            }

            if rl.IsKeyPressed(.UP) && browser.pgn_creation_window.textbox_cur_line - 1 > 0{
                browser.pgn_creation_window.textbox_cur_line -= 1
                timer_reset(&browser.how_long_held_movement_keys)
            }
            if rl.IsKeyDown(.UP) && browser.pgn_creation_window.textbox_cur_line - 1 > 0{
                timer_update(&browser.how_long_held_movement_keys, dt)
                if timer_is_finised(browser.how_long_held_movement_keys){
                    browser.pgn_creation_window.textbox_cur_line -= 1
                }
            }
        }

        //selection circles
        for i in 0..<len(browser.pgn_creation_window.color_sel_circles_pos){
            if rl.CheckCollisionPointCircle(virtual_mouse, browser.pgn_creation_window.color_sel_circles_pos[i], browser.pgn_creation_window.color_sel_circle_radius){
                if i == 0{
                    browser.pgn_creation_window.color_sel_circles_color[0] = rl.LIGHTGRAY
                }
                else{
                    browser.pgn_creation_window.color_sel_circles_color[1] = rl.DARKGRAY
                }
                if rl.IsMouseButtonPressed(.LEFT){
                    browser.pgn_creation_window.selected_circle = i
                }
            }
            else{
                if i == 0{
                    browser.pgn_creation_window.color_sel_circles_color[0] = rl.WHITE
                }
                else{
                    browser.pgn_creation_window.color_sel_circles_color[1] = rl.BLACK

                }
            }
        }
    }
    else{
        if rl.IsKeyPressed(.RIGHT){
            increment_selected_node(browser)

            timer_reset(&browser.how_long_held_movement_keys)
        }
        if rl.IsKeyDown(.RIGHT){
            timer_update(&browser.how_long_held_movement_keys, dt)

            if timer_is_finised(browser.how_long_held_movement_keys){
                increment_selected_node(browser)
            }
        }

        if rl.IsKeyPressed(.LEFT){
            decrement_selected_node(browser)

            timer_reset(&browser.how_long_held_movement_keys)
        }
        if rl.IsKeyDown(.LEFT){
            timer_update(&browser.how_long_held_movement_keys, dt)

            if timer_is_finised(browser.how_long_held_movement_keys){
                decrement_selected_node(browser)
            }
        }

        if rl.IsKeyPressed(.ENTER){
            sel_idx := get_selected_index_in_visible_nodes(browser)
            index_in_nodes := browser.visible_nodes_indicies[sel_idx]

            switch browser.nodes[index_in_nodes].type{
                case .Directory:
                    browser.nodes[index_in_nodes].is_open = !browser.nodes[index_in_nodes].is_open
                    for i in 1..=browser.nodes[index_in_nodes].child_count{
                        browser.nodes[i + index_in_nodes].is_open = browser.nodes[index_in_nodes].is_open
                    }
                    refresh_visible_nodes(browser)
                case .SingleNode, .DirectoryChild:
                    return index_in_nodes 
            }
        }

        if collission_mouse_rect(browser.create_pgn_button.rect, virtual_mouse){
            browser.create_pgn_button.cur_color = browser.create_pgn_button.color_hovered
        }
        else{
            browser.create_pgn_button.cur_color = browser.create_pgn_button.color_normal
        }

        if collission_mouse_rect(browser.create_pgn_button.rect, virtual_mouse) && rl.IsMouseButtonPressed(.LEFT) || rl.IsKeyPressed(.S){
            browser.pgn_creation_window.is_open = true
            browser.create_pgn_button.cur_color = browser.create_pgn_button.color_normal
        }
    }
    return -1
}

SINGLE_NODE_SIZE := rl.Vector2{game_size.x * 0.4, 100}
SELECTED_NODE_SIZE := rl.Vector2{game_size.x * 0.45, 130}
DIRECTORY_NODE_SIZE := rl.Vector2{game_size.x * 0.5, 150}
DIRECTORY_CHILD_NODE_SIZE := rl.Vector2{game_size.x * 0.35, 80}

calculate_gap :: proc(single_nodes, selected_node, directory_nodes, directory_child_nodes: int) -> f32{
    item_count := single_nodes + selected_node + directory_child_nodes + directory_nodes
    gap := (game_size.y - SINGLE_NODE_SIZE.y * f32(single_nodes) - SELECTED_NODE_SIZE.y * f32(selected_node) - DIRECTORY_NODE_SIZE.y * f32(directory_nodes) - DIRECTORY_CHILD_NODE_SIZE.y * f32(directory_child_nodes)) / f32(item_count + 1)
    if gap <= 0.0{
        fmt.println("[calculate gap] Gap is too small")
    }
    return gap
}

browser_render :: proc(browser: ^Browser){
    //------- RENDERING NODES

    //count 
    single_nodes, selected_node, directory_nodes, directory_child_nodes: int
    for index in browser.visible_nodes_indicies{
        if browser.nodes[index].is_selected{
            selected_node += 1
            continue
        }

        switch browser.nodes[index].type{
            case .Directory:
                if browser.nodes[index].is_open{
                    directory_nodes += 1
                }
                else{
                    single_nodes += 1
                }
            case .DirectoryChild:
                directory_child_nodes += 1
            case .SingleNode:
                single_nodes += 1
        }
    }

    gap := calculate_gap(single_nodes, selected_node, directory_nodes, directory_child_nodes)

    b := strings.builder_make()
    defer strings.builder_destroy(&b)

    next_y_pos := gap 
    for index, i in browser.visible_nodes_indicies{
        pos: rl.Vector2

        if browser.nodes[index].is_selected{
            pos = rl.Vector2{game_size.x - SELECTED_NODE_SIZE.x, next_y_pos}

            if browser.nodes[index].type == .Directory && !browser.nodes[index].is_open{
                rl.DrawRectangleV(pos, SELECTED_NODE_SIZE, rl.ORANGE)
            }
            else if browser.nodes[index].type == .Directory && browser.nodes[index].is_open{
                rl.DrawRectangleV(pos, SELECTED_NODE_SIZE, rl.LIME)
            }
            else{
                rl.DrawRectangleV(pos, SELECTED_NODE_SIZE, rl.WHITE)
            }
            next_y_pos += (gap + SELECTED_NODE_SIZE.y)


            strings.builder_reset(&b)
            strings.write_int(&b, index)
            strings.write_string(&b, ". ")
            strings.write_string(&b, browser.nodes[index].name)
            rl.DrawText(strings.to_cstring(&b), i32(pos.x + 40), i32(pos.y + 20), 45, rl.BLACK)

            continue
        }

        switch browser.nodes[index].type{
            case .SingleNode:
                pos = rl.Vector2{game_size.x - SINGLE_NODE_SIZE.x, next_y_pos}
                rl.DrawRectangleV(pos, SINGLE_NODE_SIZE, rl.BLACK)
                next_y_pos += (gap + SINGLE_NODE_SIZE.y)
            case .Directory:
                if browser.nodes[index].is_open{
                    pos = rl.Vector2{game_size.x - DIRECTORY_NODE_SIZE.x, next_y_pos}
                    rl.DrawRectangleV(pos, DIRECTORY_NODE_SIZE, rl.LIME)
                    next_y_pos += (gap + DIRECTORY_NODE_SIZE.y)
                }
                else{
                    pos = rl.Vector2{game_size.x - SINGLE_NODE_SIZE.x, next_y_pos}
                    rl.DrawRectangleV(pos, SINGLE_NODE_SIZE, rl.ORANGE)
                    next_y_pos += (gap + SINGLE_NODE_SIZE.y)
                }
            case .DirectoryChild:
                pos = rl.Vector2{game_size.x - DIRECTORY_CHILD_NODE_SIZE.x, next_y_pos}
                rl.DrawRectangleV(pos, DIRECTORY_CHILD_NODE_SIZE, rl.RED)
                next_y_pos += (gap + DIRECTORY_CHILD_NODE_SIZE.y)
        }
        strings.builder_reset(&b)
        strings.write_int(&b, index)
        strings.write_string(&b, ". ")
        strings.write_string(&b, browser.nodes[index].name)
        rl.DrawText(strings.to_cstring(&b), i32(pos.x + 40), i32(pos.y + 20), 45, rl.WHITE)
    }

    //-----------
    rl.DrawRectangleRec(browser.create_pgn_button.rect, browser.create_pgn_button.cur_color)

    if browser.pgn_creation_window.is_open{
        rl.DrawRectangleRec({0, 0, game_size.x, game_size.y}, rl.Color{255, 255, 255, 50})
        window := browser.pgn_creation_window
        rl.DrawRectangleRec(window.background, rl.BROWN)

        //-----filename_box
        rl.DrawRectangleRec(window.filename_box, rl.BLACK)

        //generating text inside filename_box
        filename_text: cstring
        generating_filename_text := false
        if len(window.filename_builder.buf) == 0 && !window.filename_box_is_focused{
            filename_text = "Click to name the file..."
        }
        else{
            filename_text, _ = strings.clone_to_cstring(strings.to_string(window.filename_builder), context.allocator)
            generating_filename_text = true
        }
        pos := center_text_in_rect(filename_text, window.filename_box, window.filename_text_size)
        rl.DrawText(filename_text, pos.x, pos.y, window.filename_text_size, rl.LIGHTGRAY) 
        if generating_filename_text{
            defer delete(filename_text)
            if len(window.filename_builder.buf) < window.max_filename_length && window.show_underscore && window.filename_box_is_focused{
                rl.DrawText("_", pos.x + rl.MeasureText(filename_text, window.filename_text_size) + 10, pos.y, window.filename_text_size, rl.LIGHTGRAY)
            }
        }

        //----textbox
        rl.DrawRectangleRec(window.textbox, rl.BLACK)

        if len(window.splitted_strings) == 0 && !window.textbox_is_focused{
            rl.DrawText("Paste your pgn from clipboard here...", i32(window.textbox.x + 10), i32(window.textbox.y + 10), window.textbox_text_size, rl.LIGHTGRAY) 
        }
        else{
            y_offset: f32
            for str, i in window.splitted_strings[window.textbox_cur_line:]{
                pos := [2]i32{i32(window.textbox.x + 10), i32(window.textbox.y + 10 + y_offset)}
                if pos.y + window.textbox_text_size > i32(window.textbox.height + window.textbox.y){
                    break
                }
                y_offset += f32(window.textbox_text_size + 2)
                //rl.DrawRectangleV({f32(pos.x), f32(pos.y)}, {f32(rl.MeasureText(str, window.textbox_text_size)), f32(window.textbox_text_size + 2)}, get_color(i, 200))
                rl.DrawText(str, pos.x, pos.y, window.textbox_text_size, rl.LIGHTGRAY) 

            }
        }

        //selection circles
        rl.DrawCircleV(window.color_sel_circles_pos[window.selected_circle], window.color_sel_circle_radius + 7.0, rl.LIME)
        for circ, i in window.color_sel_circles_pos{
            rl.DrawCircleV(circ, window.color_sel_circle_radius, window.color_sel_circles_color[i]) 
            rl.DrawCircleV(circ, window.color_sel_circle_radius, window.color_sel_circles_color[i])
        }

        //-----create_rect
        rl.DrawRectangleRec(window.create_rect, window.create_cur_color)
        text_pos:= center_text_in_rect("CREATE", window.create_rect, 60)
        rl.DrawText("CREATE", text_pos.x, text_pos.y, 60, rl.WHITE)
    }
}

split_textbox_string :: proc(str: string, browser: Browser) -> [dynamic]cstring{
    splitted_strings := make([dynamic]cstring, context.allocator)
    prev_idx := 0
    in_header := false
    for i in 0..<len(str){
        switch str[i]{
            case '\n':
                append(&splitted_strings, strings.clone_to_cstring(str[prev_idx:i+1]))
                prev_idx = i + 1 //skipping '\n'
                continue
            case '[':
                in_header = true
            case ']':
                in_header = false

        }

        //this is stupidly memory inefficient but whatever
        cstr := strings.clone_to_cstring(str[prev_idx:i])
        defer delete(cstr)

        //(browser.pgn_creation_window.textbox.width - 40) because of padding of 20 on both sides
        if rl.MeasureText(cstr, browser.pgn_creation_window.textbox_text_size) >= i32(browser.pgn_creation_window.textbox.width - 40){
            //if in header split lines afer backslash
            if in_header{
                idx_of_last_backslash := i
                for idx_of_last_backslash > 0{
                    if str[idx_of_last_backslash] == '/'{
                        break
                    }
                    else if str[idx_of_last_backslash] == '['{
                        idx_of_last_backslash = 0
                        break
                    }
                    idx_of_last_backslash -= 1
                }
                //there wasn't any backlash between square brackets 
                //so we will just split the string based on the max_character_per_line
                if idx_of_last_backslash == 0{
                    append(&splitted_strings, strings.clone_to_cstring(str[prev_idx:i]))
                    prev_idx = i 
                }
                else{
                    append(&splitted_strings, strings.clone_to_cstring(str[prev_idx:idx_of_last_backslash + 1]))
                    prev_idx = idx_of_last_backslash + 1
                }
            }
            else{   //if not in header split lines before the move count 
                append(&splitted_strings, strings.clone_to_cstring(str[prev_idx:i]))
                prev_idx = i
            }
        }
    }
    if len(splitted_strings) == 0{
        append(&splitted_strings, strings.clone_to_cstring(str))
    }
    return splitted_strings
}

write_pgn :: proc(browser: ^Browser) -> bool{
    filename := strings.to_string(browser.pgn_creation_window.filename_builder)
    for node in browser.nodes{
        if remove_extension_from_string(node.name) == filename{
            return false
        }
    }
    str := strings.concatenate({"res/pgn/", filename, ".pgn"})
    defer delete(str)

    //add header for deciding which color the user picked
    raw_string := browser.pgn_creation_window.textbox_string_raw
    idx_of_last_header := len(raw_string) - 1
    for idx_of_last_header > 0{
        if raw_string[idx_of_last_header] == ']'{
            idx_of_last_header += 1
            break
        }
        idx_of_last_header -= 1
    }
    b := strings.builder_make()
    defer strings.builder_destroy(&b)

    strings.write_string(&b, raw_string[:idx_of_last_header])

    if idx_of_last_header != 0{
        strings.write_rune(&b, '\n')
    }

    if browser.pgn_creation_window.selected_circle == 0{
        strings.write_string(&b, "[Picked White]")
    }
    else{
        strings.write_string(&b, "[Picked Black]")
    }

    if idx_of_last_header == 0{
        strings.write_rune(&b, '\n')
    }

    strings.write_string(&b, raw_string[idx_of_last_header:])

    err := os.write_entire_file_from_string(str, strings.to_string(b))
    return err == os.General_Error.None
}

get_selected_index_in_visible_nodes :: proc(browser: ^Browser) -> int{
    for index, i in browser.visible_nodes_indicies{
        if browser.nodes[index].is_selected{
            return i
        }
    }
    assert(false, "There should be at least one node that is selected")
    return -1
}

increment_selected_node :: proc(browser: ^Browser){
    idx := get_selected_index_in_visible_nodes(browser)
    if idx >= MAX_VISIBLE_NODE_AMOUNT - 1{
        children_in_closed_dirs := 0
        for i in browser.pivot..<len(browser.nodes){
            if browser.nodes[i].type == .DirectoryChild && !browser.nodes[i].is_open{
                children_in_closed_dirs += 1
            }
        }
        if browser.pivot + MAX_VISIBLE_NODE_AMOUNT + children_in_closed_dirs < len(browser.nodes){
            browser.pivot += 1
            refresh_visible_nodes(browser)
            browser.nodes[browser.visible_nodes_indicies[MAX_VISIBLE_NODE_AMOUNT - 2]].is_selected = false
            browser.nodes[browser.visible_nodes_indicies[MAX_VISIBLE_NODE_AMOUNT - 1]].is_selected = true
        }
    }
    else{
        browser.nodes[browser.visible_nodes_indicies[idx]].is_selected = false
        browser.nodes[browser.visible_nodes_indicies[idx + 1]].is_selected = true
    }
}

decrement_selected_node :: proc(browser: ^Browser){
    idx := get_selected_index_in_visible_nodes(browser)
    if idx <= 0{
        if browser.pivot > 0{
            browser.pivot -= 1
            refresh_visible_nodes(browser)
            browser.nodes[browser.visible_nodes_indicies[0]].is_selected = true
            browser.nodes[browser.visible_nodes_indicies[1]].is_selected = false
        }
    }
    else{
        browser.nodes[browser.visible_nodes_indicies[idx]].is_selected = false
        browser.nodes[browser.visible_nodes_indicies[idx - 1]].is_selected = true
    }
}

refresh_visible_nodes :: proc(browser: ^Browser){
    dir_children_offset := 0

    //prepass to check if there is a DirectoryChild of a closed directory that we need to skip
    sel_idx := get_selected_index_in_visible_nodes(browser)
    for browser.nodes[browser.pivot].type == .DirectoryChild && !browser.nodes[browser.pivot].is_open{
        if sel_idx == MAX_VISIBLE_NODE_AMOUNT - 1{
            browser.pivot += 1
        }
        else if sel_idx == 0{
            browser.pivot -= 1
        }
        else{
            assert(false, "I want to check if you can get into this branch. I think not but idk")
        }
    }


    visible_node_indicies_cpy := browser.visible_nodes_indicies
    for i in 0..<MAX_VISIBLE_NODE_AMOUNT{
        index := i + dir_children_offset + browser.pivot

        //happens when we want to close a directory near the end of the nodes 
        //such that if we would close it there wouldn't be enough indicies from pivot to the end of nodes
        //to fill up browser.visible_nodes. That's why we move pivot one spot earlier and try to generate
        //visible_nodes again
        if index >= len(browser.nodes){
            browser.visible_nodes_indicies = visible_node_indicies_cpy
            browser.pivot -= 1
            refresh_visible_nodes(browser)
            return
        }

        browser.visible_nodes_indicies[i] = index        
        if browser.nodes[index].type == .Directory && !browser.nodes[index].is_open{
            dir_children_offset += browser.nodes[index].child_count
        }
    }
}
