package chain_buffer


import "base:runtime"

import "core:mem"
import "core:log"
import "core:io"
import "core:fmt"
import "core:encoding/ansi"
import str "core:strings"
import "core:testing"
import "core:unicode/utf8"


Line :: struct {
    offset: u32,
    gap: struct {
        start, end: u16, // start..<end
    },
}

Block :: struct {
    allocator: runtime.Allocator,
    buf: []u8,
    lines: [dynamic]Line,
    gap: struct {
        start, end: u32, // start..<end, in bytes
    },
    realsize: u32, // total size of actual data in bytes
}

create :: proc(
    input: io.Reader, capacity: int,
    allocator := context.allocator,
    loc := #caller_location,
) -> Block {
    assert(capacity > 0, "Capacity must be greater than 0", loc)
    
    block: Block

    block.allocator = allocator
    context.allocator = allocator

    block.lines = make([dynamic]Line)
    block.buf = make([]u8, capacity)

    last := u32(len(block.buf))
    block.gap = { last, u32(capacity) }

    // Calculate lines and populate buffer
    offset, linestart: u32
    ch, size, err := io.read_rune(input)
    unmarked_line: bool // indicates if there are line contents that need to be marked
    mainloop: for _ in 0..<capacity {
        #partial switch err {
        case .None: break
        case .EOF:
            break mainloop
        case:
            // Unknown read error...
            log.error("Unknown error while loading buffer")
            break mainloop
        }

        other: rune
        switch ch {
        case '\n': other = '\r'
        case '\r': other = '\n'
        }
        if other != 0 {
            // There is a new-line character
            ch2, size2, err2 := io.read_rune(input)

            lineError := err2 != .None || ch2 != other

            // TODO: Check for line-ending consistency
            if lineError {
                // Invalid new-line, add missing line-ending
                // If line-endings are inconsistant, the user will be asked what line-endings
                // to use when saving the file.
                // bytes, size := utf8.encode_rune(ch)
                // copy_slice(block.buf[offset:offset+u32(size)], bytes[:size])
            }
            
            // Write out 2 null bytes for line ending
            bytes: [2]u8
            log.assertf(len(block.buf) > auto_cast offset+2, "OFFSET {} and {} / +2", len(block.buf), offset)
            copy_slice(block.buf[offset:offset+2], bytes[:])
            offset += 2

            // We must now continue executing the loop
            // This new character may need to be processed
            // So dont't read the next rune.
            // If't there's an error, it will be handled at the top of the loop.
            
            // offset += auto_cast size
            // offset += 1 // Add the extra character

            // TODO: Second gap.start is 65K

            linesize := offset - linestart
            block.realsize += linesize
            // Add the new-line
            append(&block.lines, Line {
                // size = linesize,
                offset = linestart,
                gap = {
                    // Last 2 characters (New-Line) become the gap
                    start = auto_cast linesize - 2,
                    end   = auto_cast linesize,
                },
            })
            unmarked_line = false

            linestart = offset // New-line was added, remember where next line starts

            // Advance to next character, if line had no error
            // TODO: Understand why this needs to be Outside ?
            ch, size, err = io.read_rune(input)
            if !lineError {
            }
        } else {
            // Write character to buffer
            bytes, size := utf8.encode_rune(ch)
            copy_slice(block.buf[offset:offset+u32(size)], bytes[:size])
            unmarked_line = true

            // Advance to next character
            offset += auto_cast size
            ch, size, err = io.read_rune(input)
        }

    }

    // Adds the last line in the file,
    linesize := offset - linestart
    block.realsize += linesize
    append(&block.lines, Line {
        // size = linesize,
        offset = linestart,
        gap = {
            // Last 2 characters (New-Line) become the 
            start = auto_cast linesize - 2,
            end   = auto_cast linesize,
        },
    })
    linestart = offset
    
    return block
}

destroy :: proc(using block: Block) {
    delete(buf, allocator)
    delete(lines)
}

linecount :: #force_inline proc(using block: Block) -> int {
    return len(lines)
}

readline :: proc(
    using block: ^Block, line_index: int,
    loc := #caller_location,
) -> (left, right: string) {
    log.assert(line_index > -1 && line_index < len(lines), "ChainBuffer: line index out of range", loc)

    line := &lines[line_index]

    log.assert(line.offset < auto_cast len(buf), "Line offset out of range")

    // TODO: fn Line capacity
    linecapacity: u32
    if line_index + 1 >= len(lines) {
        linecapacity = u32(len(buf)) - line.offset
    } else {
        nextline := &lines[line_index + 1]
        linecapacity = nextline.offset - line.offset
    }

    if line.gap.start == 0 {
        left = ""
    } else {
        log.info("GAPSTART:", line.gap.start)
        offset := line.offset
        size := line.offset+u32(line.gap.start)
        left = string(buf[offset:size])
    }

    if u32(line.gap.end) == linecapacity {
        right = ""
    } else {
        offset := line.offset + u32(line.gap.end)
        size := linecapacity - u32(line.gap.end)
        right = string(buf[offset:size])
    }

    return
}
