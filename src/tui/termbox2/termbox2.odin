package termbox2


import "core:c"

foreign import tbx2 "termbox2/termbox2.o"

Key :: enum u16 {
    CTRL_TILDE = 0,
    CTRL_2 = CTRL_TILDE, // clash with CTRL_TILDE
    CTRL_A,
    CTRL_B,
    CTRL_C,
    CTRL_D,
    CTRL_E,
    CTRL_F,
    CTRL_G,
    BACKSPACE,
    CTRL_H = BACKSPACE, // clash with BACKSPACE
    TAB,
    CTRL_I = TAB,       // clash with TAB
    CTRL_J,
    CTRL_K,
    CTRK_L,
    ENTER,
    CTRL_M = ENTER,     // clash with ENTER
    CTRL_N,
    CTRL_O,
    CTRL_P,
    CTRL_Q,
    CTRL_R,
    CTRL_S,
    CTRL_T,
    CTRL_U,
    CTRL_V,
    CTRL_W,
    CTRL_X,
    CTRL_Y,
    CTRL_Z,
    ESC,
    CTRL_LSQ_BRACKET = ESC,    // clash with ESC
    CTRL_3 = ESC,              // clash with ESC
    CTRL_4,
    CTRL_BACKSLASH = CTRL_4,   // clash with CTRL_4
    CTRL_5,
    CTRL_RSQ_BRACKET = CTRL_5, // clash with CTRL_5,
    CTRL_6,
    CTRL_7,
    CTRL_SLASH = CTRL_7,       // clash with CTRL_7,
    CTRL_UNDERSCORE = CTRL_7,  // clash with CTRL_7,
    SPACE,
    BACKSPACE2 = 0x7f,         // 127
    CTRL_8 = BACKSPACE2,       // clash with BACKSPACE2

    // Terminal Dependant
    F1 = 0xffff - 0,
    F2 = 0xffff - 1,
    F3 = 0xffff - 2,
    F4 = 0xffff - 3,
    F5 = 0xffff - 4,
    F6 = 0xffff - 5,
    F7 = 0xffff - 6,
    F8 = 0xffff - 7,
    F9 = 0xffff - 8,
    F10 = 0xffff - 9,
    F11 = 0xffff - 10,
    F12 = 0xffff - 11,

    INSERT = 0xffff - 12,
    DELETE = 0xffff - 13,

    HOME = 0xffff - 14,
    END  = 0xffff - 15,
    PGUP = 0xffff - 16,
    PGDN = 0xffff - 17,

    ARROW_UP    = 0xffff - 18,
    ARROW_DOWN  = 0xffff - 19,
    ARROW_LEFT  = 0xffff - 20,
    ARROW_RIGHT = 0xffff - 21,

    BACK_TAB    = 0xffff - 22,

    MOUSE_LEFT    = 0xffff - 23,
    MOUSE_RIGHT   = 0xffff - 24,
    MOUSE_MIDDLE  = 0xffff - 25,
    MOUSE_RELEASE = 0xffff - 26,
    WHEEL_UP      = 0xffff - 27,
    WHEEL_DOWN    = 0xffff - 28,
}

Color :: enum {
    DEFAULT,
    BLACK,
    RED,
    GREEN,
    YELLOW,
    BLUE,
    MAGENTA,
    CYAN,
    WHITE,
}

Attr :: bit_field u32 {
    // Color
    color: Color | 4,

    // Discard middle bits
    _: u32 | 20,

    // Options: last 8 bits
    bold:       bool | 1,
    underline:  bool | 1,
    reverse:    bool | 1,
    italic:     bool | 1,
    blink:      bool | 1,
    hi_black:   bool | 1,
    bright:     bool | 1,
    dim:        bool | 1,
}

//! Turns out Attr is the 32bit version


Event_Type :: enum u8 {
    NONE = 0,
    KEY,
    RESIZE,
    MOUSE,
}

Mod :: enum {
    ALT,
    CTRL,
    SHIFT,
    MOTION,
}
Mods :: bit_set[Mod; u8]

Input :: enum {
    ESC,
    ALT,
    MOUSE,
}
Input_Mode :: bit_set[Input; i32]

