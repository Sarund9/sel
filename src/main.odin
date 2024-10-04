package main


import "core:log"
import "core:fmt"
import "core:os"
import "core:mem"
import "core:encoding/ansi"
import str "core:strings"
import "core:testing"

import tb "tui/termbox2"
import "tui"


@test
maintest :: proc(_: ^testing.T) {
    main()
}

cursor: [2]i32
status: str.Builder

edit: Editor


main :: proc() {
    
    ctx: tui.Context
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
        data, ok := os.read_entire_file("testbed/alacritty.toml")
        assert(ok, "File not found")
        edit.gap = gbuff_make(len(data) + 32)
        copy_slice(edit.gap.buf, data)
        delete(data)
        calculate_lines(&edit)
    }
    defer {
        delete(edit.lines)
        delete(edit.gap.buf, edit.gap.allocator)
    }


    for !ctx.quit {
        ev := tui.frame(&ctx)
        #partial switch e in ev {
        case tui.Key:
            using str
            builder_reset(&status)
            write_string(&status, "KEY:  ")
            write_string(&status, fmt.tprint(e.key))
            write_string(&status, ", MODS: ")
            write_string(&status, fmt.tprint(e.mods))
            
            
        case tui.Char:
            using str
            builder_reset(&status)
            
            write_string(&status, "CHAR: ")
            write_quoted_rune(&status, e)
        case tui.Mouse:
            using str
            builder_reset(&status)
            
            write_string(&status, "MOUSE: ")
            write_string(&status, fmt.tprint(e.button))
            write_string(&status, " - ")
            write_string(&status, fmt.tprint(e.pos.x, e.pos.y))
            
            // write_string(&status, "   | ")
            // write_string(&status, fmt.tprint(e.mods))
            if !e.motion {
                tb.set_cursor(e.pos.x, e.pos.y)
            }
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

gui :: proc(ctx: ^tui.Context) {

    // Split area in 3 parts
    {
    }

    // Layout
    w := ctx.width
    h := ctx.height

    left_space_desired := i32(120)
    left_min := i32(16)
    text_max := i32(100)
    right_min := i32(32)

    left := (w / 2) - (text_max / 2)
    // if left < left_min {
    //     left = left_min
    // }
    left = max(left, left_min)

    right := (w / 2) + (text_max / 2)
    right = min(right, (w - right_min))

    text_width := right - left

    // // Min: 16 on each side
    // if text_width + 32 > w {
    //     text_width = w - 33
    // }

    // side_width := (w - text_width - 2) / 2

    // // Move to `text_start` when posible
    // {
    //     newwidth := text_start
    //     if newwidth + text_width + 16 > w {

    //     }
    // }
    
    // left  := side_width
    // right := left + text_width

    // Guides
    // tb.print(left,  0, { color = .RED, bold = true }, {}, "|")
    // tb.print(right, 0, { color = .RED, bold = true }, {}, "|")

    // Modes
    for line in 0..<i32(1) {
        x := left - 18
        // tb.print(x, line, { bright = true, color = .BLACK }, {}, "|")
        // x += 2
        tb.print(
            x, line, { reverse = true }, {},
            " WRITE ",
        )
        // x += 6
        // tb.print(x, line, { bright = true, color = .BLACK }, {}, "|")
    }


//     SAMPLE_TEXT :: `

// local gui  = require("gui")
// local file = require("file")

// local function prepare(path)
//     local fd = file.openwrite(file)
//     fd.write([[# Generated File]])
//     file.close(fd)
// end
// `
//     sample_lines := str.split(SAMPLE_TEXT, "\n", context.temp_allocator)


    build := str.builder_make(context.temp_allocator)

    // Editor Lines
    for line in 0..<h-3 {
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
        line_start := edit.lines[line]
        line_size := line_length(&edit, int(line))
        str.builder_reset(&build)
        print_range(&edit, &build, line_start, line_start + line_size)

        tb.print(
            left + 1, line,
            {}, {},
            str.to_cstring(&build),
        )
        
        // text := sample_lines[line]
        // endchar := text_width - 2
        // if endchar < 1 do continue

        // if i32(len(text)) >= endchar {
        //     text = text[:endchar]
        // }
        // tb.print(
        //     left + 1, line,
        //     {}, {},
        //     str.clone_to_cstring(text, context.temp_allocator),
        // )

    }

    for line in 0..<h {
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


    // Determine layout
    // {
    //     w := ctx.width
    //     text_width := i32(120)
    //     // Min: 10 on each side
    //     if text_width + 20 > w {
    //         text_width = w - 21
    //     }
    //     side_width := (w - text_width - 2) / 2

    //     // 0000_0001_0000_0000__0000_0000_0000_0000

    //     // Draw lines
    //     for l in 0..<ctx.height {
    //         // at := tb.Attr {
    //         //     color = .BLACK,
    //         //     bright = true,
    //         // }
    //         // tb.print(side_width, l, {
    //         //     color = .WHITE,
    //         //     dim = true,
    //         // }, {}, "  0 ")

    //         // tb.print(w - side_width, l, {
    //         //     color = .BLACK,
    //         //     bright = true,
    //         // }, {}, "|")

    //         // b := tui.bline()
    
    //         // for i in 0..<side_width {
    //         //     str.write_byte(&b, ' ')
    //         // }
    //         // str.write_string(&b, fmt.tprintf("{}|{}", ansi.FG_BRIGHT_BLACK, ansi.FG_WHITE))
    //         // for i in 0..<text_width {
    //         //     str.write_byte(&b, ' ')
    //         // }
    //         // str.write_byte(&b, '|')
    //         // for i in 0..<side_width {
    //         //     str.write_byte(&b, ' ')
    //         // }
    
    //         // tui.bend(ctx, &b, l)
    //     }

    //     // Draw Cursor
    //     // tb.print(cursor.x, cursor.y, {
    //     //     reverse = true,
    //     // }, {}, " ")
    // }

}
