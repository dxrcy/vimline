const std = @import("std");

pub const c = @cImport({
    @cInclude("curses.h");
});

const Error = error.CursesError;

pub const Key = c_uint;

const ScreenSize = struct {
    rows: u16,
    cols: u16,
};

fn asError(res: c_int) !c_int {
    if (res == c.ERR) {
        return Error;
    }
    return res;
}

pub const Window = struct {
    window: *c.WINDOW,

    pub fn clear(self: Window) !void {
        _ = try asError(c.wclear(self.window));
    }

    pub fn move(self: Window, y: u16, x: u16) !void {
        _ = try asError(c.wmove(self.window, y, x));
    }

    pub fn getch(self: Window) !Key {
        return @intCast(try asError(c.wgetch(self.window)));
    }

    pub fn addch(self: Window, char: c.chtype) !void {
        _ = try asError(c.waddch(self.window, char));
    }

    pub fn addstr(self: Window, string: []const u8) !void {
        for (0..string.len) |i| {
            try self.addch(string[i]);
        }
    }

    pub fn keypad(self: Window, value: bool) !void {
        _ = try asError(c.keypad(self.window, value));
    }

    pub fn getScreenSize(self: Window) !ScreenSize {
        const rows = try asError(c.getmaxy(self.window));
        const cols = try asError(c.getmaxx(self.window));
        return ScreenSize{
            .rows = @intCast(rows),
            .cols = @intCast(cols),
        };
    }
};

// TODO: use `w*` versions

pub fn initscr() !Window {
    return Window{
        .window = c.initscr() orelse return Error,
    };
}

pub fn endwin() !void {
    _ = try asError(c.endwin());
}

pub fn noecho() !void {
    _ = try asError(c.noecho());
}

pub fn set_escdelay(delay: c_int) !void {
    _ = try asError(c.set_escdelay(delay));
}

pub const CursorStyle = enum(u8) {
    SteadyBlock = 2,
    SteadyBar = 6,
};

pub fn setCursor(cursor: CursorStyle) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("\x1b[{} q", .{@intFromEnum(cursor)}) catch {};
}
