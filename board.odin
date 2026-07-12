package main

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

TILE_COLOR_DARK := rl.Color{115, 149, 82, 255}
TILE_COLOR_LIGHT := rl.Color{235, 236, 208, 255}
TILE_COLOR_ACTIVE_DARK := rl.Color{185, 202, 66, 255}
TILE_COLOR_ACTIVE_LIGHT := rl.Color{245, 246, 129, 255}
TILE_COLOR_MISTAKE := rl.Color{250, 101, 115, 255}
TILE_COLOR_MISTAKE_MODIFIABLE := TILE_COLOR_MISTAKE

Tile :: struct{
    color: rl.Color,
    pos: [2]f32,
}

PieceType :: enum{
    None,
    Pawn,
    Rook,
    Knight,
    Bishop,
    Queen,
    King,
}

Piece :: struct{
    type: PieceType,
    is_white: bool,
}

Board :: struct{
    tile_size: f32,
    tiles: [64]Tile,

    pieces: [64]Piece,
    pieces_texture: rl.Texture2D,

    moves: [dynamic]Move,
    moves_cursor: int,

    move_forward_timer: Timer,
    move_backward_timer: Timer,

    held_piece: Piece, 
    held_piece_index: int,

    placed_piece_on_incorrect_tile_timer: Timer,
    placed_piece_on_incorrect_tile_index: int,

    mistakes_count: int,
    finished_pgn: bool,
}

board_create :: proc(filename := "res/fen/default.fen") -> Board{
    board := Board{}
    board.tile_size = 140 
    for i := 0; i < 8; i += 1{
        for j := 0; j < 8; j += 1{
            color := rl.Color{}
            if (i + j) % 2 == 1{
                color = TILE_COLOR_DARK 
            }
            else{
                color = TILE_COLOR_LIGHT 
            }

            tile := Tile{
                color = color,
                pos = [2]f32{400 + f32(j) * board.tile_size, 200 + f32(i) * board.tile_size}
            }
            board.tiles[i * 8 + j] = tile
        }
    }

    board.pieces_texture = rl.LoadTexture("res/textures/pieces.png")
    assert(board.pieces_texture.width != 0, "[board_create function] cannot load texture")
    assert(read_fen(filename, &board.pieces))

    board.held_piece_index = -1

    board.move_forward_timer = timer_create(0.15, finished_at_the_start = true)
    board.move_backward_timer = timer_create(0.15, finished_at_the_start = true)
    board.placed_piece_on_incorrect_tile_timer = timer_create(0.3, finished_at_the_start = true)
    return board
}

board_update :: proc(board: ^Board, mouse: rl.Vector2, dt: f64){
    //keyboard movement
    if !board.finished_pgn && rl.IsKeyDown(.RIGHT) && board.moves_cursor < len(board.moves) && timer_is_finised(board.move_forward_timer){
        move := board.moves[board.moves_cursor]
        board.moves_cursor += 1
        move_pieces_forward(&board.pieces, move)

        timer_reset(&board.move_forward_timer)
    }
    if !board.finished_pgn && rl.IsKeyDown(.LEFT) && board.moves_cursor > 0 && timer_is_finised(board.move_backward_timer){
        board.moves_cursor -= 1
        last_move := board.moves[board.moves_cursor]
        move_pieces_backward(&board.pieces, last_move)

        timer_reset(&board.move_backward_timer)
    } 

    //mouse movement
    if !board.finished_pgn && rl.IsMouseButtonDown(.LEFT) && board.held_piece_index == -1{
        if index := mouse_pos_to_board_index(board.tiles[:], board.tile_size, mouse); index != -1 && board.pieces[index].type != .None{
            board.held_piece = board.pieces[index]
            board.held_piece_index = index
            board.pieces[index] = Piece{.None, false}
        }
    }

    if !board.finished_pgn && rl.IsMouseButtonReleased(.LEFT) && board.held_piece_index != -1{
        index := mouse_pos_to_board_index(board.tiles[:], board.tile_size, mouse)

        //if we put a piece outside the board 
        if index == -1{
            board.pieces[board.held_piece_index] = board.held_piece
        }
        else if board.moves[board.moves_cursor].to != index{
            board.pieces[board.held_piece_index] = board.held_piece

            board.placed_piece_on_incorrect_tile_index = index
            timer_reset(&board.placed_piece_on_incorrect_tile_timer)
            TILE_COLOR_MISTAKE_MODIFIABLE = TILE_COLOR_MISTAKE

            board.mistakes_count += 1
        }
        else{
            board.pieces[index] = board.held_piece
            board.moves_cursor += 1
        }

        board.held_piece_index = -1
    }

    //timers
    timer_update(&board.move_forward_timer, dt)
    timer_update(&board.move_backward_timer, dt)
    timer_update(&board.placed_piece_on_incorrect_tile_timer, dt)
    TILE_COLOR_MISTAKE_MODIFIABLE.a = u8(255 * (1.0 - timer_percentage_time_elapsed(board.placed_piece_on_incorrect_tile_timer)))

    //other
    if board.moves_cursor >= len(board.moves){
        board.finished_pgn = true
    }
}

