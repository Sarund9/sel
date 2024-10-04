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

import "core:container/rbtree"
import "core:text/scanner"


Editor :: struct {
    gap: GapBuffer,
    cursor: int,
    lines: [dynamic]int, // where does each line start
}

// O(n)
calculate_lines :: proc(ed: ^Editor) {

    clear(&ed.lines)
    left, right := gbuff_strings(ed.gap)
    append(&ed.lines, 0) // Start of file

    // TODO: File Chunks
    // TODO: Only invalidate after cursor
    // TODO: Handle wrapping screen width
    for c, i in left {
        if c == '\n' {
            append(&ed.lines, i + 1)
        }
    }
    for c, i in right {
        if c == '\n' {
            append(&ed.lines, len(left) + i + 1)
        }
    }
}

line_length :: proc(e: ^Editor, line_index: int, loc := #caller_location) -> int {
    assert(line_index >= 0 && line_index < len(e.lines), "Invalid Line Index", loc)

    if line_index >= len(e.lines) - 1 {
        buflen := gbuff_len(e.gap)
        return buflen - e.lines[len(e.lines) - 1 ]
    } else {
        starts := e.lines[line_index]
        next := e.lines[line_index + 1]
        return next - starts
    }
}

edit_insert :: proc(e: ^Editor, cursor: int, text: string) {
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

// TODO: UTF8 SUPPORT
rune_at :: proc(e: ^Editor) -> rune {
    cursor := clamp(e.cursor, 0, gbuff_len(e.gap) - 1)
    left, right := gbuff_strings(e.gap)
    if cursor < len(left) {
        return rune(left[cursor])
    } else {
        return rune(right[cursor])
    }
}

print_range :: proc(
    e: ^Editor,
    build: ^str.Builder,
    start, end: int,
) {
    left, right := gbuff_strings(e.gap)
    assert(start >= 0)
    assert(end <= gbuff_len(e.gap))

    leftl := len(left)
    if end < leftl {
        str.write_string(build, left[start:end])
    } else if start >= leftl {
        str.write_string(build, right[start:end])
    } else {
        str.write_string(build, left[start:])
        str.write_string(build, right[:end])
    }
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
