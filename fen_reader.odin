package main

import "core:os"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

read_fen :: proc(filename: string, pieces: ^[64]Piece) -> bool{
    file_contents_u8, err := os.read_entire_file_from_path(filename, context.temp_allocator)
    if err != nil{
        fmt.println("Error opening the file", filename, ":", err)
        return false
    }
    file_contents_str := transmute(string)file_contents_u8

    //we are ignoring who is starting the game, which side can castle etc.
    piece_positions := strings.split(file_contents_str, " ", context.temp_allocator)[0] 
    character_ptr := 0 
    board_index := 0
    for board_index < 64{
        switch rune(piece_positions[character_ptr]){
            case '1'..='8':
                board_index += int(piece_positions[character_ptr]) - 48;
                character_ptr += 1 
            case 'r':
                pieces[board_index] = Piece{.Rook, false}
                character_ptr += 1
                board_index += 1
            case 'R':
                pieces[board_index] = Piece{.Rook, true}
                character_ptr += 1
                board_index += 1
            case 'n':
                pieces[board_index] = Piece{.Knight, false}
                character_ptr += 1
                board_index += 1
            case 'N':
                pieces[board_index] = Piece{.Knight, true}
                character_ptr += 1
                board_index += 1
            case 'b':
                pieces[board_index] = Piece{.Bishop, false}
                character_ptr += 1
                board_index += 1
            case 'B':
                pieces[board_index] = Piece{.Bishop, true}
                character_ptr += 1
                board_index += 1
            case 'q':
                pieces[board_index] = Piece{.Queen, false}
                character_ptr += 1
                board_index += 1
            case 'Q':
                pieces[board_index] = Piece{.Queen, true}
                character_ptr += 1
                board_index += 1
            case 'k':
                pieces[board_index] = Piece{.King, false}
                character_ptr += 1
                board_index += 1
            case 'K':
                pieces[board_index] = Piece{.King, true}
                character_ptr += 1
                board_index += 1
            case 'p':
                pieces[board_index] = Piece{.Pawn, false}
                character_ptr += 1
                board_index += 1
            case 'P':
                pieces[board_index] = Piece{.Pawn, true}
                character_ptr += 1
                board_index += 1
            case '/':
                character_ptr += 1
            case:
                fmt.println("[read_fen function] unknown character in fen file:", rune(piece_positions[character_ptr]))
                assert(false)
        }
    }

    return true
}

piece_type_to_texture_source_rect :: proc(piece: Piece) -> rl.Rectangle{
    rect := rl.Rectangle{0, 0, 200, 200}
    switch piece.type{
        case .None:
        case .King:
        case .Queen:
            rect.x = 200
        case .Bishop:
            rect.x = 400
        case .Knight:
            rect.x = 600
        case .Rook:
            rect.x = 800
        case .Pawn:
            rect.x = 1000
    }
    if !piece.is_white{
        rect.y = 200
    }
    return rect
}