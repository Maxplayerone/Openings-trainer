package main

import "core:testing"

expect_fen :: proc(t: ^testing.T, path: string, expected: [64]Piece) {
    pieces: [64]Piece
    testing.expect(t, read_fen(path, &pieces), "Couldn't load FEN")

    for piece, i in expected {
        testing.expectf(
            t,
            piece == pieces[i],
            "Piece mismatch at square %d",
            i,
        )
    }
}

@(test)
test_fen :: proc(t: ^testing.T) {
    default_expected := [64]Piece{
    Piece{.Rook,   false},
    Piece{.Knight, false},
    Piece{.Bishop, false},
    Piece{.Queen,  false},
    Piece{.King,   false},
    Piece{.Bishop, false},
    Piece{.Knight, false},
    Piece{.Rook,   false},
    Piece{.Pawn, false},
    Piece{.Pawn, false},
    Piece{.Pawn, false},
    Piece{.Pawn, false},
    Piece{.Pawn, false},
    Piece{.Pawn, false},
    Piece{.Pawn, false},
    Piece{.Pawn, false},
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    piece_none(),
    Piece{.Pawn, true},
    Piece{.Pawn, true},
    Piece{.Pawn, true},
    Piece{.Pawn, true},
    Piece{.Pawn, true},
    Piece{.Pawn, true},
    Piece{.Pawn, true},
    Piece{.Pawn, true},
    Piece{.Rook,   true},
    Piece{.Knight, true},
    Piece{.Bishop, true},
    Piece{.Queen,  true},
    Piece{.King,   true},
    Piece{.Bishop, true},
    Piece{.Knight, true},
    Piece{.Rook,   true},
    }
    fen1_expected := [64]Piece{
    Piece{.Rook, false}, Piece{.Knight, false}, Piece{.Bishop, false}, Piece{.Queen, false},
    Piece{.King, false}, Piece{.Bishop, false}, Piece{.Knight, false}, Piece{.Rook, false},
    Piece{.Pawn, false}, Piece{.Pawn, false}, piece_none(), piece_none(),
    Piece{.Pawn, false}, Piece{.Pawn, false}, Piece{.Pawn, false}, Piece{.Pawn, false},
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, false}, Piece{.Pawn, false},
    Piece{.Pawn, true}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), Piece{.Knight, true}, piece_none(), piece_none(),
    Piece{.Pawn, true}, Piece{.Pawn, true}, Piece{.Pawn, true}, Piece{.Pawn, true},
    piece_none(), Piece{.Pawn, true}, Piece{.Pawn, true}, Piece{.Pawn, true},
    Piece{.Rook, true}, Piece{.Knight, true}, Piece{.Bishop, true}, Piece{.Queen, true},
    Piece{.King, true}, Piece{.Bishop, true}, piece_none(), Piece{.Rook, true},
    }

    fen2_expected := [64]Piece{
    piece_none(), Piece{.Bishop, true}, piece_none(), Piece{.Bishop, false},
    piece_none(), Piece{.King, true}, piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), Piece{.Pawn, true},
    piece_none(), Piece{.Rook, true}, piece_none(), piece_none(),
    piece_none(), Piece{.Knight, true}, Piece{.Pawn, false}, piece_none(),
    Piece{.King, false}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), Piece{.Pawn, false}, Piece{.Pawn, true}, piece_none(),
    piece_none(), Piece{.Knight, false}, Piece{.Rook, true}, Piece{.Pawn, false},
    Piece{.Bishop, false}, piece_none(), Piece{.Pawn, true}, piece_none(),
    piece_none(), piece_none(), Piece{.Queen, true}, Piece{.Pawn, false},
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Knight, true}, piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, false}, piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Queen, false}, piece_none(),
    }

    fen3_expected := [64]Piece{
    piece_none(), Piece{.Bishop, false}, piece_none(), Piece{.Bishop, true},
    piece_none(), Piece{.King, false}, piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), Piece{.Bishop, true}, piece_none(), piece_none(),
    piece_none(), Piece{.Queen, false}, piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, true}, piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    Piece{.King, true}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    }

    fen4_expected := [64]Piece{
    piece_none(), Piece{.Bishop, false}, piece_none(), Piece{.Bishop, true},
    piece_none(), Piece{.King, true}, piece_none(), piece_none(),
    Piece{.Knight, false}, Piece{.Rook, false}, piece_none(), Piece{.Rook, true},
    piece_none(), Piece{.Pawn, true}, piece_none(), Piece{.Pawn, false},
    piece_none(), Piece{.Knight, true}, piece_none(), piece_none(),
    Piece{.King, false}, piece_none(), piece_none(), Piece{.Pawn, false},
    piece_none(), piece_none(), Piece{.Pawn, true}, piece_none(),
    piece_none(), Piece{.Rook, true}, Piece{.Knight, false}, piece_none(),
    Piece{.Bishop, true}, piece_none(), Piece{.Pawn, false}, Piece{.Pawn, true},
    piece_none(), piece_none(), piece_none(), Piece{.Knight, true},
    piece_none(), piece_none(), piece_none(), Piece{.Queen, true},
    Piece{.Pawn, true}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Bishop, false}, piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), Piece{.Rook, false}, piece_none(), Piece{.Queen, false},
    }

    fen5_expected := [64]Piece{
    piece_none(), Piece{.Bishop, true}, piece_none(), Piece{.Bishop, false},
    piece_none(), Piece{.King, true}, piece_none(), piece_none(),
    Piece{.Pawn, true}, piece_none(), piece_none(), Piece{.Knight, true},
    piece_none(), Piece{.Queen, true}, piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, false}, Piece{.Pawn, false},
    Piece{.Pawn, false}, piece_none(), Piece{.Knight, true}, Piece{.Pawn, false},
    piece_none(), piece_none(), piece_none(), Piece{.King, false},
    piece_none(), piece_none(), Piece{.Pawn, false}, piece_none(),
    Piece{.Rook, true}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), Piece{.Pawn, true},
    Piece{.Knight, false}, Piece{.Rook, false}, Piece{.Knight, false}, piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, false}, piece_none(),
    piece_none(), piece_none(), Piece{.Bishop, true}, piece_none(),
    piece_none(), piece_none(), piece_none(), Piece{.Bishop, false},
    piece_none(), piece_none(), piece_none(), Piece{.Queen, false},
    }

    fen6_expected := [64]Piece{
    piece_none(), Piece{.Bishop, false}, piece_none(), Piece{.Bishop, true},
    piece_none(), Piece{.King, false}, piece_none(), piece_none(),
    Piece{.Rook, true}, piece_none(), Piece{.Pawn, false}, piece_none(),
    piece_none(), Piece{.Knight, true}, Piece{.Knight, true}, piece_none(),
    Piece{.Rook, false}, piece_none(), Piece{.Queen, true}, piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, false}, piece_none(),
    Piece{.Rook, false}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, false}, piece_none(),
    Piece{.Bishop, false}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.King, true}, piece_none(),
    Piece{.Bishop, true}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), Piece{.Rook, true}, piece_none(), piece_none(),
    }

    fen7_expected := [64]Piece{
    piece_none(), Piece{.Bishop, true}, piece_none(), Piece{.Bishop, false},
    piece_none(), Piece{.Knight, true}, piece_none(), Piece{.Queen, false},
    piece_none(), piece_none(), piece_none(), Piece{.Pawn, false},
    piece_none(), Piece{.Pawn, false}, piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, false}, piece_none(),
    piece_none(), piece_none(), piece_none(), Piece{.Rook, true},
    piece_none(), piece_none(), piece_none(), Piece{.King, false},
    Piece{.Knight, true}, piece_none(), Piece{.Rook, true}, piece_none(),
    Piece{.Pawn, false}, piece_none(), piece_none(), Piece{.Pawn, true},
    Piece{.Knight, false}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    Piece{.Pawn, true}, Piece{.Rook, false}, Piece{.Rook, false}, Piece{.Bishop, false},
    piece_none(), piece_none(), Piece{.Bishop, true}, piece_none(),
    piece_none(), Piece{.Knight, false}, Piece{.Queen, true}, piece_none(),
    Piece{.King, true}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    }

    fen8_expected := [64]Piece{
    piece_none(), Piece{.Bishop, false}, piece_none(), Piece{.Bishop, true},
    piece_none(), Piece{.Knight, true}, piece_none(), piece_none(),
    piece_none(), Piece{.Pawn, false}, Piece{.Pawn, true}, piece_none(),
    piece_none(), Piece{.Pawn, false}, piece_none(), Piece{.Rook, false},
    Piece{.Bishop, false}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    Piece{.Rook, true}, piece_none(), piece_none(), Piece{.Pawn, false},
    Piece{.Pawn, false}, Piece{.King, false}, piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    Piece{.Rook, true}, piece_none(), piece_none(), Piece{.Knight, false},
    piece_none(), Piece{.Knight, true}, Piece{.Pawn, true}, Piece{.Pawn, true},
    piece_none(), piece_none(), Piece{.Rook, false}, piece_none(),
    Piece{.Queen, true}, piece_none(), piece_none(), piece_none(),
    piece_none(), Piece{.Bishop, true}, piece_none(), piece_none(),
    Piece{.Knight, false}, Piece{.King, true}, piece_none(), piece_none(),
    }

    fen9_expected := [64]Piece{
    piece_none(), Piece{.Bishop, false}, piece_none(), Piece{.Bishop, true},
    piece_none(), Piece{.Knight, true}, piece_none(), piece_none(),
    piece_none(), Piece{.Rook, false}, piece_none(), piece_none(),
    Piece{.Pawn, false}, Piece{.Bishop, true}, piece_none(), piece_none(),
    piece_none(), Piece{.Knight, true}, piece_none(), Piece{.King, false},
    piece_none(), Piece{.Pawn, true}, piece_none(), piece_none(),
    Piece{.Knight, false}, piece_none(), Piece{.Rook, true}, piece_none(),
    piece_none(), Piece{.Bishop, false}, piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), Piece{.Pawn, true},
    piece_none(), Piece{.Pawn, true}, piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    Piece{.King, true}, piece_none(), Piece{.Queen, true}, piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    }

    fen10_expected := [64]Piece{
    piece_none(), Piece{.Bishop, true}, piece_none(), Piece{.Bishop, false},
    piece_none(), Piece{.Knight, true}, piece_none(), piece_none(),
    piece_none(), Piece{.Rook, false}, Piece{.Pawn, false}, piece_none(),
    Piece{.King, false}, piece_none(), Piece{.King, true}, piece_none(),
    piece_none(), Piece{.Rook, false}, piece_none(), piece_none(),
    piece_none(), Piece{.Knight, true}, Piece{.Pawn, false}, piece_none(),
    piece_none(), Piece{.Bishop, false}, Piece{.Pawn, true}, Piece{.Rook, true},
    Piece{.Pawn, true}, Piece{.Pawn, false}, piece_none(), piece_none(),
    Piece{.Pawn, false}, piece_none(), piece_none(), piece_none(),
    piece_none(), Piece{.Queen, true}, piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    Piece{.Rook, true}, piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), Piece{.Pawn, false}, piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    piece_none(), piece_none(), piece_none(), piece_none(),
    }

    expect_fen(t, "res/fen/default.fen", default_expected)
    expect_fen(t, "res/fen/fen_test1.fen", fen1_expected)
    expect_fen(t, "res/fen/fen_test2.fen", fen2_expected)
    expect_fen(t, "res/fen/fen_test3.fen", fen3_expected)
    expect_fen(t, "res/fen/fen_test4.fen", fen4_expected)
    expect_fen(t, "res/fen/fen_test5.fen", fen5_expected)
    expect_fen(t, "res/fen/fen_test6.fen", fen6_expected)
    expect_fen(t, "res/fen/fen_test7.fen", fen7_expected)
    expect_fen(t, "res/fen/fen_test8.fen", fen8_expected)
    expect_fen(t, "res/fen/fen_test9.fen", fen9_expected)
    expect_fen(t, "res/fen/fen_test10.fen", fen10_expected)
}