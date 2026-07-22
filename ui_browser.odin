package main

import "core:os"
import "core:strings"
import "core:fmt"

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

Browser :: struct{
    nodes: [dynamic]Node,
    visible_nodes_indicies: [MAX_VISIBLE_NODE_AMOUNT]int,
    pivot: int,
}


browser_create :: proc() -> (Browser, bool){
    browser: Browser
    browser.nodes = make([dynamic]Node, context.allocator)

    //loading file names and checking for nested directories
    path := "res/pgn"
    file_infos, err := os.read_all_directory_by_path(path, context.allocator)
    defer os.file_info_slice_delete(file_infos, context.allocator)

    file_infos_sorted := sort_file_infos(file_infos)
    defer delete(file_infos_sorted)

    if err != nil{
        fmt.println(err)
        return {}, false
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
                return {}, false
            }

            append(&browser.nodes, Node{name = name, type = .Directory})
            dir_index := len(browser.nodes) - 1

            for directory_file_info in dir_infos_sorted{
                child_name := strings.clone(directory_file_info.name)

                if directory_file_info.type == .Directory{
                    fmt.println("[browser_create] cannot have a directory inside a directory")
                    return {}, false
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

    browser.nodes[0].is_selected = true
    refresh_visible_nodes(&browser)
    return browser, true
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
        browser.pivot += 1
        refresh_visible_nodes(browser)
        browser.nodes[browser.visible_nodes_indicies[MAX_VISIBLE_NODE_AMOUNT - 2]].is_selected = false
        browser.nodes[browser.visible_nodes_indicies[MAX_VISIBLE_NODE_AMOUNT - 1]].is_selected = true
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

    for i in 0..<MAX_VISIBLE_NODE_AMOUNT{
        index := i + dir_children_offset + browser.pivot

        browser.visible_nodes_indicies[i] = index        
        if browser.nodes[index].type == .Directory && !browser.nodes[index].is_open{
            dir_children_offset += browser.nodes[index].child_count
        }
    }
}

browser_update :: proc(browser: ^Browser){
    if rl.IsKeyPressed(.RIGHT){
        increment_selected_node(browser)
    }
    if rl.IsKeyPressed(.LEFT){
        decrement_selected_node(browser)
    }


    if rl.IsKeyPressed(.ENTER){
        sel_idx := get_selected_index_in_visible_nodes(browser)
        index_in_nodes := browser.visible_nodes_indicies[sel_idx]

        if browser.nodes[index_in_nodes].type == .Directory{
            browser.nodes[index_in_nodes].is_open = !browser.nodes[index_in_nodes].is_open
            for i in 1..=browser.nodes[index_in_nodes].child_count{
                browser.nodes[i + index_in_nodes].is_open = browser.nodes[index_in_nodes].is_open
            }
            refresh_visible_nodes(browser)
        }
    }
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
}