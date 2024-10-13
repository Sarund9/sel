package main


import "base:runtime"

import "core:mem"
import "core:log"
import "core:fmt"
import "core:encoding/ansi"
import str "core:strings"
import "core:testing"
import "core:unicode/utf8"

import tb "tui/termbox2"
import "tui"


Editor :: struct {
    gap: GapBuffer,
    cursor: int,
    lines: [dynamic]Line_Range, // where does each line start
}

Pos :: struct {
    pos: u64,
    lin, col: u32,
}

Line_Range :: struct {
    offset, size: int,
}

// O(n)
calculate_lines :: proc(ed: ^Editor) {

    clear(&ed.lines)

    // TODO: File Chunks
    // TODO: Only invalidate after cursor
    // TODO: Handle wrapping screen width

    left, right := gbuff_strings(ed.gap)
    start: int
    state := false
    for c, i in left {
        switch c {
        case '\n', '\r':
            if state {
                state = false
                start = i + 1 // Starting on the next line.
                break
            }
            append(&ed.lines, Line_Range { start, i - start })
            state = true
        case:
            if !state do break
            state = false
            start = i
        }
    }

    start = len(left)
    state = false
    for c, i in right {
        switch c {
        case '\n', '\r':
            if state {
                state = false
                start = len(left) + i + 1 // Starting on the next line.
                break
            }
            append(&ed.lines, Line_Range { start, (len(left) + i) - start })
            state = true
        case:
            if !state do break
            state = false
            start = i
        }
    }
}

line_length :: proc(e: ^Editor, line_index: int, loc := #caller_location) -> int {
    assert(line_index >= 0 && line_index < len(e.lines), "Invalid Line Index", loc)

    return e.lines[line_index].size

    // if line_index >= len(e.lines) - 1 {
    //     // If it's the last line..
    //     buflen := gbuff_len(e.gap)
    //     line := e.lines[len(e.lines) - 1 ]
    //     return line.size
    // } else {
    //     starts := e.lines[line_index]
    //     next := e.lines[line_index + 1]
    //     return next - starts // - 2 // NEW LINES, 
    //     // TODO: HANDLE THIS BETTER
    // }
}

edit_insert_rune :: proc(e: ^Editor, cursor: int, char: rune) {
    gbuff_insert_rune(&e.gap, cursor, char)
    e.cursor += utf8.rune_size(char)
    calculate_lines(e)
}

edit_insert_string :: proc(e: ^Editor, cursor: int, text: string) {
    gbuff_insert_string(&e.gap, cursor, text)
    e.cursor += len(text)
    calculate_lines(e)
}

edit_remove :: proc(e: ^Editor, cursor, count: int) {
    ecursor := cursor
    if count < 0 {
        ecursor -= 2
    }
    gbuff_remove(&e.gap, cursor, count)
    if count < 0 {
        e.cursor = max(0, e.cursor + count)
    }
    calculate_lines(e)
}

// edit_setcursor :: proc(e: ^Editor, line, char: int, loc := #caller_location) {
//     assert(line >= 0 && line < len(e.lines), "Line Index out of range", loc)
//     linestart := e.lines[line]
//     e.cursor = linestart + char
//     if e.gap.start < e.cursor && e.gap.start > linestart {
        
//         // Before start
//         // before_start := max(e.gap.start - linestart, 0)
//         // After end
//         // after_end := max((linestart + char) - e.gap.end, 0)
//         gap_size := (e.gap.start - e.gap.end)
//         // if end is less than linestart+char
//         // then reduce that difference
//         diff := max((linestart + char) - e.gap.end, 0)

//         gap_overlap := gap_size - diff

//         e.cursor = linestart + char + gap_overlap

//         // e.cursor += max(e.gap.start - linestart, 0)
//         // e.cursor += max((linestart + char) - e.gap.end, 0)
//     }
// }


edit_cursor_move :: proc(
    e: ^Editor,
    delta: int,
    loc := #caller_location,
) -> (moved: int) {
    size := gbuff_len(e.gap)
    newPos := e.cursor + delta
    newPos = clamp(newPos, 0, size - 1)

    // cursor2D.x += i32(newPos - e.cursor) // TODO: New-Line processing
    // cursor2D.x = i32(newPos)
    // str.builder_reset(&status)
    // str.write_string(&status, fmt.tprintf("CURSOR MOVED FROM {} to {} by {}", e.cursor, newPos, i32(newPos - e.cursor)))

    if delta < 0 {
        // Moved backwards inside the gap
        if e.cursor >= e.gap.start && newPos < e.gap.end {
            // If the gap is at the beginning
            if e.gap.start == 0 {
                newPos = 0
            } else {
                newPos = e.gap.start + (delta + (e.cursor - e.gap.end))
            }
        }
    } else {
        // Moved forwards inside the gap
        if e.cursor < e.gap.start && newPos >= e.gap.start {
            // If the gap is at the end
            if e.gap.end == len(e.gap.buf) {
                newPos = size
            } else {
                newPos = e.gap.end + (delta - (e.cursor - e.gap.start))
            }
        }
    }
    // // TODO: New Lines
    // other: rune
    // switch rune_at_cursor(e) {
    // case '\n': other = '\r'
    // case '\r': other = '\n'
    // }

    moved = newPos - e.cursor
    e.cursor = newPos
    return
}