Output_Mode :: enum i32 {
    CURRENT,
    NORMAL,
    _256,
    _216,
    GRAYSCALE,
    // TODO: True Color ?
}

Error :: enum i32 {
    OK = 0,
    ERR = -1,
    NEED_MORE = -2,
    INIT_ALREADY = -3,
    INIT_OPEN = -4,
    MEM = -5,
    NO_EVENT = -6,
    NO_TERM = -7,
    NOT_INIT = -8,
    OUT_OF_BOUNDS = -9,
    READ = -10,
    RESIZE_IOCTL = -11,
    RESIZE_PIPE = -12,
    RESIZE_SIGACTION = -13,
    POLL = -14,
    TCGETATTR = -15,
    TCSETATTR = -16,
    UNSUPPORTED_TERM = -17,
    RESIZE_WRITE = -18,
    RESIZE_POLL = -19,
    RESIZE_READ = -20,
    RESIZE_SSCANF = -21,
    CAP_COLLISION = -22,

    SELECT = POLL,
    RESIZE_SELECT = RESIZE_POLL,
}

Cell :: struct {
    ch: rune,
    fg, bg: Attr,
}

Event :: struct {
    type: Event_Type,
    mods: Mods,
    key: Key,
    ch: rune,
    resize: struct { w, h: i32 },
    mouse: [2]i32,
}

Extract_Func :: enum i32 {
    PRE, POST,
}

@(default_calling_convention="c", link_prefix="tb_")
foreign tbx2 {
    init            :: proc() -> Error ---
    shutdown        :: proc() -> Error ---
    
    // Buffers
    width           :: proc() -> i32 ---
    height          :: proc() -> i32 ---

    clear           :: proc() -> Error ---
    set_clear_attrs :: proc(fg, bg: Attr) -> Error ---
    present         :: proc() -> Error ---

    set_cursor      :: proc(x, y: i32) -> Error ---
    hide_cursor     :: proc() -> Error ---

    set_cell        :: proc(x, y: i32, ch: rune, fg, bg: Attr) -> Error ---
    set_cell_ex     :: proc(x, y: i32, ch: [^]rune, nch: c.size_t, fg, bg: Attr) -> Error ---
    extend_cell     :: proc(x, y: i32, ch: rune) -> Error ---

    set_input_mode  :: proc(mode: Input_Mode) -> Error ---
    set_output_mode :: proc(mode: Output_Mode) -> Error ---

    peek_event      :: proc(e: ^Event, timeout_ms: i32) -> Error ---
    poll_event      :: proc(e: ^Event) -> Error ---

    get_fds         :: proc(ttyfd: ^i32, resizefd: ^i32) -> Error ---

    print           :: proc(x, y: i32, fg, bg: Attr, str: cstring) -> Error ---
    printf          :: proc(
        x, y: i32, fg, bg: Attr, fmt: cstring, #c_vararg args: ..any,
    ) -> Error ---
    print_ex        :: proc(
        x, y: i32, fg, bg: Attr, out_w: ^c.size_t, str: cstring,
    ) -> Error ---
    printf_ex       :: proc(
        x, y: i32, fg, bg: Attr, out_w: ^c.size_t,
        str: cstring, #c_vararg args: ..any,
    ) -> Error ---

    send            :: proc(buf: cstring, nbuf: c.size_t) -> Error ---
    sendf           :: proc(fmt: cstring, #c_vararg args: ..any) -> Error ---

    set_func        :: proc(
        fn_type: Extract_Func,
        fn: proc "c" (e: ^Event, s: ^c.size_t),
    ) -> Error ---

    // utf8_char_length :: proc(c: u8) -> i32 ---
    // utf8_char_to_unicode :: proc(out: ^rune, c: cstring) -> Error ---
    // utf8_unicode_to_char

    // Utility functions


    last_errno      :: proc() -> Error ---
    strerror        :: proc(err: Error) -> cstring ---
    has_truecolor   :: proc() -> b32 ---
    has_egc         :: proc() -> b32 ---
    attr_width      :: proc() -> i32 ---
    version         :: proc() -> cstring ---
}


/* Utilities

*/

// acolor :: proc(col: Color) -> Attr {
//     return {
//         color = col,
//     }
// }


