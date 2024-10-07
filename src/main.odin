package main


import "core:log"
import "core:fmt"
import "core:os"
import "core:io"
import "core:mem"
import "core:encoding/ansi"
import str "core:strings"
import "core:testing"

import "editor"

import tb "tui/termbox2"
import "tui"


@test
maintest :: proc(t: ^testing.T) {
    testing.cleanup(t, proc(data: rawptr) {
        tui.shutdown(&ctx)
    }, nil)

    main()
}

status: str.Builder

edit: Editor
cursor: [2]i32
ctx: tui.Context

state: struct {
    event: tui.Event,
    layout: struct {
        left, right: i32,
    }
}
_debug: bool

dumbbuffer :: proc() {

    TP :: fmt.tprint
    using io
    // ctx.quit = true // TEMP DEBUG
    handle, err := os.open("sel_debug.txt",
        os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
    assert(err == os.ERROR_NONE, TP("OS Error:", err))
    
    defer os.close(handle)
    W := io.to_write_flusher(os.stream_from_handle(handle))
    defer io.flush(W)
    io.write_string(W, "=== Debug ===\n")

    // TODO: Fix this issue
    /* It seems that when inserting A, 4 bytes are added (should only be 1)
    
    */
    

    for b, i in edit.gap.buf {
        if edit.gap.start == i {
            io.write_string(W, "|")
            continue
        }
        if edit.gap.end == i {
            io.write_string(W, "|")
            continue
        }
        r := rune(b)
        io.write_escaped_rune(W, r, 0)
        io.write_string(W, " ")
    }

    // left, right := gbuff_strings(edit.gap)
    // io.write_string(W, "[[[\n")
    // io.write_string(W, left)
    // io.write_string(W, "\n----\n")
    // io.write_string(W, right)
    // io.write_string(W, "\n]]]\n")

    // io.write_string(W, "Line Starts:\n")
    // for line in edit.lines {
    //     io.write_string(W, " > ")
    //     io.write_int(W, line)
    //     io.write_string(W, "\n")

    // }
}

main :: proc() {
    
    // log.info("HELLO ")

    defer str.builder_destroy(&status)

    tui.init(&ctx)
    defer tui.shutdown(&ctx)

    SAMPLE_TEXT :: `

local gui  = require("gui")
local file = require("file")

local function prepare(path)
    local fd = file.openwrite(file)
    fd.write([[# Generated File]])
    file.close(fd)
end
// `
    // TEMP: INIT EDITOR
    {
        data, ok := os.read_entire_file("README.md")
        assert(ok, "File not found")
        edit.gap = gbuff_make(len(data) + 32)
        // copy_slice(edit.gap.buf, data)
        gbuff_insert_slice(&edit.gap, 0, data)
        delete(data)
        calculate_lines(&edit)
    }
    defer {
        delete(edit.lines)
        delete(edit.gap.buf, edit.gap.allocator)
    }

    state.layout.left, state.layout.right = calculate_layout(&ctx)

    for !ctx.quit {
        state.event = tui.frame(&ctx)
        #partial switch e in state.event {
        case tui.Key:
            using str
            builder_reset(&status)
            write_string(&status, "KEY:  ")
            write_string(&status, fmt.tprint(e.key))
            write_string(&status, ", MODS: ")
            write_string(&status, fmt.tprint(e.mods))
            
            #partial switch e.key {
            // case .ARROW_DOWN:
            //     cursor.y += 1
            // case .ARROW_UP:
            //     cursor.y -= 1
            // case .ARROW_LEFT:
            //     cursor.x -= 1
            // case .ARROW_RIGHT:
            //     cursor.x += 1
            }
            
        case tui.Char:
            using str
            builder_reset(&status)
            
            // write_string(&status, "CHAR: ")
            // write_quoted_rune(&status, e)

            line := edit.lines[cursor.y]
            char := line.offset + int(cursor.x)

            edit_insert_rune(&edit, char, e)
            _debug = true

            dumbbuffer()
        case tui.Mouse:
            // using str
            // builder_reset(&status)
            
            // write_string(&status, "MOUSE: ")
            // write_string(&status, fmt.tprint(e.button))
            // write_string(&status, " - ")
            // write_string(&status, fmt.tprint(e.pos.x, e.pos.y))
            
            // write_string(&status, "   | ")
            // write_string(&status, fmt.tprint(e.mods))
            // if !e.motion && e.button == .Left {

            //     cursor = { left - e.pos.x, e.pos.y }
            // }
        }

        tb.clear()

        gui(&ctx)

        // Status
        tb.print(5, ctx.height - 1, {
            reverse = true,
            dim = true,
        }, {}, str.to_cstring(&status))

    }
}

calculate_layout :: proc(ctx: ^tui.Context) -> (left, right: i32) {
    // Layout
    w := ctx.width
    h := ctx.height

    left_space_desired := i32(120)
    left_min := i32(16)
    text_max := i32(100)
    right_min := i32(32)

    left = (w / 2) - (text_max / 2)
    left = max(left, left_min)

    right = (w / 2) + (text_max / 2)
    right = min(right, (w - right_min))

    return
}

pressed :: proc { mouse_pressed }