board_render :: proc(board: ^Board, mouse: rl.Vector2){
    for tile in board.tiles{
        rl.DrawRectangleRec({tile.pos.x, tile.pos.y, board.tile_size, board.tile_size}, tile.color)
    }

    //highlight the from and to tile when moving with arrows
    if board.moves_cursor > 0{
        last_move := board.moves[board.moves_cursor - 1]
        if last_move.from > 63{
            highlight_tile_castles(board^, last_move.from)
        }
        else{
            highlight_tile(board^, last_move.from) 
            highlight_tile(board^, last_move.to) 
        }
    } 

    //highlight tile when placed piece incorrectly
    if !timer_is_finised(board.placed_piece_on_incorrect_tile_timer){
        tile := board.tiles[board.placed_piece_on_incorrect_tile_index]
        rl.DrawRectangleRec({tile.pos.x, tile.pos.y, board.tile_size, board.tile_size}, TILE_COLOR_MISTAKE_MODIFIABLE)
    }

    //draw pieces textures
    for piece, i in board.pieces{
        if piece.type == .None{
            continue
        }

        rl.DrawTexturePro(board.pieces_texture, 
            piece_type_to_texture_source_rect(piece),
            {board.tiles[i].pos.x, board.tiles[i].pos.y, board.tile_size, board.tile_size}, 
            {0.0, 0.0}, 0.0, rl.WHITE)
    }

    //draw held piece
    if board.held_piece_index != -1{
        //highlight the file from which we picked up the piece
        highlight_tile(board^, board.held_piece_index)

        rl.DrawTexturePro(board.pieces_texture, 
            piece_type_to_texture_source_rect(board.held_piece),
            {mouse.x - board.tile_size / 2, mouse.y - board.tile_size / 2, board.tile_size, board.tile_size}, 
            {0.0, 0.0}, 0.0, rl.WHITE)
    }

    //draw results panel
    if board.finished_pgn{
        rl.DrawRectangleRec({0, 0, game_size.x, game_size.y}, {0, 0, 0, 50})
        result_panel := rl.Rectangle{game_size.x / 3, game_size.y / 10 * 2, game_size.x /3, game_size.y / 10 * 6}
        rl.DrawRectangleRec(result_panel, {192, 186, 187, 255})
        rl.DrawRectangleLinesEx(result_panel, 8.0, rl.WHITE)

        b := strings.builder_make(context.temp_allocator)

        strings.write_string(&b, "Amount of mistakes: ")
        strings.write_int(&b, board.mistakes_count)
        rl.DrawText(strings.clone_to_cstring(strings.to_string(b), context.temp_allocator), i32(game_size.x / 3 * 1.1), i32(game_size.y / 10 * 4), 45, rl.WHITE)
    }
}

highlight_tile :: proc(board: Board, tile_index: int){
    tile := board.tiles[tile_index]
    if tile.color == TILE_COLOR_DARK{
        rl.DrawRectangleRec(to_rect(tile.pos, board.tile_size), TILE_COLOR_ACTIVE_DARK)
    }
    else{
        rl.DrawRectangleRec(to_rect(tile.pos, board.tile_size), TILE_COLOR_ACTIVE_LIGHT)
    }
    //rl.DrawRectangleLinesEx(to_rect(tile.pos, board.tile_size), 5.0, rl.WHITE)
}

