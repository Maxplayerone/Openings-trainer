package main

get_possible_moves :: proc(pieces: []Piece, piece_index: int, piece: Piece, last_move: Move) -> [dynamic; 64]int{
    moves: [dynamic; 64]int
    #partial switch piece.type{
        case .None:
        case .Rook:
            get_possible_moves_for_rook(pieces, piece_index, piece, &moves)
        case .Bishop:
            get_possible_moves_for_bishop(pieces, piece_index, piece, &moves)
        case .Knight:
            get_possible_moves_for_knight(pieces, piece_index, piece, &moves)
        case .Queen:
            get_possible_moves_for_bishop(pieces, piece_index, piece, &moves)
            get_possible_moves_for_rook(pieces, piece_index, piece, &moves)
        case .King:
            get_possible_moves_for_king(pieces, piece_index, piece, &moves)
        case .Pawn:
            get_possible_moves_for_pawn(pieces, piece_index, piece, last_move, &moves)
    }
    return moves
}

get_possible_moves_for_rook :: proc(pieces: []Piece, piece_index: int, piece: Piece, moves: ^[dynamic; 64]int){
    for i := piece_index + 1; i % 8 != 0 && i < 64; i += 1{
        if pieces[i].type != .None{
            if pieces[i].is_white != piece.is_white{
                append(moves, i)
            }
            break
        }
        append(moves, i)
    }
    for i := piece_index - 1; i % 8 != 7 && i >= 0; i -= 1{
        if pieces[i].type != .None{
            if pieces[i].is_white != piece.is_white{
                append(moves, i)
            }
            break
        }
        append(moves, i)
    }
    for i := piece_index - 8; i > -1; i -= 8{
        if pieces[i].type != .None{
            if pieces[i].is_white != piece.is_white{
                append(moves, i)
            }
            break
        }
        append(moves, i)
    }
    for i := piece_index + 8; i < 64; i += 8{
        if pieces[i].type != .None{
            if pieces[i].is_white != piece.is_white{
                append(moves, i)
            }
            break
        }
        append(moves, i)
    }
}

get_possible_moves_for_bishop :: proc(pieces: []Piece, piece_index: int, piece: Piece, moves: ^[dynamic; 64]int){
    for i := piece_index - 7; i % 8 != 0 && i >= 0; i -= 7{
        if pieces[i].type != .None{
            if pieces[i].is_white != piece.is_white{
                append(moves, i)
            }
            break
        }
        append(moves, i)
    }
    for i := piece_index + 7; i % 8 != 7 && i < 64; i += 7{
        if pieces[i].type != .None{
            if pieces[i].is_white != piece.is_white{
                append(moves, i)
            }
            break
        }
        append(moves, i)
    }
    for i := piece_index - 9; i % 8 != 7 && i >= 0; i -= 9{
        if pieces[i].type != .None{
            if pieces[i].is_white != piece.is_white{
                append(moves, i)
            }
            break
        }
        append(moves, i)
    }
    for i := piece_index + 9; i % 8 != 0 && i < 64; i += 9{
        if pieces[i].type != .None{
            if pieces[i].is_white != piece.is_white{
                append(moves, i)
            }
            break
        }
        append(moves, i)
    }
}

get_possible_moves_for_knight :: proc(pieces: []Piece, piece_index: int, piece: Piece, moves: ^[dynamic; 64]int){
    //bottom moves
    if piece_index % 8 >= 2 && piece_index + 6 < 64 && is_tile_different_color_or_empty(pieces, piece_index + 6, piece){
        append(moves, piece_index + 6)
    }
    if piece_index % 8 <= 5 && piece_index + 10 < 64 && is_tile_different_color_or_empty(pieces, piece_index + 10, piece){
        append(moves, piece_index + 10)
    }
    if piece_index % 8 >= 1 && piece_index + 15 < 64 && is_tile_different_color_or_empty(pieces, piece_index + 15, piece){
        append(moves, piece_index + 15)
    }
    if piece_index % 8 <= 6 && piece_index + 17 < 64 && is_tile_different_color_or_empty(pieces, piece_index + 17, piece){
        append(moves, piece_index + 17)
    }

    //top moves
    if piece_index % 8 <= 5 && piece_index - 6 >= 0 && is_tile_different_color_or_empty(pieces, piece_index - 6, piece){
        append(moves, piece_index - 6)
    }
    if piece_index % 8 >= 2 && piece_index - 10 >= 0 && is_tile_different_color_or_empty(pieces, piece_index - 10, piece){
        append(moves, piece_index - 10)
    }
    if piece_index % 8 <= 6 && piece_index - 15 >= 0 && is_tile_different_color_or_empty(pieces, piece_index - 15, piece){
        append(moves, piece_index - 15)
    }
    if piece_index % 8 >= 1 && piece_index - 17 >= 0 && is_tile_different_color_or_empty(pieces, piece_index - 17, piece){
        append(moves, piece_index - 17)
    }
}

