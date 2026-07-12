package main

import "core:os"
import "core:fmt"

Move :: struct{
    from: int,
    to: int, 
    captured: Piece,
    promoted: Piece,
    en_passant: bool,
}

piece_none :: proc() -> Piece{
    return {.None, false}
}

TokenType :: enum{
    EOF,
    Error,
    Metadata,
    MoveCount,
    FinalVerdict,
    PieceIndicator,
    MoveCoordinates,
    Castles,
    Capture,
    CaptureAmbiguity,
    Checkmate,
    Check,
    Promotion,
}

Token :: struct{
    type: TokenType,
    lexeme: string,
}

Lexer :: struct{
    input: string,
    cur_position: int,
}

lexer_next_char :: proc(lexer: ^Lexer) -> byte{
    if lexer.cur_position >= len(lexer.input){
        return 0
    }
    ch := lexer.input[lexer.cur_position]
    lexer.cur_position += 1
    return ch
}

lexer_peek_char :: proc(lexer: Lexer, depth := 0) -> byte{
    if lexer.cur_position + depth >= len(lexer.input){
        return 0
    }
    return lexer.input[lexer.cur_position + depth]
}

lexer_is_whitespace :: proc(ch: byte) -> bool{
    return ch == ' ' || ch == '\r' || ch == '\t' || ch == '\n'
}

lexer_skip_whitespace :: proc(lexer: ^Lexer){
    ch := lexer_peek_char(lexer^)
    for lexer_is_whitespace(ch){
        lexer_next_char(lexer)
        ch = lexer_peek_char(lexer^)
    }
}

lexer_read_brackets :: proc(lexer: ^Lexer) -> Token{
    start := lexer.cur_position - 1 //so start points to [ and not the first character after that
    peek_char := lexer_peek_char(lexer^)
    for peek_char != ']'{
        if lexer.cur_position >= len(lexer.input) || peek_char == '['{
            fmt.println("[Error in lexer_read_brackets] unclosed metadata bracket object")
            return Token{.Error, "Error"}
        }
        lexer_next_char(lexer)
        peek_char = lexer_peek_char(lexer^)
    }
    lexer_next_char(lexer)
    return {.Metadata, lexer.input[start:lexer.cur_position]}
}

lexer_is_number :: proc(c: u8) -> bool{
    //theoretically c >= 49 because the first digit cannot be a 0 but I don't think it's a big deal 
    return c >= 48 && c <= 57
}

lexer_read_number :: proc(lexer: ^Lexer) -> Token{
    start := lexer.cur_position - 1
    peek_char := lexer_peek_char(lexer^)
    for peek_char != '.'{
        if !lexer_is_number(peek_char){
            fmt.println("[Error in lexer_read_number] expected a number. Got ", rune(peek_char), peek_char)
            return Token{.Error, "Error"}
        }

        lexer_next_char(lexer)
        peek_char = lexer_peek_char(lexer^)
    }
    lexer_next_char(lexer)

    return {.MoveCount, lexer.input[start:lexer.cur_position]}
}

lexer_read_move_coordinate :: proc(lexer: ^Lexer, cur_char: byte) -> Token{
    start := lexer.cur_position - 1
    peek_ch := lexer_peek_char(lexer^)
    if lexer_is_number(peek_ch){
        lexer_next_char(lexer)
        return Token{.MoveCoordinates, lexer.input[start:start+2]}
    }
    else if peek_ch == 'x'{
        return lexer_read_capture(lexer)
    }
    else{
        fmt.println("[Error in lexer_read_move_coordinate] next character should be a number. Got ", rune(peek_ch), peek_ch)
        return Token{.Error, "Error"}
    }
}