mouse_pressed :: proc(button: tui.Button) -> Maybe([2]i32) {
    #partial switch e in state.event {
    case tui.Mouse:
        if !e.motion && e.button == button {
            return e.pos
        }
    }
    return nil
}

gui :: proc(ctx: ^tui.Context) {
    using state
    // Layout
    left := layout.left
    right := layout.right
    text_width := right - left

    switch pos in pressed(.Left) {
    case [2]i32:
        // CURSOR: Mouse to Text Frame
        newCursor := [2]i32 { pos.x - (left + 1), pos.y }

        if newCursor.x < 0 || newCursor.y >= ctx.height - 1 {
            break
        }
        if len(edit.lines) > 0 {
            newCursor.y = clamp(newCursor.y, 0, i32(len(edit.lines) - 1))

            // thisline := line_length(&edit, auto_cast newCursor.y)
            thisline := edit.lines[newCursor.y]
            newCursor.x = min(newCursor.x, i32(thisline.size))
            newCursor.x = max(newCursor.x, 0)
            
            // thislinestart := edit.lines[newCursor.y]

            // edit_setcursor(&edit, auto_cast newCursor.y, auto_cast newCursor.x)
            // New-line character correction
            // Get characters at this line
            // TODO: Protect newlines ?
            // TODO: Unit Tests
            r: rune
            // if thisline.size < 1 {
            //     r = '\x00'
            // } else {
            // }
            r = rune_at_index(&edit, thisline.offset + int(newCursor.x))
            
            str.builder_reset(&status)
            str.write_string(&status, "CHAR: ")
            str.write_quoted_rune(&status, r)
            // str.write_string(&status, " - LINE LENGTH: ")
            // str.write_int(&status, thisline)
            // switch r {
            // case '\n', '\r':
            //     edit_cursor_move(&edit, -1)
            //     newCursor.x -= 1
            //     newCursor.x = max(newCursor.x, 0)
            //     // Skip a second one
            //     r2 := rune_at_index(&edit, thislinestart + int(newCursor.x - 2))
            //     switch r2 {
            //     case '\n', '\r':
            //         // edit_cursor_move(&edit, -1)
            //         newCursor.x -= 1
            //         newCursor.x = max(newCursor.x, 0)
            //     case:
            //     }
            // case:
            // }

            // r = rune_at(&edit)
            // switch r {
            // case '\n', '\r':
            //     edit_cursor_move(&edit, -1)
            //     newCursor.x -= 1
            // }
        } else {
            newCursor = { 0, 0 }
            // Can't use this because the illegal state will make it fail.
            // edit_setcursor(&edit, 0, 0)
            edit.cursor = 0
        }

        cursor = newCursor



        {
            using str
            // builder_reset(&status)
            
            // write_string(&status, "Cursor: ")
            // write_string(&status, fmt.tprint(cursor))
            
            // write_string(&status, "Lines: ")
            // thisline := line_length(&edit, auto_cast len(edit.lines) - 1)
            // write_string(&status, fmt.tprint(thisline))
        }

        // TODO: Only set if within bounds

        // CURSOR: Text Frame to Mouse
        abs_x := newCursor.x + (left + 1)
        abs_y := newCursor.y
        tb.set_cursor(abs_x, abs_y)

    }
    // if len(edit.lines) > 0 {
    //     cursor.y = clamp(cursor.y, 0, i32(len(edit.lines) - 1))
    //     thisline := line_length(&edit, edit.lines[cursor.y])
    //     cursor.x = clamp(cursor.x, left + 1, right - 2)
    // } else {
    //     cursor = { left + 1, 0 }
    // }
    // tb.set_cursor(cursor.x, cursor.y)

    // Modes
    for line in 0..<i32(1) {
        x := left - 18
        tb.print(
            x, line, { reverse = true }, {},
            " WRITE ",
        )
    }

    build := str.builder_make(context.temp_allocator)

    // Editor Lines
    for line in 0..<ctx.height-3 {
        if text_width < 1 do break
        if int(line) >= len(edit.lines) {
            // str.builder_reset(&status)
            // str.write_string(&status, "FILE TOO SHORT")
            break
        }
        // Line number
        lnum := fmt.ctprint(line+1)
        tb.print(
            left - i32(len(lnum)), line,
            { color = .BLACK, bright = true }, {},
            lnum,
        )

        // Text
        liner := edit.lines[line]
        // line_size := line_length(&edit, int(line)) // New lines
        if liner.size < 1 {
            continue
        }
        str.builder_reset(&build)
        // if line == 3 {
        //     log.warn("PRE CRASH:", line_start, "adv", line_size)
        // }

        print_range(&edit, &build, liner.offset, liner.offset + liner.size)
        // assert(line < 3, "END")

        tb.print(
            left + 1, line,
            {}, {},
            str.to_cstring(&build),
        )
    }

    for line in 0..<ctx.height {
        // Edge
        tb.print(right, line, { bright = true, color = .BLACK }, {}, "|")
    }

    // Opened Editors
    for line in 0..<i32(1) {
        tb.print(
            right + 2, line, {}, {},
            "<sample>",
        )
    }

    
}
