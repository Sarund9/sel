package main


import "core:log"
import "core:io"
import "core:os"
import str "core:strings"
import test "core:testing"

import "chain"


TEST_TEXT :: `# Stacking Editor Layers



`

@test
chain_tests :: proc(t: ^test.T) {

    read: str.Reader
    stream := str.to_reader(&read, TEST_TEXT)

    block := chain.create(stream, 1024)

    // EXPECT: Block integrity
    {
        log.warnf("TEST TEXT:\n{}", TEST_TEXT)
        log.warnf("BUFFER:\n{}", string(block.buf[:len(TEST_TEXT)]))
        text := TEST_TEXT
        for b, i in block.buf {
            // exp := i < len(text) ? text[i] : '\x00'
            // switch exp {
            // case '\n', '\r':
            //     continue // 
            // }
            exp := i < len(text) ? text[i] : '\x00'
            switch exp {
            case '\n', '\r': exp = 0
            }
            // exp := text[i]
            test.expectf(
                t, b == exp,
                "Block memory not correct, byte '{}' was '{}', expected: {}",
                i, b, exp,
            )
        }
    }

    // EXPECT: Lines
    // test.expectf(t, len(block.lines) == 5, "Lines was length: {}", len(block.lines))
    
    testline :: proc(t: ^test.T, lines: []chain.Line, index: int, expect: chain.Line) {
        test.expectf(
            t, index > -1 && index < len(lines),
            "Line index is out of range: {} not in 0..<{}",
            index, len(lines),
        )
        test.expectf(t, lines[index] == expect, "Line {} is wrong: {}", index, lines[index])
    }

    // Line Tests                    size  start end
    // testline(t, block.lines[:], 0, { 26, { 24, 26 } })
    // testline(t, block.lines[:], 1, { 2, { 0, 2 } })
    // testline(t, block.lines[:], 2, { 2, { 0, 2 } })
    // testline(t, block.lines[:], 3, { 2, { 0, 2 } })
    // testline(t, block.lines[:], 4, { 0, { 0, 0 } })




    // log.info("LINES:\n > ",
    //     block.lines[0], "\n > ",
    //     block.lines[1], "\n > ",
    //     block.lines[2], "\n > ",
    //     block.lines[3], "\n > ",
    //     block.lines[4], "\n",
    // )
}

