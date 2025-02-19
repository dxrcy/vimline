const std = @import("std");
const c = @cImport({
    @cInclude("curses.h");
});

const Error = error.CursesError;

const Key = c_int;

fn asError(res: c_int) !c_int {
    if (res == c.ERR) {
        return Error;
    }
    return res;
}

pub const Window = struct {
    window: *c.WINDOW,
    allocator: std.mem.Allocator,

    pub fn getch(self: Window) !Key {
        return asError(c.wgetch(self.window));
    }
};

pub fn initscr(allocator: std.mem.Allocator) !Window {
    return Window{
        .window = c.initscr() orelse return Error,
        .allocator = allocator,
    };
}

pub fn endwin() !void {
    _ = try asError(c.endwin());
}
