package main


import "core:log"
import "core:fmt"
import "core:os"
import "core:io"
import "core:mem"
import "core:encoding/ansi"
import str "core:strings"
import "core:testing"
import "core:time"

import tb "tui/termbox2"
import "tui"


state: State

State :: struct {
    status: str.Builder,
    
    cursor: [2]i32,
    ctx: tui.Context,
    
    edit: Editor,

    event: tui.Event,
    layout: struct {
        left, right: i32,
    }
}

@test
maintest :: proc(t: ^testing.T) {
    testing.cleanup(t, proc(data: rawptr) {
        
        tui.shutdown(&state.ctx)
    }, nil)

    time.sleep(time.Millisecond * 200) // Wait 200ms

    // chainbuf:184 30:65564

    main()
}

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
    

}

main :: proc() {
    
    // log.info("HELLO ")

    defer str.builder_destroy(&state.status)

    tui.init(&state.ctx)
    defer tui.shutdown(&state.ctx)

    SAMPLE_TEXT :: `

local gui  = require("gui")
local file = require("file")

local function prepare(path)
    local fd = file.openwrite(file)
    fd.write([[# Generated File]])
    file.close(fd)
end
// `

    edit_load(&state.edit, "README.md")

    state.layout.left, state.layout.right = calculate_layout(&state.ctx)

    for !state.ctx.quit {
        state.event = tui.frame(&state.ctx)
        #partial switch e in state.event {
        case tui.Key:
            using str
            builder_reset(&state.status)
            write_string(&state.status, "KEY:  ")
            write_string(&state.status, fmt.tprint(e.key))
            write_string(&state.status, ", MODS: ")
            write_string(&state.status, fmt.tprint(e.mods))
            
            left, right := calculate_layout(&state.ctx)

            #partial switch e.key {
            // case .ARROW_DOWN:
            //     cursor.y += 1
            // case .ARROW_UP:
            //     cursor.y -= 1
            case .ARROW_LEFT:
                
            case .ARROW_RIGHT:
                
            }
            
        case tui.Char:
            using str
            builder_reset(&state.status)
            
        case tui.Mouse:
            
        }

        tb.clear()

        gui(&state.ctx)

        // Status
        tb.print(5, state.ctx.height - 1, {
            reverse = true,
            dim = true,
        }, {}, str.to_cstring(&state.status))

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
        if int(line) >= edit_linecount(&edit) {
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
        // liner := edit.lines[line]
        // line_size := line_length(&edit, int(line)) // New lines
        // if liner.size < 1 {
        //     continue
        // }
        str.builder_reset(&build)
        edit_printline(&edit, int(line), &build)
        // if line == 3 {
        //     log.warn("PRE CRASH:", line_start, "adv", line_size)
        // }

        // print_range(&edit, &build, liner.offset, liner.offset + liner.size)
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
