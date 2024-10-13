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
    size: u32,
    gap: struct {
        start, end: u16, // start..<end
    },
}

Block :: struct {
    allocator: runtime.Allocator,
    buf: []u8,
    lines: [dynamic]Line,
    gap: struct {
        start, end: u32, // start..<end
    },
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

            linesize := offset - linestart
            // Add the new-line
            append(&block.lines, Line {
                size = linesize,
                gap = {
                    // Last 2 characters (New-Line) become the 
                    start = auto_cast linesize - 2,
                    end   = auto_cast linesize,
                },
            })

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

            // Advance to next character
            offset += auto_cast size
            ch, size, err = io.read_rune(input)
        }

    }

    // assert(false)

    return block
    /*
    {
        OLD ATTEMPTS
        
        // MINI LEXER
        Lex :: struct {
            input: io.Reader,
            index: i64,
            ch: rune,
            size: int,
            err: io.Error,
        }

        next :: proc(using lex: ^Lex) -> bool {
            if err != .None do return false // in case of repeated advance after error

            ch, size, err = io.read_rune(input)
            index += 1
            #partial switch err {
            case .None: return true
            case .EOF:  return false
            case:
                // Unknown read error...
                log.error("Unknown error while loading buffer")
                return false
            }
        }

        newline :: proc(lex: ^Lex) -> bool {
            switch lex.ch {
            case '\n', '\r': return true
            }
            return false
        }


        lex := Lex {
            input = input,
            index = -1,
        }

        // Add line
        append(&block.lines, Line {})
        if next(&lex) do mainloop: for {
            // Line contents
            line := &block.lines[len(block.lines) - 1]
            if !newline(&lex) {
                for {
                    line.gap.start += 1
                    if !next(&lex) {
                        // Last line, gap is 0
                        line.gap.end = line.gap.start
                        break mainloop
                    }
                    if newline(&lex) {
                        break
                    }
                }
                
            }
            
            // Get the next character, should be a new-line
            if !next(&lex) || !newline(&lex) {
                // File was corrupted ?
                panic("Unimplemented")
            }

            // Set the line ending
            line.gap.end = line.gap.start + 2
        }
        

        // line: Line
        // i := -1
        // loop: for i < capacity {
        //     i += 1
        //     ch, size, err := io.read_rune(input)
        //     #partial switch err {
        //     case .None: break
        //     case .EOF:
        //         // Last line
        //         log.info("LAST CHAR:", i)
        //         line.gap.start = u16(u32(i) - line.offset)
        //         line.gap.end = line.gap.start
        //         append(&block.lines, line)
        //         break loop
        //     case:
        //         // Unknown read error...
        //         log.error("Unknown error while loading buffer")
        //         break loop
        //     }

        //     other: rune
        //     switch ch {
        //     case '\n': other = '\r'
        //     case '\r': other = '\n'
        //     }
        //     if other != 0 {
        //         line.gap.start = u16(u32(i) - line.offset)   // TODO: Check
        //         line.gap.end = u16(u32(i) - line.offset) + 2 // TODO: Check

        //         // Add the line as [\n]..<[\r]+1
        //         log.info("At", i, "add:", line)
        //         append(&block.lines, line)
        //         line.offset = u32(i) + 2
                
        //         // Skip advance the next rune
        //         ch, size, err := io.read_rune(input)
        //         i += 1
        //         #partial switch err {
        //         case .None: break
        //         case .EOF: break loop
        //         case:
        //             // Unknown read error...
        //             log.error("Unknown error while loading buffer")
        //             break loop
        //         }

        //         switch ch {
        //         case other:
        //             line.offset = u32(i) + 2
        //             continue
        //         case: // Corrupted file ?
        //             // TODO: Add line endings ?
        //         }
                
        //         continue
        //     }

        //     bytes, _ := utf8.encode_rune(ch)
        //     // Write bytes to buffer
        //     copy_slice(block.buf[i:i+size], bytes[:])
        // }

    }
    */
    
}
