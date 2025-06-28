package main


import "base:runtime"

import "core:mem"
import "core:log"
import "core:fmt"
import "core:io"
import "core:os"
import "core:encoding/ansi"
import str "core:strings"
import "core:testing"
import "core:unicode/utf8"

import tb "tui/termbox2"
import "tui"

import "chain"


Editor :: struct {
    buffer: chain.Block, // Chainbuffer
}

edit_load :: proc(using edit: ^Editor, path: string) {
    handle, err := os.open(path)
    log.assertf(err == nil, "Failed to load File: {}", path)
    defer os.close(handle)

    read := io.to_reader(os.stream_from_handle(handle))

    edit_init(edit, read)
}

edit_init :: proc(using edit: ^Editor, input: io.Reader) {
    buffer = chain.create(input, 1024)
}

edit_dispose :: proc(using edit: ^Editor) {

    chain.destroy(buffer)
}

edit_linecount :: proc(using edit: ^Editor) -> int {
    return chain.linecount(buffer)
}

edit_printline :: proc(
    edit: ^Editor, line_index: int, build: ^str.Builder, loc := #caller_location,
) {
    left, right := chain.readline(&edit.buffer, line_index, loc)

    str.write_string(build, left)
    str.write_string(build, right)
}
