package text_editor




Buffer :: struct {
    original: []byte,
    additions: [dynamic]byte,
    pieces: [dynamic]Piece,
    // lines: [dynamic]Ref,
}

Piece :: struct {
    added: bool,
    offset, length: int,
}

Ref :: struct {
    piece, offset: int,
}

create :: proc(using tab: ^Buffer, data: []u8) {
    original = data
    additions = make([dynamic]byte)
    pieces = make([dynamic]Piece)

    // Add the first Piece
    append(&tab.pieces, Piece { false, 0, len(data) })

    // lines = make([dynamic]Ref)

    // Construct list of Lines
    // newline: byte
    // for ch, index in original {

    //     switch newline {
    //     case '\r':
    //         if ch == '\n' {
    //             continue
    //         }

    //         newline = '\x00'
    //         append(&lines, Ref {
    //             0,     // -1 means the original buffer
    //             index, // index where the line starts
    //         })

    //     case '\n':
    //         if ch == '\r' {
    //             continue
    //         }
            
    //     case '\x00':
    //         switch ch {
    //         case '\n', '\r':
    //             newline = ch
    //         }
    //     }
    // }
}

destroy :: proc(using tab: ^Buffer) {
    delete(additions)
    delete(pieces)
    // delete(lines)
}

append_end :: proc(using tab: ^Buffer, text: string) {
    // Add the Piece to the end of the Table
    of := len(additions)
    append_string(&additions, text)
    append(&pieces, Piece {
        added = true,
        offset = of,
        length = len(text),
    })
}


insert :: proc(using tab: ^Buffer, cursor: int, text: string) {
    
    // if line >= len(lines) || line < 0 do return
    // lref := &lines[line]
    
    // if lref.piece < 0 || lref.piece >= len(pieces) do return
    // piece := &pieces[lref.piece]

    // Advance
    // adv := column
    // adv_i := lref.piece
    // for adv >= piece.length {
    //     // Goto next piece
    //     adv -= piece.length
    //     adv_i += 1
    //     // Extension of the array is required
    //     if adv_i >= len(pieces) {

    //     }
    //     piece = &pieces[adv_i]
    // }

    // Add the Piece to the end of the Table
    // of := len(additions)
    // append_string(&additions, text)
    // append(&pieces, Piece {
    //     added = true,
    //     offset = of,
    //     length = len(text),
    // })
    
    // End of additions
    // if !piece.added && piece.offset + piece.length == len(additions) {
    //     append_string(&additions, text)
    // }
}

