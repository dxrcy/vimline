const std = @import("std");
const lib = @import("lib.zig");

pub const c = @cImport({
    @cInclude("curses.h");
});

pub const Key = c_uint;

pub const ScreenSize = struct {
    rows: u16,
    cols: u16,
};

fn asError(result: c_int) !c_int {
    if (result == c.ERR) {
        return error.CursesError;
    }
    return result;
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

    pub fn attr_set(self: Window, attrs: c.attr_t, pair: anytype) !void {
        _ = try asError(c.wattr_set(self.window, attrs, @intFromEnum(pair), null));
    }
};

pub fn initscr() !Window {
    return Window{
        .window = c.initscr() orelse return error.CursesError,
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
    SteadyUnderline = 4,
};

pub fn setCursor(cursor: CursorStyle) void {
    lib.printStdout("\x1b[{} q", .{@intFromEnum(cursor)});
}

pub const acs = struct {
    pub const LRCORNER = 0x0040006a;
    pub const URCORNER = 0x0040006b;
    pub const ULCORNER = 0x0040006c;
    pub const LLCORNER = 0x0040006d;
    pub const HLINE = 0x00400071;
    pub const VLINE = 0x00400078;
};

pub const attr = struct {
    pub const NORMAL = c.A_NORMAL;
    pub const DIM = c.A_DIM;
};

pub const color = struct {
    pub const BLUE = c.COLOR_BLUE;
    pub const WHITE = c.COLOR_WHITE;
};

pub fn start_color() !void {
    _ = try asError(c.start_color());
}

pub fn use_default_colors() !void {
    _ = try asError(c.use_default_colors());
}

pub fn init_pair(pair: anytype, fg: c_short, bg: c_short) !void {
    _ = try asError(c.init_pair(@intFromEnum(pair), fg, bg));
}