lexer_read_draw :: proc(lexer: ^Lexer) -> Token{
    //we know the peek char was / so we can move to the next one
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != '2'{
        fmt.println("[Error in lexer_read_draw] Expected 1/2-1/2 got 1/[?]")
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != '-'{
        fmt.println("[Error in lexer_read_draw] Expected 1/2-1/2 got 1/2[?]")
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != '1'{
        fmt.println("[Error in lexer_read_draw] Expected 1/2-1/2 got 1/2-[?]")
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != '/'{
        fmt.println("[Error in lexer_read_draw] Expected 1/2-1/2 got 1/2-1[?]")
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != '2'{
        fmt.println("[Error in lexer_read_draw] Expected 1/2-1/2 got 1/2-1/[?]")
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    return Token{.FinalVerdict, "1/2-1/2"}
}

lexer_read_white_won :: proc(lexer: ^Lexer) -> Token{
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != '0'{
        fmt.println("[Error in lexer_read_white_won] Expected 1-0 got 1-[?]")
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    return Token{.FinalVerdict, "1-0"}
}

lexer_read_castles :: proc(lexer: ^Lexer) -> Token{
    if lexer_peek_char(lexer^) != '-'{
        fmt.println("[Error in lexer_read_castles] Expected char -. Got ", rune(lexer_peek_char(lexer^)), lexer_peek_char(lexer^))
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != 'O'{
        fmt.println("[Error in lexer_read_castles] Expected char O. Got ", rune(lexer_peek_char(lexer^)), lexer_peek_char(lexer^))
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != '-'{
        return Token{.Castles, "O-O"}
    }
    lexer_next_char(lexer)
    if lexer_peek_char(lexer^) != 'O'{
        fmt.println("[Error in lexer_read_castles] Expected char O. Got ", rune(lexer_peek_char(lexer^)), lexer_peek_char(lexer^))
        return Token{.Error, "Error"}
    }
    lexer_next_char(lexer)
    return Token{.Castles, "O-O-O"}
}

lexer_read_promotion :: proc(lexer: ^Lexer) -> Token{
    peek_ch := lexer_peek_char(lexer^)
    if peek_ch == 'S' || peek_ch == 'W' || peek_ch == 'G' || peek_ch == 'H' || peek_ch == 'Q' || peek_ch == 'R' || peek_ch == 'B' || peek_ch == 'N'{
        lexer_next_char(lexer)
        return Token{.Promotion, lexer.input[lexer.cur_position-2:lexer.cur_position]}
    }
    else{
        fmt.println("[Error in lexer_read_promotion] Expected W, S, G or H. Got ", rune(peek_ch), peek_ch)
        return Token{.Error, "Error"}
    }
}

lexer_read_capture :: proc(lexer: ^Lexer) -> Token{
    start := lexer.cur_position - 1
    peek_char := lexer_peek_char(lexer^)
    for !lexer_is_whitespace(peek_char) && peek_char != 0 && peek_char != '+' && peek_char != '#' && peek_char != '='{
        lexer_next_char(lexer)
        peek_char = lexer_peek_char(lexer^)
    } 
    return Token{.Capture, lexer.input[start:lexer.cur_position]}
}

lexer_read_capture_ambiguity :: proc(lexer: ^Lexer) -> Token{
    tok := lexer_read_capture(lexer)
    tok.type = .CaptureAmbiguity
    return tok
}

lexer_next_token :: proc(lexer: ^Lexer) -> Token{
    lexer_skip_whitespace(lexer)

    ch := lexer_next_char(lexer)
    switch ch{
        case '[':
            return lexer_read_brackets(lexer)
        case '*':
            return Token{.FinalVerdict, "*"}
        case 'a'..='h':
            return lexer_read_move_coordinate(lexer, ch)
        case 'O':
            return lexer_read_castles(lexer)
        case 'B':
            if lexer_peek_char(lexer^) == 'x'{
                return lexer_read_capture(lexer) 
            }
            else{
                return Token{.PieceIndicator, "B"}
            }
        case 'K':
            if lexer_peek_char(lexer^) == 'x'{
                return lexer_read_capture(lexer) 
            }
            else{
                return Token{.PieceIndicator, "K"}
            }
        case '+':
            return Token{.Check, "+"}
        case '#':
            return Token{.Checkmate, "#"}
        case '=':
            return lexer_read_promotion(lexer)
        case '1'..='9': 
            if ch == '1' && lexer_peek_char(lexer^) == '/'{
                return lexer_read_draw(lexer)
            }
            else if ch == '1' && lexer_peek_char(lexer^) == '-'{
                return lexer_read_white_won(lexer)
            }
            else{
                return lexer_read_number(lexer)
            }
        case 'N':
            double_peek_ch := lexer_peek_char(lexer^, 1)
            peek_ch := lexer_peek_char(lexer^)
            //if Nac4 or N2g8
            if (((double_peek_ch >= 'a' && double_peek_ch <= 'h') || double_peek_ch == 'x') && peek_ch >= 'a' && peek_ch <= 'h') || (peek_ch >= '1' && peek_ch <= '8'){
                if double_peek_ch == 'x' || lexer_peek_char(lexer^, 2) == 'x'{
                    return lexer_read_capture_ambiguity(lexer)
                }
                else{
                    lexer_next_char(lexer)
                    return Token{.PieceIndicator, lexer.input[lexer.cur_position - 2:lexer.cur_position]}
                }
            }
            else if peek_ch == 'x'{
                return lexer_read_capture(lexer)
            }

            return Token{.PieceIndicator, "N"}
        case 'R':
            double_peek_ch := lexer_peek_char(lexer^, 1)
            peek_ch := lexer_peek_char(lexer^)
            //if Rac4 or R2g8
            if (((double_peek_ch >= 'a' && double_peek_ch <= 'h') || double_peek_ch == 'x') && peek_ch >= 'a' && peek_ch <= 'h') || (peek_ch >= '1' && peek_ch <= '8'){
                if double_peek_ch == 'x' || lexer_peek_char(lexer^, 2) == 'x'{
                    return lexer_read_capture_ambiguity(lexer)
                }
                else{
                    lexer_next_char(lexer)
                    return Token{.PieceIndicator, lexer.input[lexer.cur_position - 2:lexer.cur_position]}
                }
            }
            else if peek_ch == 'x'{
                return lexer_read_capture(lexer)
            }

            return Token{.PieceIndicator, "R"}
        case 'Q':
            double_peek_ch := lexer_peek_char(lexer^, 1)
            peek_ch := lexer_peek_char(lexer^)
            //if Qac4 or Q2g8
            if (((double_peek_ch >= 'a' && double_peek_ch <= 'h') || double_peek_ch == 'x') && peek_ch >= 'a' && peek_ch <= 'h') || (peek_ch >= '1' && peek_ch <= '8'){
                if double_peek_ch == 'x' || lexer_peek_char(lexer^, 2) == 'x'{
                    return lexer_read_capture_ambiguity(lexer)
                }
                else{
                    lexer_next_char(lexer)
                    return Token{.PieceIndicator, lexer.input[lexer.cur_position - 2:lexer.cur_position]}
                }
            }
            else if peek_ch == 'x'{
                return lexer_read_capture(lexer)
            }

            return Token{.PieceIndicator, "Q"}
        case 0:
            return Token{.EOF, "eof"}
        case:
            return Token{.Error, "Error"}
    }
}

Parser :: struct{
    pieces: [64]Piece,
    lexer: Lexer,
    cur_piece: Piece,
    piece_ambiguity: bool,
    ambiguity_lexeme: string,
    moves: [dynamic]Move,
}

parser_create :: proc(lexer: Lexer, allocator := context.allocator) -> Parser{
    parser := Parser{}
    assert(read_fen("res/fen/default.fen", &parser.pieces))    
    parser.cur_piece = Piece{.Pawn, true}
    parser.moves = make([dynamic]Move, allocator)
    parser.lexer = lexer
    return parser
}

get_closest_piece :: proc(pieces: []Piece, cur_piece: Piece, coordinate_lexeme: string) -> int{
    found_pieces := get_pieces_from_board(pieces, cur_piece)
    assert(len(found_pieces) != 0, "[Error in get_closest_piece] Couldn't find any piece")
    if len(found_pieces) > 1{
        return remove_pieces_that_cannot_move_there(pieces, found_pieces, coordinate_lexeme)
    }
    return found_pieces[0]
}

get_closest_piece_with_ambiguity :: proc(pieces: []Piece, cur_piece: Piece, coordinate_lexeme: string, ambiguity_char: u8) -> int{
    found_pieces: [dynamic; 64]int
    if ambiguity_char >= '1' && ambiguity_char <= '8'{
        found_pieces = get_pieces_from_file(pieces, cur_piece, ambiguity_char)
    }
    else if ambiguity_char >= 'a' && ambiguity_char <= 'h'{
        found_pieces = get_pieces_from_rank(pieces, cur_piece, ambiguity_char)
    }
    else{
        assert(false, "Wrong input argument")
    }

    assert(len(found_pieces) != 0, "[Error in get_closest_piece] Couldn't find any piece")
    if len(found_pieces) > 1{
        return remove_pieces_that_cannot_move_there(pieces, found_pieces, coordinate_lexeme)
    }
    return found_pieces[0]
}

parser_piece_symbol_to_piece_type :: proc(symbol: u8) -> PieceType{
    switch symbol{
        case 'N', 'S':
            return .Knight
        case 'K':
            return .King
        case 'Q', 'H':
            return .Queen
        case 'B', 'G':
            return .Bishop
        case 'R', 'W':
            return .Rook
    }
    assert(false, "No match for lexeme") 
    return .None
}

parser_parse :: proc(parser: ^Parser) -> bool{
    for tok := lexer_next_token(&parser.lexer); tok.type != .EOF; tok = lexer_next_token(&parser.lexer){
        fmt.println("Currently parsing token:", tok)

        switch tok.type{
            case .Error:
                return false
            case .EOF:
                return true
            case .Metadata:
            case .FinalVerdict:
            case .MoveCount:
            case .Capture:
                piece_char := tok.lexeme[0]
                coordinate_lexeme := tok.lexeme[2:]
                en_passant := false
                from := -1 

                if piece_char >= 'a' && piece_char <= 'h'{
                    parser.cur_piece.type = .Pawn
                    //here piece_char is not a piece like N, Q etc. but a file like a, b, c, d...
                    from = get_closest_piece_with_ambiguity(parser.pieces[:], parser.cur_piece, coordinate_lexeme, piece_char)
                }
                else{
                    parser.cur_piece.type = parser_piece_symbol_to_piece_type(piece_char)
                    from = get_closest_piece(parser.pieces[:], parser.cur_piece, coordinate_lexeme)
                }

                to := coordinate_to_index(coordinate_lexeme)
                captured_piece := parser.pieces[to]

                if captured_piece == piece_none(){
                    en_passant = true
                }

                parser.pieces[from] = piece_none() 
                parser.pieces[to] = parser.cur_piece
                append(&parser.moves, Move{from, to, captured_piece, piece_none(), en_passant})

                //cleanup
                parser.cur_piece.is_white = !parser.cur_piece.is_white
                parser.cur_piece.type = .Pawn
                parser.piece_ambiguity = false
            case .CaptureAmbiguity:
                piece_char := tok.lexeme[0]
                ambiguity := tok.lexeme[1]
                coordinate_lexeme := tok.lexeme[3:]
                en_passant := false

                parser.cur_piece.type = parser_piece_symbol_to_piece_type(piece_char)

                from := get_closest_piece_with_ambiguity(parser.pieces[:], parser.cur_piece, coordinate_lexeme, ambiguity)
                to := coordinate_to_index(coordinate_lexeme)
                captured_piece := parser.pieces[to] 

                if captured_piece == piece_none(){
                    en_passant = true
                }

                parser.pieces[from] = piece_none() 
                parser.pieces[to] = parser.cur_piece
                append(&parser.moves, Move{from, to, captured_piece, piece_none(), en_passant})

                //cleanup
                parser.cur_piece.is_white = !parser.cur_piece.is_white
                parser.cur_piece.type = .Pawn
                parser.piece_ambiguity = false
            case .Checkmate:
            case .Check:
            case .MoveCoordinates:
                from, to := -1, -1 
                if !parser.piece_ambiguity{
                    from = get_closest_piece(parser.pieces[:], parser.cur_piece, tok.lexeme)
                    to = coordinate_to_index(tok.lexeme)
                }
                else{
                    from = get_closest_piece_with_ambiguity(parser.pieces[:], parser.cur_piece, tok.lexeme, parser.ambiguity_lexeme[1])
                    to = coordinate_to_index(tok.lexeme)
                }
                parser.pieces[from] = Piece{.None, false}
                parser.pieces[to] = parser.cur_piece
                append(&parser.moves, Move{from, to, piece_none(), piece_none(), false})

                //cleanup
                parser.cur_piece.is_white = !parser.cur_piece.is_white
                parser.cur_piece.type = .Pawn
                parser.piece_ambiguity = false
            case .PieceIndicator:
                parser.cur_piece.type = parser_piece_symbol_to_piece_type(tok.lexeme[0])
                if len(tok.lexeme) == 2{
                    parser.piece_ambiguity = true
                    parser.ambiguity_lexeme = tok.lexeme
                }
            case .Castles:
                //(NOTE): not checking if rooks and kings are in the correct position
                if len(tok.lexeme) == 3 && parser.cur_piece.is_white{
                    append(&parser.moves, Move{64, 64, piece_none(), piece_none(), false})
                    parser.pieces[coordinate_to_index("e1")] = piece_none() 
                    parser.pieces[coordinate_to_index("h1")] = piece_none() 
                    parser.pieces[coordinate_to_index("f1")] = Piece{.Rook, true}
                    parser.pieces[coordinate_to_index("g1")] = Piece{.King, true}
                }
                else if len(tok.lexeme) == 3 && !parser.cur_piece.is_white{
                    append(&parser.moves, Move{65, 65, piece_none(), piece_none(), false})
                    parser.pieces[coordinate_to_index("e8")] = piece_none() 
                    parser.pieces[coordinate_to_index("h8")] = piece_none() 
                    parser.pieces[coordinate_to_index("f8")] = Piece{.Rook, false} 
                    parser.pieces[coordinate_to_index("g8")] = Piece{.King, false} 
                }
                else if len(tok.lexeme) == 5 && parser.cur_piece.is_white{
                    append(&parser.moves, Move{66, 66, piece_none(), piece_none(), false})
                    parser.pieces[coordinate_to_index("e1")] = piece_none() 
                    parser.pieces[coordinate_to_index("a1")] = piece_none() 
                    parser.pieces[coordinate_to_index("d1")] = Piece{.Rook, true} 
                    parser.pieces[coordinate_to_index("c1")] = Piece{.King, true} 
                }
                else if len(tok.lexeme) == 5 && !parser.cur_piece.is_white{
                    append(&parser.moves, Move{67, 67, piece_none(), piece_none(), false})
                    parser.pieces[coordinate_to_index("e8")] = piece_none() 
                    parser.pieces[coordinate_to_index("a8")] = piece_none() 
                    parser.pieces[coordinate_to_index("d8")] = Piece{.Rook, false}
                    parser.pieces[coordinate_to_index("c8")] = Piece{.King, false}
                }
                else{
                    assert(false)
                }

                //cleanup
                parser.cur_piece.is_white = !parser.cur_piece.is_white
                parser.cur_piece.type = .Pawn
                parser.piece_ambiguity = false
            case .Promotion:
                parser.moves[len(parser.moves) - 1].promoted = {parser_piece_symbol_to_piece_type(tok.lexeme[1]), !parser.cur_piece.is_white}
        }
    }
    return true
}

read_pgn :: proc(filename: string, pieces: []Piece) -> ([dynamic]Move, bool){
    file_contents_u8, err := os.read_entire_file_from_path(filename, context.temp_allocator)    
    if err != nil{
        fmt.println("Error opening the file", filename, ":", err)
        return {}, false
    }

    file_contents_str := transmute(string)file_contents_u8

    lexer := Lexer{input = file_contents_str}
    /*
    for tok := lexer_next_token(&lexer); tok.type != .EOF; tok = lexer_next_token(&lexer){
        fmt.println(tok)
    }
    success := true
    */
    parser := parser_create(lexer)
    success := parser_parse(&parser) 

    return parser.moves, success
}