highlight_tile_castles :: proc(board: Board, tile_index: int){
    if tile_index == 64{
        highlight_tile(board, coordinate_to_index("e1")) 
        highlight_tile(board, coordinate_to_index("g1")) 
    }
    else if tile_index == 65{
        highlight_tile(board, coordinate_to_index("e8")) 
        highlight_tile(board, coordinate_to_index("g8")) 
    }
    else if tile_index == 66{
        highlight_tile(board, coordinate_to_index("e1")) 
        highlight_tile(board, coordinate_to_index("c1")) 
    }
    else if tile_index == 67{
        highlight_tile(board, coordinate_to_index("e8")) 
        highlight_tile(board, coordinate_to_index("c8")) 
    }
    else{
        assert(false, "Incorrect use of the function")
    }
}

move_pieces_forward :: proc(pieces: ^[64]Piece, move: Move){
    //castles indicies:
    //64 - white short
    //65 - black short
    //66 - white long
    //67 - black long
    if move.from == 64 && move.to == 64{
        pieces[coordinate_to_index("e1")] = piece_none() 
        pieces[coordinate_to_index("h1")] = piece_none() 
        pieces[coordinate_to_index("f1")] = Piece{.Rook, true}
        pieces[coordinate_to_index("g1")] = Piece{.King, true}
    }
    else if move.from == 65 && move.to == 65{
        pieces[coordinate_to_index("e8")] = piece_none() 
        pieces[coordinate_to_index("h8")] = piece_none() 
        pieces[coordinate_to_index("f8")] = Piece{.Rook, false}
        pieces[coordinate_to_index("g8")] = Piece{.King, false}
    }
    else if move.from == 66 && move.to == 66{
        pieces[coordinate_to_index("e1")] = piece_none() 
        pieces[coordinate_to_index("a1")] = piece_none() 
        pieces[coordinate_to_index("d1")] = Piece{.Rook, true}
        pieces[coordinate_to_index("c1")] = Piece{.King, true}
    }
    else if move.from == 67 && move.to == 67{
        pieces[coordinate_to_index("e8")] = piece_none() 
        pieces[coordinate_to_index("a8")] = piece_none() 
        pieces[coordinate_to_index("d8")] = Piece{.Rook, false}
        pieces[coordinate_to_index("c8")] = Piece{.King, false}
    }
    else{
        tmp := pieces[move.from] 
        pieces[move.from] = piece_none() 
        if move.promoted == piece_none(){
            pieces[move.to] = tmp
        }
        else{
            pieces[move.to] = move.promoted
        }

        if move.en_passant && tmp.is_white{
            pieces[move.to + 8] = piece_none()
        }
        if move.en_passant && !tmp.is_white{
            pieces[move.to - 8] = piece_none()
        }
    }
}

move_pieces_backward :: proc(pieces: ^[64]Piece, move: Move){
    if move.from == 64{
        pieces[coordinate_to_index("e1")] = Piece{.King, true}
        pieces[coordinate_to_index("h1")] = Piece{.Rook, true}
        pieces[coordinate_to_index("f1")] = piece_none() 
        pieces[coordinate_to_index("g1")] = piece_none() 
    }
    else if move.from == 65{
        pieces[coordinate_to_index("e8")] = Piece{.King, false}
        pieces[coordinate_to_index("h8")] = Piece{.Rook, false}
        pieces[coordinate_to_index("f8")] = piece_none() 
        pieces[coordinate_to_index("g8")] = piece_none() 
    }
    else if move.from == 66{
        pieces[coordinate_to_index("e1")] = Piece{.King, true}
        pieces[coordinate_to_index("a1")] = Piece{.Rook, true}
        pieces[coordinate_to_index("c1")] = piece_none() 
        pieces[coordinate_to_index("d1")] = piece_none() 
    }
    else if move.from == 67{
        pieces[coordinate_to_index("e8")] = Piece{.King, false}
        pieces[coordinate_to_index("a8")] = Piece{.Rook, false}
        pieces[coordinate_to_index("c8")] = piece_none() 
        pieces[coordinate_to_index("d8")] = piece_none() 
    }
    else{
        tmp := pieces[move.to]
        pieces[move.to] = move.captured
        if move.promoted == piece_none(){
            pieces[move.from] = tmp 
        }
        else{
            pieces[move.from] = Piece{.Pawn, move.promoted.is_white}
        }

        if move.en_passant && tmp.is_white{
            pieces[move.to + 8] = Piece{.Pawn, false} 
        }
        if move.en_passant && !tmp.is_white{
            pieces[move.to - 8] = Piece{.Pawn, true} 
        }
    }
}

