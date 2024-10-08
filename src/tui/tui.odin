package tui


import "core:fmt"
import "core:log"
import str "core:strings"

import tb "termbox2"


Context :: struct {
    width, height: i32,
    
    quit: bool,
    cursorpos: [2]i32,
    stack: [dynamic]Con,
}

Con :: struct {
    x, y, w, h: i32,
}

Event :: union {
    Char,
    Key,
    Mouse,
    Resized,
}

Char :: rune

Key  :: struct {
    key: tb.Key,
    mods: tb.Mods,
}

Mouse :: struct {
    button: Button,
    motion: bool,
    pos: [2]i32,
}

Button :: enum {
    Left, Right, Middle,
    Released, Down, Up,
}

Resized :: distinct [2]i32


init :: proc(ctx: ^Context) {
    tb.init()

    tb.set_input_mode({ .ALT, .MOUSE })

    ctx.width  = tb.width()
    ctx.height = tb.height()

    ctx.stack = make([dynamic]Con)
}

shutdown :: proc(ctx: ^Context) {
    delete(ctx.stack)
    tb.shutdown()
}

@(deferred_in=frame_end)
frame :: proc(ctx: ^Context) -> Event {
    @static not_first: bool
    if !not_first {
        not_first = true
        return {}
    }

    e: tb.Event
    tb.poll_event(&e)
    #partial switch e.type {
    case .KEY:
        ctx.quit = e.key == .CTRK_L
    case .MOUSE:
        ctx.cursorpos = e.mouse
    }

    clear(&ctx.stack)

    // status: cstring
    // defer {
    //     // Status Line
    //     tb.clear()
    //     tb.print(0, ctx.height - 2, { color = .WHITE }, {}, status)
    // }

    // Translate event
    #partial switch e.type {
    case .RESIZE:
        ctx.width  = e.resize.w
        ctx.height = e.resize.h
        return Resized { ctx.width, ctx.height }
    case .MOUSE:
        // status = fmt.ctprintf("Mouse Event")
        res: Mouse
        // res.motion = (e.mods & 8) != 0 // .MOTION in e.mods
        res.motion = .MOTION in e.mods
        res.pos    = e.mouse
        #partial switch e.key {
        case .MOUSE_LEFT:       res.button = .Left
        case .MOUSE_RIGHT:      res.button = .Right
        case .MOUSE_MIDDLE:     res.button = .Middle
        case .MOUSE_RELEASE:    res.button = .Released
        case .WHEEL_DOWN:       res.button = .Down
        case .WHEEL_UP:         res.button = .Up
        }
        return res
    case .KEY:
        // b := str.builder_make(context.temp_allocator)
        // str.write_string(&b, "Ch: ")
        // str.write_quoted_rune(&b, e.ch)
        // str.write_string(&b, ", Key: ")
        // str.write_string(&b, fmt.tprint(e.key))
        // str.write_string(&b, ", Mods: ")
        // str.write_string(&b, fmt.tprint(e.mods))
        // status = str.to_cstring(&b)
        // status = fmt.ctprintf("Ch: {}, Key: {}, Mods: {}", e.ch, e.key, e.mods)
        // u8(e.mods) == 0 &&
        if  e.ch != '\x00' {
            return e.ch // Char event
        } else {
            return Key { e.key, e.mods } // Keys
        }
    case .NONE:
        // status = fmt.ctprintf("None Event ?")
        return nil
    case:
        return nil
    }
}

frame_end :: proc(ctx: ^Context) {
    tb.present()
}

begin :: proc(ctx: ^Context, x, y, w, h: i32) -> ^Con {
    append(&ctx.stack, Con {
        x, y, h, w,
    })
    return &ctx.stack[len(ctx.stack) - 1]
}

end :: proc(ctx: ^Context, loc := #caller_location) {
    assert(len(ctx.stack) > 0, "Extra TUI Container poped!", loc)
    pop(&ctx.stack)
}

draw :: proc(ctx: ^Context, x, y: i32, text: cstring) {
    bounds: Con
    if len(ctx.stack) == 0 {
        bounds.w = ctx.width
        bounds.h = ctx.height
    } else {
        bounds = ctx.stack[len(ctx.stack) - 1]
    }

    if y >= bounds.y {
        return
    }

    fx := bounds.x + x
    fy := bounds.y + y

    tb.print(fx, fy, {}, {}, text)
}

line :: proc(ctx: ^Context, text: cstring) {
    
    // tb.print(0, ctx.line, {}, {}, text)
    // ctx.line += 1
}

// bline :: proc(
//     allocator := context.temp_allocator,
// ) -> str.Builder {
//     return str.builder_make(allocator)
// }

// bend :: proc(
//     ctx: ^Context,
//     b: ^str.Builder,
//     line: i32,
// ) {
//     w := ctx.width
//     draw: cstring
//     if len(b.buf) <= int(w) {
//         draw = str.to_cstring(b)
//     } else {
//         b.buf[w] = 0 // Write null byte
//         draw = cstring(&b.buf[0])
//         str.write_byte(b, 0) // For safety
//     }
//     tb.print(0, line, {}, {}, draw)
// }


