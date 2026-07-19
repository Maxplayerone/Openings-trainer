package main

import "core:os"
import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

SingleNode :: struct{
    name: string,
}

Directory :: struct{
    name: string,
    is_open: bool,
    children: [dynamic]SingleNode,
}

Node :: union{
    SingleNode,
    Directory,
}

NodeType :: enum{
    Directory,
    DirectoryChild,
    SingleNode,
}

VisibleNode :: struct{
    name: string, 
    number: int,
    type: NodeType,
    is_selected: bool,
}

MAX_VISIBLE_NODE_AMOUNT :: 12

Browser :: struct{
    nodes: [dynamic]Node,
    visible_nodes: [MAX_VISIBLE_NODE_AMOUNT]VisibleNode,
    global_selected_node_index: int,
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
            if err != nil{
                fmt.println(err)
                return {}, false
            }

            directory_node := Directory{
                name = name,
            }
            directory_node.children = make([dynamic]SingleNode, context.allocator)

            for directory_file_info in directory_infos{
                child_name := strings.clone(directory_file_info.name)
                if directory_file_info.type == .Directory{
                    fmt.println("[browser_create] cannot have a directory inside a directory")
                    return {}, false
                }
                else{
                    append(&directory_node.children, SingleNode{child_name})
                }
            }
            os.file_info_slice_delete(directory_infos, context.allocator)
            append(&browser.nodes, directory_node)
        }
        else{
            append(&browser.nodes, SingleNode{name})
        }
    }

    //populating the visible_node array
    length := len(browser.nodes) >= len(browser.visible_nodes) ? len(browser.visible_nodes) : len(browser.nodes)
    for i in 0..<length{
        switch n in browser.nodes[i]{
            case SingleNode:
                browser.visible_nodes[i].name = n.name
                browser.visible_nodes[i].type = .SingleNode
            case Directory:
                if n.is_open{
                    assert(false)
                }
                else{
                    browser.visible_nodes[i].name = n.name
                    browser.visible_nodes[i].type = .Directory
                }
        }
        browser.visible_nodes[i].number = i
    }

    browser.visible_nodes[0].is_selected = true
    return browser, true
}

get_selected_node_index :: proc(visible_nodes: []VisibleNode) -> int{
    for node, i in visible_nodes{
        if node.is_selected{
            return i
        }
    }
    assert(false, "We have to have a selected node")
    return -1
}

shift_visible_nodes_up :: proc(browser: ^Browser){
    if browser.global_selected_node_index <= 0{
        return
    }

    browser.global_selected_node_index -= 1

    for i in 0..<MAX_VISIBLE_NODE_AMOUNT{
        switch n in browser.nodes[browser.global_selected_node_index + i]{
            case SingleNode:
                browser.visible_nodes[i].type = .SingleNode 
                browser.visible_nodes[i].name = n.name 
            case Directory:
                browser.visible_nodes[i].type = .Directory 
                browser.visible_nodes[i].name = n.name 

        }
        browser.visible_nodes[i].number = browser.global_selected_node_index + i
    }
    browser.visible_nodes[0].is_selected = true
}

shift_visible_nodes_down :: proc(browser: ^Browser){
    if browser.global_selected_node_index + 1 >= len(browser.nodes){
        return
    }

    browser.global_selected_node_index += 1
    starting_index := browser.global_selected_node_index - MAX_VISIBLE_NODE_AMOUNT + 1

    for i in 0..<MAX_VISIBLE_NODE_AMOUNT{
        switch n in browser.nodes[starting_index + i]{
            case SingleNode:
                browser.visible_nodes[i].type = .SingleNode 
                browser.visible_nodes[i].name = n.name 
            case Directory:
                browser.visible_nodes[i].type = .Directory 
                browser.visible_nodes[i].name = n.name 

        }
        browser.visible_nodes[i].number = starting_index + i
    }
    browser.visible_nodes[MAX_VISIBLE_NODE_AMOUNT - 1].is_selected = true
}

increment_visible_selected_node :: proc(browser: ^Browser){
    selected_index := get_selected_node_index(browser.visible_nodes[:])
    if selected_index + 1 == MAX_VISIBLE_NODE_AMOUNT{ //we want to increment the selected index so we check if the next positions if out of bounds 
        shift_visible_nodes_down(browser)
    }
    else{
        browser.visible_nodes[selected_index].is_selected = false
        browser.visible_nodes[selected_index + 1].is_selected = true
        browser.global_selected_node_index += 1
    }
}

