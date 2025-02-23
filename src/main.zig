const std = @import("std");
const print = std.debug.print;

const lib = @import("lib.zig");

const curses = @import("curses.zig");
const acs = curses.acs;
const ScreenSize = curses.ScreenSize;
const Window = curses.Window;
const Key = curses.Key;

const MAX_INPUT = 200;

const box_size = struct {
    const MAX_WIDTH = 70;
    const MARGIN = 2;
};
const box_padding = struct {
    const LEFT = 5;
    const RIGHT_FULL = 3;
    const RIGHT_EMPTY = 1;
};

const keys = struct {
    const ESCAPE = 0x1b;
    const BACKSPACE = 0x107;

    const ARROW_LEFT = 0x104;
    const ARROW_RIGHT = 0x105;

    const RETURN = 0x0a;

    const PRINTABLE_START = 0x20;
    const PRINTABLE_END = 0x7e;
};

const VimMode = enum {
    Normal,
    Insert,
    Replace,
    Visual,
};

const box = struct {
    var x: u16 = 0;
    var y: u16 = 0;
    var width: u16 = 10;

    fn update(size: ScreenSize) void {
        width = min(size.cols - box_size.MARGIN * 2 - 2, box_size.MAX_WIDTH);
        x = (size.cols - width) / 2 - 1;
        y = size.rows / 2 - 1;
    }
};

pub fn main() !void {
    var state = State{
        .mode = .Normal,
        .snap = Snap{
            .buffer = undefined,
            .length = 0,
            .cursor = 0,
            .offset = 0,
        },
    };

    const window = try ui.init();

    { // Temporary
        const buffer = "abcdef ghijkl mnopqr stuvwx yz12345 67890 ABCDEF GHIJKL MNOPQR STUVWX YZ12345 67890";
        @memcpy(state.snap.buffer[0..buffer.len], buffer);
        state.snap.length = buffer.len;
        state.snap.cursor = buffer.len - 1;
        const size = try window.getScreenSize();
        box.update(size);
        state.snap.updateOffsetInitial();
    }

    while (true) {
        try ui.render(window, &state);

        state.handleKey(try window.getch()) catch |err| switch (err) {
            error.Exit => break,
            else => return err,
        };
    }
}

const State = struct {
    mode: VimMode,
    snap: Snap,

    fn exit(self: *const State, save_result: bool) !void {
        try ui.deinit();
        if (save_result) {
            self.saveResult();
        }
        return error.Exit;
    }

    fn saveResult(self: *const State) void {
        const text = self.snap.buffer[0..self.snap.length];
        lib.printStdout("{s}\n", .{text});
    }

    fn handleKey(self: *State, key: Key) !void {
        switch (self.mode) {
            .Normal => {
                switch (key) {
                    'q' => {
                        try self.exit(false);
                    },

                    keys.RETURN => {
                        try self.exit(true);
                    },

                    'x' => {
                        self.snap.removeNextChar();
                    },

                    'r' => {
                        self.mode = .Replace;
                    },

                    'i' => {
                        self.mode = .Insert;
                    },
                    'a' => {
                        self.mode = .Insert;
                        self.snap.moveRightInsert();
                    },

                    'I' => {
                        self.mode = .Insert;
                        self.snap.moveToFirstNonspace();
                    },
                    'A' => {
                        self.mode = .Insert;
                        self.snap.moveToEndInsert();
                    },

                    '^', '_' => {
                        self.snap.moveToFirstNonspace();
                    },
                    '0' => {
                        self.snap.moveToStart();
                    },
                    '$' => {
                        self.snap.moveToEnd();
                    },

                    'h', keys.ARROW_LEFT => {
                        self.snap.moveLeft();
                    },
                    'l', keys.ARROW_RIGHT => {
                        self.snap.moveRight();
                    },

                    'D' => {
                        self.snap.deleteToEnd();
                    },

                    // TODO: v
                    // TODO: V
                    // TODO: w
                    // TODO: e
                    // TODO: b
                    // TODO: W
                    // TODO: E
                    // TODO: B
                    // TODO: u
                    // TODO: <C-r>

                    else => {},
                }
            },

            .Insert => {
                switch (key) {
                    keys.ESCAPE => {
                        self.mode = .Normal;
                        self.snap.moveLeft();
                    },

                    keys.RETURN => {
                        try self.exit(true);
                    },

                    keys.BACKSPACE => {
                        self.snap.removePreviousChar();
                    },

                    keys.ARROW_LEFT => {
                        self.snap.moveLeft();
                    },
                    keys.ARROW_RIGHT => {
                        self.snap.moveRight();
                    },

                    keys.PRINTABLE_START...keys.PRINTABLE_END => {
                        self.snap.insertChar(@intCast(key));
                    },

                    else => {},
                }
            },

            .Replace => {
                switch (key) {
                    keys.PRINTABLE_START...keys.PRINTABLE_END => {
                        self.mode = .Normal;
                        self.snap.replaceChar(@intCast(key));
                    },

                    else => {
                        self.mode = .Normal;
                    },
                }
            },

            .Visual => {
                // TODO
            },
        }
    }
};

