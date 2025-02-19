const std = @import("std");
const print = std.debug.print;

const curses = @import("./curses.zig");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    print("Hello\n", .{});

    const stdscr = try curses.initscr(allocator);

    print("Hello\n", .{});

    _ = try stdscr.getch();

    _ = try curses.endwin();
}
