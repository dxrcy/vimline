const std = @import("std");

pub const c = @cImport({
    @cInclude("curses.h");
});

const Error = error.CursesError;

const Key = c_uint;

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
        return @intCast(try asError(c.wgetch(self.window)));
    }

    pub fn waddch(self: Window, char: c.chtype) !void {
        _ = try asError(c.waddch(self.window, char));
    }

    pub fn keypad(self: Window, value: bool) !void {
        _ = try asError(c.keypad(self.window, value));
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

pub fn clear() !void {
    _ = try asError(c.clear());
}

pub fn noecho() !void {
    _ = try asError(c.noecho());
}