decrement_visible_selected_node :: proc(browser: ^Browser){
    selected_index := get_selected_node_index(browser.visible_nodes[:])
    if selected_index == 0{
        shift_visible_nodes_up(browser)
    }
    else{
        browser.visible_nodes[selected_index].is_selected = false
        browser.visible_nodes[selected_index - 1].is_selected = true
        browser.global_selected_node_index -= 1
    }
}

browser_update :: proc(browser: ^Browser){
    if rl.IsKeyPressed(.RIGHT){
        increment_visible_selected_node(browser)
    }
    if rl.IsKeyPressed(.LEFT){
        decrement_visible_selected_node(browser)
    }
}

SINGLE_NODE_SIZE := rl.Vector2{game_size.x * 0.4, 100}
SELECTED_NODE_SIZE := rl.Vector2{game_size.x * 0.45, 130}
DIRECTORY_NODE_SIZE := rl.Vector2{game_size.x * 0.45, 130}
DIRECTORY_CHILD_NODE_SIZE := rl.Vector2{game_size.x * 0.45, 130}

calculate_gap :: proc(single_nodes, selected_node, directory_nodes, directory_child_nodes: int) -> f32{
    item_count := single_nodes + selected_node + directory_child_nodes + directory_nodes
    gap := (game_size.y - SINGLE_NODE_SIZE.y * f32(single_nodes) - SELECTED_NODE_SIZE.y * f32(selected_node) - DIRECTORY_NODE_SIZE.y * f32(directory_nodes) - DIRECTORY_CHILD_NODE_SIZE.y * f32(directory_child_nodes)) / f32(item_count + 1)
    if gap <= 0.0{
        fmt.println("[calculate gap] Gap is too small")
    }
    return gap
}

browser_render :: proc(browser: ^Browser){
    gap := calculate_gap(MAX_VISIBLE_NODE_AMOUNT, 0, 0, 0)
    selected_node_index := get_selected_node_index(browser.visible_nodes[:])

    b := strings.builder_make()
    defer strings.builder_destroy(&b)

    for node, i in browser.visible_nodes{
        name := node.name
        if selected_node_index > i{
            pos := rl.Vector2{game_size.x - SINGLE_NODE_SIZE.x, gap + (gap + SINGLE_NODE_SIZE.y) * f32(i)}
            rl.DrawRectangleV(pos, SINGLE_NODE_SIZE, rl.BLACK)

            strings.builder_reset(&b)
            strings.write_int(&b, browser.visible_nodes[i].number)
            strings.write_string(&b, ". ")
            strings.write_string(&b, name)
            rl.DrawText(strings.to_cstring(&b), i32(pos.x + 40), i32(pos.y + 40), 45, rl.WHITE)
        }
        else if selected_node_index == i{
            pos := rl.Vector2{game_size.x - SELECTED_NODE_SIZE.x, gap + (gap + SINGLE_NODE_SIZE.y) * f32(i)}
            rl.DrawRectangleV(pos, SELECTED_NODE_SIZE, rl.WHITE)

            strings.builder_reset(&b)
            strings.write_int(&b, browser.visible_nodes[i].number)
            strings.write_string(&b, ". ")
            strings.write_string(&b, name)
            rl.DrawText(strings.to_cstring(&b), i32(pos.x + 40), i32(pos.y + 40), 45, rl.BLACK)
        }
        else{
            pos := rl.Vector2{game_size.x - SINGLE_NODE_SIZE.x, gap + (gap + SINGLE_NODE_SIZE.y) * f32(i - 1) + (gap + SELECTED_NODE_SIZE.y)}
            rl.DrawRectangleV(pos, SINGLE_NODE_SIZE, rl.BLACK)

            strings.builder_reset(&b)
            strings.write_int(&b, browser.visible_nodes[i].number)
            strings.write_string(&b, ". ")
            strings.write_string(&b, name)
            rl.DrawText(strings.to_cstring(&b), i32(pos.x + 40), i32(pos.y + 40), 45, rl.WHITE)
        }

    }
}