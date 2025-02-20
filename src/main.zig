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
    length: usize,
    cursor: usize,
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var state: State = .{
        .mode = .Normal,
        .snap = .{
            .buffer = undefined,
            .length = 0,
            .cursor = 0,
        },
    };

    @memcpy(state.snap.buffer[0..3], "abc");
    state.snap.length = 3;

    const stdscr = try curses.initscr(allocator);

    try curses.noecho();
    try stdscr.keypad(true);

    var key: c_uint = 0;

    while (true) {
        try curses.clear();

        for (0..state.snap.length) |i| {
            try stdscr.waddch(state.snap.buffer[i]);
        }

        key = try stdscr.getch();

        const keys = struct {
            const ESCAPE = 0x1b;
            const BACKSPACE = 0x107;

            const PRINTABLE_START = 0x20;
            const PRINTABLE_END = 0x7e;
        };

        switch (key) {
            keys.ESCAPE => {
                break;
            },

            keys.BACKSPACE => {
                if (state.snap.length > 0) {
                    state.snap.length -= 1;
                }
            },

            keys.PRINTABLE_START...keys.PRINTABLE_END => {
                if (state.snap.length < MAX_INPUT) {
                    state.snap.buffer[state.snap.length] = @intCast(key);
                    state.snap.length += 1;
                }
            },

            else => {},
        }
    }

    try curses.endwin();
}