// TODO: UTF8 SUPPORT
rune_at_cursor :: proc(e: ^Editor) -> rune {
    cursor := clamp(e.cursor, 0, gbuff_len(e.gap) - 1)
    left, right := gbuff_strings(e.gap)
    if cursor < len(left) {
        return rune(left[cursor])
    } else {
        return rune(right[cursor])
    }
}

rune_at_index :: proc(e: ^Editor, charIndex: int) -> rune {
    charIndex := clamp(charIndex, 0, gbuff_len(e.gap) - 1)
    left, right := gbuff_strings(e.gap)
    if charIndex < len(left) {
        return rune(left[charIndex])
    } else {
        return rune(right[charIndex])
    }
}

print_range :: proc(
    e: ^Editor,
    build: ^str.Builder,
    start, end: int,
    loc := #caller_location,
) {
    size := gbuff_len(e.gap)
    left, right := gbuff_strings(e.gap)
    assert(start >= 0, "Start index cannot be negative", loc)
    assert(start < end, "End index must be greater than start", loc)
    assert(end <= size, "End index is out of range", loc)

    leftl := len(left)
    if end <= leftl {
        str.write_string(build, left[start:end])
    } else if start >= leftl {
        // if _debug {
        //     log.warn("PRECRASH:", start, end, "-", len(right))
            
        //     assert(start != 34, "STOP")
        // }
        
        str.write_string(build, right[start-leftl:end-leftl])
    } else {
        str.write_string(build, left[start:])
        // if start > 26 {
        //     log.errorf("PRE CRASH: '{}' END: {}", right, end)
        //     log.errorf("OTHER: '{}' START: {}", left, start)
        // }
        if end < len(right) {
            str.write_string(build, right[:end-leftl])
        }
        // assert(start <= 26, "BOTH")
    }
    // assert(start <= 26, "END")

}



GapBuffer :: struct {
    allocator: runtime.Allocator,
    buf: []u8,
    start, end: int,
}

gbuff_len :: proc(gap: GapBuffer) -> int {
    gapsize := gap.end - gap.start
    return len(gap.buf) - gapsize
}

gbuff_make :: proc(
    capacity := 32, allocator := context.allocator,
) -> GapBuffer {
    b := GapBuffer {}
    b.allocator = allocator
    b.buf = make([]u8, capacity, allocator)
    b.end = capacity
    return b
}

gbuff_destroy :: proc(
    b: GapBuffer,
) {
    delete(b.buf)
}

gbuff_shift :: proc(gap: ^GapBuffer, cursor: int) {
    gap_len := gap.end - gap.start
    // cursor := min(cursor, len(gap.buf))
    cursor := clamp(cursor, 0, len(gap.buf) - gap_len)
    if cursor == gap.start do return

    if gap.start < cursor {
        delta := cursor - gap.start
        mem.copy(
            &gap.buf[gap.start], &gap.buf[gap.end], delta)
        gap.start += delta
        gap.end   += delta
    } else if gap.start > cursor {
        delta := gap.start - cursor
        mem.copy(
            &gap.buf[gap.end - delta],
            &gap.buf[gap.start - delta], delta)
        gap.start -= delta
        gap.end   -= delta
    }
}

gbuff_ensure :: proc(gap: ^GapBuffer, capacity: int) {
    gap_size := gap.end - gap.start

    if gap_size < capacity {
        gbuff_shift(gap, len(gap.buf) - gap.end)
        newBuf := make([]u8, 2 * len(gap.buf), gap.allocator)
        copy_slice(newBuf, gap.buf[:])
        delete(gap.buf)
        gap.buf = newBuf
        gap.end = len(gap.buf)
    }
}

gbuff_insert :: proc {
    gbuff_insert_char,
    gbuff_insert_slice,
    gbuff_insert_rune,
    gbuff_insert_string,
}

gbuff_insert_char :: proc(gap: ^GapBuffer, cursor: int, char: u8) {
    gbuff_ensure(gap, 1)
    gbuff_shift(gap, cursor)
    gap.buf[gap.start] = char
    gap.start += 1
}

gbuff_insert_slice :: proc(gap: ^GapBuffer, cursor: int, slice: []u8) {
    gbuff_ensure(gap, len(slice))
    gbuff_shift(gap, cursor)

    copy_slice(gap.buf[gap.start:], slice)
    gap.start += len(slice)
}

gbuff_insert_rune :: proc(gap: ^GapBuffer, cursor: int, char: rune) {
    bytes, length := utf8.encode_rune(char)
    gbuff_insert_slice(gap, cursor, bytes[:])
}

gbuff_insert_string :: proc(gap: ^GapBuffer, cursor: int, str: string) {
    gbuff_insert_slice(gap, cursor, transmute([]u8) str)
}

gbuff_remove :: proc(gap: ^GapBuffer, cursor: int, count: int) {
    del := abs(count)
    ef_cursor := cursor
    if cursor < 0 do ef_cursor = max(0, ef_cursor - del)

    gbuff_shift(gap, ef_cursor)
    gap.end = min(gap.end + del, len(gap.buf))
}

gbuff_strings :: proc(gap: GapBuffer) -> (left, right: string) {
    return string(gap.buf[:gap.start]), string(gap.buf[gap.end:])
}