const Snap = struct {
    buffer: [MAX_INPUT]u8,
    length: u32,
    cursor: u32,
    offset: u32,

    fn updateOffsetLeft(self: *Snap) void {
        if (self.cursor < self.offset + box_padding.LEFT) {
            self.offset = subsat(self.cursor, box_padding.LEFT);
        }
    }

    fn updateOffsetRight(self: *Snap) void {
        const width = box.width;

        const padding_right: u32 = if (self.cursor + 1 >= self.length)
            box_padding.RIGHT_EMPTY
        else
            box_padding.RIGHT_FULL;

        if (self.cursor + padding_right > self.offset + width) {
            self.offset = subsat(self.cursor + padding_right, width);
        }
    }

    fn updateOffsetInitial(self: *Snap) void {
        self.offset = subsat(self.cursor + box_padding.RIGHT_EMPTY + 1, box.width);
    }

    fn firstNonspaceIndex(self: *const Snap) u32 {
        var i: u32 = 0;
        while (std.ascii.isWhitespace(self.buffer[i])) {
            i += 1;
        }
        return i;
    }

    fn removeNextChar(self: *Snap) void {
        if (self.length == 0 or self.cursor >= self.length) {
            return;
        }

        for (self.cursor + 1..self.length) |i| {
            self.buffer[i - 1] = self.buffer[i];
        }
        self.length -= 1;
        if (self.cursor >= self.length and self.cursor > 0) {
            self.cursor -= 1;
        }

        self.updateOffsetLeft();
    }

    fn removePreviousChar(self: *Snap) void {
        if (self.cursor == 0 or self.length == 0) {
            return;
        }

        for (self.cursor..self.length) |i| {
            self.buffer[i - 1] = self.buffer[i];
        }
        self.length -= 1;
        self.cursor -= 1;

        self.updateOffsetLeft();
    }

    fn insertChar(self: *Snap, char: u8) void {
        if (self.length >= MAX_INPUT) {
            return;
        }

        var i = self.length;
        while (i > self.cursor) : (i -= 1) {
            self.buffer[i] = self.buffer[i - 1];
        }
        self.buffer[self.cursor] = char;
        self.cursor += 1;
        self.length += 1;

        self.updateOffsetRight();
    }

    fn replaceChar(self: *Snap, char: u8) void {
        self.buffer[self.cursor] = char;
    }

    fn deleteToEnd(self: *Snap) void {
        if (self.length < self.cursor) {
            return;
        }
        self.length = self.cursor;
        if (self.cursor > 0) {
            self.cursor -= 1;
        }
    }

    fn moveLeft(self: *Snap) void {
        if (self.cursor == 0) {
            return;
        }
        self.cursor -= 1;
        self.updateOffsetLeft();
    }

    fn moveRight(self: *Snap) void {
        if (self.cursor + 1 >= self.length) {
            return;
        }
        self.cursor += 1;
        self.updateOffsetRight();
    }

    fn moveRightInsert(self: *Snap) void {
        if (self.cursor >= self.length) {
            return;
        }
        self.cursor += 1;
        self.updateOffsetRight();
    }

    fn moveToStart(self: *Snap) void {
        self.cursor = 0;
        self.updateOffsetLeft();
    }

    fn moveToFirstNonspace(self: *Snap) void {
        self.cursor = self.firstNonspaceIndex();
        self.updateOffsetLeft();
    }

    fn moveToEnd(self: *Snap) void {
        self.cursor = subsat(self.length, 1);
        self.updateOffsetRight();
    }

    fn moveToEndInsert(self: *Snap) void {
        self.cursor = self.length;
        self.updateOffsetRight();
    }
};

