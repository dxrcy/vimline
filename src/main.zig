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
    input: [MAX_INPUT]u8,
    length: usize,
    cursor: usize,
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    _ = .{
        .mode = .Normal,
        .snap = .{
            .input = undefined,
            .length = 0,
            .cursor = 0,
        },
    };

    const stdscr = try curses.initscr(allocator);

    try curses.noecho();

    var key: c_uint = 0;

    while (true) {
        try curses.clear();

        try stdscr.waddch(key);

        key = try stdscr.getch();

        switch (key) {
            'q' => {
                break;
            },

            else => {},
        }
    }

    _ = try curses.endwin();
}