mouse_pos_to_board_index :: proc(tiles: []Tile, tile_size: f32, mouse: rl.Vector2) -> int{
    for tile, i in tiles{
        if collission_mouse_rect(to_rect(tile.pos, tile_size), mouse){
            return i
        }
    }
    return -1
}

coordinate_to_index :: proc(coordinate: string) -> int{
    if len(coordinate) != 2 || !(coordinate[0] >= 'a' && coordinate[0] <= 'h') || !(coordinate[1] >= '1' && coordinate[1] <= '8'){
        assert(false, "[Error in coordinate to index] Got wrong coordinate")
        return -1;
    }
    num := int(u8(coordinate[1]) - 48);
    file := int(u8(coordinate[0]) - 97);
    return 8 * (8 - num) + file;
}

index_to_coordinate :: proc(index: int) -> string {
    switch index {
    case 0:  return "a8"
    case 1:  return "b8"
    case 2:  return "c8"
    case 3:  return "d8"
    case 4:  return "e8"
    case 5:  return "f8"
    case 6:  return "g8"
    case 7:  return "h8"

    case 8:  return "a7"
    case 9:  return "b7"
    case 10: return "c7"
    case 11: return "d7"
    case 12: return "e7"
    case 13: return "f7"
    case 14: return "g7"
    case 15: return "h7"

    case 16: return "a6"
    case 17: return "b6"
    case 18: return "c6"
    case 19: return "d6"
    case 20: return "e6"
    case 21: return "f6"
    case 22: return "g6"
    case 23: return "h6"

    case 24: return "a5"
    case 25: return "b5"
    case 26: return "c5"
    case 27: return "d5"
    case 28: return "e5"
    case 29: return "f5"
    case 30: return "g5"
    case 31: return "h5"

    case 32: return "a4"
    case 33: return "b4"
    case 34: return "c4"
    case 35: return "d4"
    case 36: return "e4"
    case 37: return "f4"
    case 38: return "g4"
    case 39: return "h4"

    case 40: return "a3"
    case 41: return "b3"
    case 42: return "c3"
    case 43: return "d3"
    case 44: return "e3"
    case 45: return "f3"
    case 46: return "g3"
    case 47: return "h3"

    case 48: return "a2"
    case 49: return "b2"
    case 50: return "c2"
    case 51: return "d2"
    case 52: return "e2"
    case 53: return "f2"
    case 54: return "g2"
    case 55: return "h2"

    case 56: return "a1"
    case 57: return "b1"
    case 58: return "c1"
    case 59: return "d1"
    case 60: return "e1"
    case 61: return "f1"
    case 62: return "g1"
    case 63: return "h1"
    }

    return ""
}

is_king_in_neighbouring_tiles :: proc(pieces: []Piece, index: int, is_white: bool) -> bool{
    //8 1 2
    //7   3 
    //6 5 4
    if index - 8 >= 0 && pieces[index - 8].is_white == is_white && pieces[index - 8].type == .King{
        return true
    }
    if index - 7 >= 0 && index % 8 != 7 && pieces[index - 7].is_white == is_white && pieces[index - 7].type == .King{
        return true
    }
    if index % 8 != 7  && pieces[index + 1].is_white == is_white && pieces[index + 1].type == .King{
        return true
    }
    if index + 9 < 64 && index % 8 != 7  && pieces[index + 9].is_white == is_white && pieces[index + 9].type == .King{
        return true
    }
    if index + 8 < 64 && pieces[index + 8].is_white == is_white && pieces[index + 8].type == .King{
        return true
    }
    if index + 7 < 64 && index % 8 != 0 && pieces[index + 7].is_white == is_white && pieces[index + 7].type == .King{
        return true
    }
    if index % 8 != 0 && pieces[index - 1].is_white == is_white && pieces[index - 1].type == .King{
        return true
    }
    if index % 8 != 0 && index - 9 >= 0  && pieces[index - 9].is_white == is_white && pieces[index - 9].type == .King{
        return true
    }

    return false
}

