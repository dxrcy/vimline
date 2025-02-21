const std = @import("std");
const print = std.debug.print;

const curses = @import("./curses.zig");

const MAX_INPUT = 200;

const State = struct {
    mode: VimMode,
    snap: Snap,
};

const VimMode = enum {
    Normal,
    Insert,
};

const Snap = struct {
    buffer: [MAX_INPUT]u8,
    length: u32,
    cursor: u32,
};

const InputBox = struct {
    x: u16,
    y: u16,
    width: u32,
};

var input_box = InputBox{
    .x = 2,
    .y = 5,
    .width = 20,
};

pub fn main() !void {
    var state = State{
        .mode = .Normal,
        .snap = Snap{
            .buffer = undefined,
            .length = 0,
            .cursor = 0,
        },
    };

    @memcpy(state.snap.buffer[0..6], "abcdef");
    state.snap.length = 6;
    state.snap.cursor = 6;

    const stdscr = try curses.initscr();

    try curses.noecho();
    try stdscr.keypad(true);
    try curses.set_escdelay(0);

    var key: c_uint = 0;
    while (true) {
        try frame(&stdscr, &state, &key);
    }

    try curses.endwin();
}

fn frame(stdscr: *const curses.Window, state: *State, key: *curses.Key) !void {
    try curses.clear();

    try curses.move(input_box.y + 1, @intCast(@as(usize, input_box.x) + state.snap.cursor));
    try stdscr.waddch('^');

    try curses.move(input_box.y, input_box.x);
    for (0..state.snap.length) |i| {
        try stdscr.waddch(state.snap.buffer[i]);
    }

    key.* = try stdscr.getch();

    const keys = struct {
        const ESCAPE = 0x1b;
        const BACKSPACE = 0x107;

        const ARROW_LEFT = 0x104;
        const ARROW_RIGHT = 0x105;

        const PRINTABLE_START = 0x20;
        const PRINTABLE_END = 0x7e;
    };

    switch (key.*) {
        keys.ESCAPE => {
            try curses.endwin();
            std.process.exit(0);
        },

        keys.BACKSPACE => {
            if (state.snap.cursor > 0 and state.snap.length > 0) {
                for (state.snap.cursor..state.snap.length) |i| {
                    state.snap.buffer[i - 1] = state.snap.buffer[i];
                }
                state.snap.cursor -= 1;
                state.snap.length -= 1;
            }
        },

        keys.ARROW_LEFT => {
            if (state.snap.cursor > 0) {
                state.snap.cursor -= 1;
            }
        },
        keys.ARROW_RIGHT => {
            if (state.snap.cursor < state.snap.length) {
                state.snap.cursor += 1;
            }
        },

        keys.PRINTABLE_START...keys.PRINTABLE_END => {
            if (state.snap.length < MAX_INPUT) {
                var i = state.snap.length;
                while (i > state.snap.cursor) : (i -= 1) {
                    state.snap.buffer[i] = state.snap.buffer[i - 1];
                }
                state.snap.buffer[state.snap.cursor] = @intCast(key.*);
                state.snap.cursor += 1;
                state.snap.length += 1;
            }
        },

        else => {},
    }
}