const ui = struct {
    fn init() !Window {
        const window = try curses.initscr();

        try curses.noecho();
        try window.keypad(true);
        try curses.set_escdelay(0);

        return window;
    }

    fn deinit() !void {
        try curses.endwin();
    }

    fn render(window: Window, state: *State) !void {
        const size = try window.getScreenSize();
        box.update(size);

        try window.clear();

        try ui.drawModeName(window, state, size);

        try ui.drawBox(
            window,
            state.snap.offset > 0,
            state.snap.offset + box.width < state.snap.length,
        );
        try ui.drawText(window, state);

        try ui.setCursor(state.mode);
        try ui.setCursorPosition(window, &state.snap);
    }

    fn drawModeName(window: Window, state: *const State, size: ScreenSize) !void {
        try window.move(size.rows - 1, 1);

        const mode = switch (state.mode) {
            VimMode.Normal => "NORMAL ",
            VimMode.Insert => "INSERT ",
            VimMode.Replace => "REPLACE",
            VimMode.Visual => "VISUAL ",
        };
        try window.addstr(mode);
    }

    fn drawBox(window: Window, left_open: bool, right_open: bool) !void {
        try window.move(box.y, box.x);
        try window.addch(acs.ULCORNER);
        for (0..box.width) |_| {
            try window.addch(acs.HLINE);
        }
        try window.addch(acs.URCORNER);

        try window.move(box.y + 1, box.x);
        try window.addch(if (left_open) ':' else acs.VLINE);
        try window.move(box.y + 1, box.x + box.width + 1);
        try window.addch(if (right_open) ':' else acs.VLINE);

        try window.move(box.y + 2, box.x);
        try window.addch(acs.LLCORNER);
        for (0..box.width) |_| {
            try window.addch(acs.HLINE);
        }
        try window.addch(acs.LRCORNER);
    }

    fn drawText(window: Window, state: *const State) !void {
        try window.move(box.y + 1, box.x + 1);

        for (0..box.width) |i| {
            const index = i + state.snap.offset;
            if (index >= state.snap.length) {
                break;
            }
            try window.addch(state.snap.buffer[index]);
        }
    }

    fn setCursor(mode: VimMode) !void {
        const style: curses.CursorStyle = switch (mode) {
            .Insert => .SteadyBar,
            .Replace => .SteadyUnderline,
            else => .SteadyBlock,
        };
        curses.setCursor(style);
    }

    fn setCursorPosition(window: Window, snap: *const Snap) !void {
        const cursor_x: u16 = @intCast(
            box.x + min(
                @as(u32, box.width),
                subsat(snap.cursor, snap.offset),
            ) + 1,
        );
        try window.move(box.y + 1, cursor_x);
    }
};

fn subsat(lhs: anytype, rhs: anytype) @TypeOf(lhs) {
    if (rhs >= lhs) {
        return 0;
    }
    return lhs - rhs;
}

fn min(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    if (rhs < lhs) {
        return rhs;
    }
    return lhs;
}