//(NOTE): also need to check if after moving the piece will be in a check
get_possible_moves_for_king :: proc(pieces: []Piece, piece_index: int, piece: Piece, moves: ^[dynamic; 64]int){
    if piece_index % 8 != 7 && is_tile_different_color_or_empty(pieces, piece_index + 1, piece) && !is_king_in_neighbouring_tiles(pieces, piece_index + 1, !piece.is_white){
        append(moves, piece_index + 1)
    }
    if piece_index % 8 != 0 && is_tile_different_color_or_empty(pieces, piece_index - 1, piece) && !is_king_in_neighbouring_tiles(pieces, piece_index - 1, !piece.is_white){
        append(moves, piece_index - 1)
    }
    if piece_index - 8 >= 0 && is_tile_different_color_or_empty(pieces, piece_index - 8, piece) && !is_king_in_neighbouring_tiles(pieces, piece_index - 8, !piece.is_white){
        append(moves, piece_index - 8)
    }
    if piece_index + 8 < 64 && is_tile_different_color_or_empty(pieces, piece_index + 8, piece) && !is_king_in_neighbouring_tiles(pieces, piece_index + 8, !piece.is_white){
        append(moves, piece_index + 8)
    }

    //diagonal
    if piece_index % 8 != 7 && piece_index - 7 >= 0 && is_tile_different_color_or_empty(pieces, piece_index - 7, piece) && !is_king_in_neighbouring_tiles(pieces, piece_index - 7, !piece.is_white){
        append(moves, piece_index - 7)
    }
    if piece_index % 8 != 0 && piece_index - 9 >= 0 && is_tile_different_color_or_empty(pieces, piece_index - 9, piece) && !is_king_in_neighbouring_tiles(pieces, piece_index - 9, !piece.is_white){
        append(moves, piece_index - 9)
    }
    if piece_index % 8 != 7 && piece_index + 9 < 64 && is_tile_different_color_or_empty(pieces, piece_index + 9, piece) && !is_king_in_neighbouring_tiles(pieces, piece_index + 9, !piece.is_white){
        append(moves, piece_index + 9)
    }
    if piece_index % 8 != 0 && piece_index + 7 < 64 && is_tile_different_color_or_empty(pieces, piece_index + 7, piece) && !is_king_in_neighbouring_tiles(pieces, piece_index + 7, !piece.is_white){
        append(moves, piece_index + 7)
    }
}

get_possible_moves_for_pawn :: proc(pieces: []Piece, piece_index: int, piece: Piece, last_move: Move, moves: ^[dynamic; 64]int){
    //for white
    if piece.is_white && piece_index - 8 >= 0 && pieces[piece_index - 8].type == .None{
        append(moves, piece_index - 8)
    }
    if piece.is_white && piece_index >= 48 && piece_index < 56 && piece_index - 16 >= 0 && pieces[piece_index - 16].type == .None{
        append(moves, piece_index - 16)
    }
    if piece.is_white && piece_index - 7 >= 0 && piece_index % 8 != 7 && pieces[piece_index - 7].type != .None{
        append(moves, piece_index - 7)
    }
    if piece.is_white && piece_index - 9 >= 0 && piece_index % 8 != 0 && pieces[piece_index - 9].type != .None{
        append(moves, piece_index - 9)
    }
    //en passant
    if piece.is_white && piece_index % 8 != 7 && piece_index >= 24 && piece_index < 32 && last_move.to == piece_index + 1 && last_move.from + 16 == last_move.to && !pieces[last_move.to].is_white && pieces[last_move.to].type == .Pawn{
        append(moves, piece_index - 7)
    }
    if piece.is_white && piece_index % 8 != 0 && piece_index >= 24 && piece_index < 32 && last_move.to == piece_index - 1 && last_move.from + 16 == last_move.to && !pieces[last_move.to].is_white && pieces[last_move.to].type == .Pawn{
        append(moves, piece_index - 9)
    }

    //for black
    if !piece.is_white && piece_index + 8 < 64 && pieces[piece_index + 8].type == .None{
        append(moves, piece_index + 8)
    }
    if !piece.is_white && piece_index >= 8 && piece_index < 16 && piece_index + 16 < 64 && pieces[piece_index + 16].type == .None{
        append(moves, piece_index + 16)
    }
    if !piece.is_white && piece_index + 7 < 64 && piece_index % 8 != 0 && pieces[piece_index + 7].type != .None{
        append(moves, piece_index + 7)    
    }
    if !piece.is_white && piece_index + 9 < 64 && piece_index % 8 != 7 && pieces[piece_index + 9].type != .None{
        append(moves, piece_index + 9)    
    }
    //en passant
    if last_move.from == -1 && last_move.to == -1{
        return
    }

    if !piece.is_white && piece_index % 8 != 7 && piece_index >= 32 && piece_index < 40 && last_move.to == piece_index + 1 && last_move.from - 16 == last_move.to && pieces[last_move.to].is_white && pieces[last_move.to].type == .Pawn{
        append(moves, piece_index + 9)
    }
    if !piece.is_white && piece_index % 8 != 0 && piece_index >= 32 && piece_index < 40 && last_move.to == piece_index - 1 && last_move.from - 16 == last_move.to && pieces[last_move.to].is_white && pieces[last_move.to].type == .Pawn{
        append(moves, piece_index + 7)
    }
}

is_check :: proc(pieces: []Piece,  is_king_to_check_white: bool, king_index: int) -> bool{
    //gather all opposite color pieces
    opposite_color_pieces := make([dynamic]int, context.allocator)
    defer delete(opposite_color_pieces)

    for piece, i in pieces{
        if piece.is_white != is_king_to_check_white{
            append(&opposite_color_pieces, i)
        }
    }

    for piece_index in opposite_color_pieces{
        //Move{-1, -1} because we only look for a check. Last move is used only to check en passant
        moves := get_possible_moves(pieces, piece_index, pieces[piece_index], Move{-1, -1, piece_none(), piece_none(), false})
        for move in moves{
            if move == king_index{
                return true
            }
        }
    }
    return false
}