is_tile_different_color_or_empty :: proc(pieces: []Piece, index_to_check: int, piece_to_compare: Piece) -> bool{
    return pieces[index_to_check].type == .None || (pieces[index_to_check].type != .None && pieces[index_to_check].is_white != piece_to_compare.is_white)
}

get_king_index :: proc(pieces: []Piece, king_color_is_white: bool) -> int{
    for piece, i in pieces{
        if piece.type == .King && piece.is_white == king_color_is_white{
            return i
        }
    }
    assert(false, "[Error in get_king_index] Failing here means we don't have at least one king of each color, which shoouldn't happen")
    return -1
}

get_pieces_from_board :: proc(pieces: []Piece, piece_to_look_for: Piece) -> [dynamic; 64]int{
    found_pieces: [dynamic; 64]int
    for piece, i in pieces{
        if piece == piece_to_look_for{
            append(&found_pieces, i)
        }
    }
    return found_pieces
}

get_pieces_from_file :: proc(pieces: []Piece, piece_to_look_for: Piece, file: u8) -> [dynamic;64]int{
    if !(file >= '1' && file <= '8'){
        assert(false, "wrong input argument")
    }

    found_pieces := get_pieces_from_board(pieces, piece_to_look_for) 

    i := 0
    length := len(found_pieces)
    for _ in 0..<length{
        if index_to_coordinate(found_pieces[i])[1] == file{
            i += 1
        }
        else{
            ordered_remove(&found_pieces, i)
        }
    }
    return found_pieces
}

get_pieces_from_rank :: proc(pieces: []Piece, piece_to_look_for: Piece, rank: u8) -> [dynamic;64]int{
    if !(rank >= 'a' && rank <= 'h'){
        assert(false, "wrong input argument")
    }
    found_pieces := get_pieces_from_board(pieces, piece_to_look_for) 

    i := 0
    length := len(found_pieces)
    for _ in 0..<length{
        if index_to_coordinate(found_pieces[i])[0] == rank{
            i += 1
        }
        else{
            ordered_remove(&found_pieces, i)
        }
    }
    return found_pieces
}

remove_pieces_that_cannot_move_there :: proc(pieces: []Piece, found_pieces: [dynamic; 64]int, coordinate_lexeme: string) -> int{
    found_pieces := found_pieces
    coordinate_index := coordinate_to_index(coordinate_lexeme)

    i := 0
    length := len(found_pieces)
    for _ in 0..<length{
        moves := get_possible_moves(pieces, found_pieces[i], pieces[found_pieces[i]], Move{-1, -1, piece_none(), piece_none(), false})

        //fmt.println(moves, i, found_pieces[:], len(found_pieces))

        can_move_there := false
        for move in moves{
            if move == coordinate_index{
                can_move_there = true
            }
        }

        if can_move_there{
            i += 1
        }
        else{
            ordered_remove(&found_pieces, i)
        }
    }

    //it's possible that there are still two pawns that can move to the same place
    //we should find the one closest to the index 
    //(the other one is behind so it's definitely cannot move in front of the other pawn)
    if len(found_pieces) != 1{

        only_pawns := true
        for piece_index in found_pieces{
            if pieces[piece_index].type != .Pawn{
                only_pawns = false
            }
        }
        assert(only_pawns, "we only expect pawns here")

        min_dist := 10000
        for piece_index in found_pieces{
            if abs(piece_index - coordinate_index) < min_dist{
                min_dist = abs(piece_index - coordinate_index)
            }
        }

        i := 0
        for _ in 0..<len(found_pieces){
            if abs(found_pieces[i] - coordinate_index) == min_dist{
                i += 1
            }
            else{
                ordered_remove(&found_pieces, i)
            }
        }
    }

    assert(len(found_pieces) == 1, "There should only be one piece that can move to a specific tile")
    return found_pieces[0] 
}