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

const keys = struct {
    const ESCAPE = 0x1b;
    const BACKSPACE = 0x107;

    const ARROW_LEFT = 0x104;
    const ARROW_RIGHT = 0x105;

    const PRINTABLE_START = 0x20;
    const PRINTABLE_END = 0x7e;
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

    defer {
        curses.endwin() catch {};
    }

    var key: c_uint = 0;
    while (true) {
        try frame(&stdscr, &state, &key);
    }
}

fn frame(stdscr: *const curses.Window, state: *State, key: *curses.Key) !void {
    try stdscr.clear();

    const size = try stdscr.getScreenSize();

    try stdscr.move(size.rows - 1, 0);
    const mode = switch (state.mode) {
        VimMode.Normal => "NORMAL",
        VimMode.Insert => "Insert",
    };
    try stdscr.addstr(mode);

    try stdscr.move(input_box.y + 1, @intCast(@as(usize, input_box.x) + state.snap.cursor));
    try stdscr.addch('^');

    try stdscr.move(input_box.y, input_box.x);
    for (0..state.snap.length) |i| {
        try stdscr.addch(state.snap.buffer[i]);
    }

    key.* = try stdscr.getch();

    switch (state.mode) {
        VimMode.Normal => {
            switch (key.*) {
                'q' => {
                    try curses.endwin();
                    std.process.exit(0);
                },

                'i' => {
                    state.mode = .Insert;
                },

                else => {},
            }
        },

        VimMode.Insert => {
            switch (key.*) {
                keys.ESCAPE => {
                    state.mode = .Normal;
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
        },
    }
}
