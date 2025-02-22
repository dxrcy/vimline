const std = @import("std");
const print = std.debug.print;

const curses = @import("./curses.zig");
const acs = curses.acs;
const ScreenSize = curses.ScreenSize;
const Window = curses.Window;
const Key = curses.Key;

const MAX_INPUT = 200;

const box_padding = struct {
    const LEFT = 5;
    const RIGHT_FULL = 3;
    const RIGHT_EMPTY = 1;
};
const box_size = struct {
    const MAX_WIDTH = 70;
    const MARGIN = 2;
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

    const ui = try Ui.init();
    defer ui.deinit();

    { // Temporary
        const buffer = "abcdef ghijkl mnopqr stuvwx yz12345 67890 ABCDEF GHIJKL MNOPQR STUVWX YZ12345 67890";
        @memcpy(state.snap.buffer[0..buffer.len], buffer);
        state.snap.length = buffer.len;
        state.snap.cursor = buffer.len - 1;
        const size = try ui.window.getScreenSize();
        box.update(size);
        state.snap.updateOffsetInitial();
    }

    while (true) {
        try ui.frame(&state);
    }
}

const State = struct {
    mode: VimMode,
    snap: Snap,

    fn exit(self: *const State, save_result: bool) !void {
        try curses.endwin();
        if (save_result) {
            self.saveResult();
        }
        std.process.exit(0);
    }

    fn saveResult(self: *const State) void {
        const text = self.snap.buffer[0..self.snap.length];
        const stdout = std.io.getStdOut().writer();
        stdout.print("{s}\n", .{text}) catch {};
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
                        self.snap.delete();
                    },

                    'r' => {
                        self.mode = .Replace;
                    },

                    'i' => {
                        self.mode = .Insert;
                    },
                    'a' => {
                        self.mode = .Insert;
                        self.snap.moveRight2();
                    },

                    'I' => {
                        self.mode = .Insert;
                        self.snap.moveToStart2();
                    },
                    'A' => {
                        self.mode = .Insert;
                        self.snap.moveToEnd2();
                    },

                    '^', '_' => {
                        self.snap.moveToStart2();
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
                        self.snap.deleteRight();
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
                        self.snap.cursor = subsat(self.snap.cursor, 1);
                    },

                    keys.RETURN => {
                        try self.exit(true);
                    },

                    keys.BACKSPACE => {
                        self.snap.backspace();
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

    fn firstNonwhitespaceIndex(self: *const Snap) u32 {
        var i: u32 = 0;
        while (std.ascii.isWhitespace(self.buffer[i])) {
            i += 1;
        }
        return i;
    }

    fn delete(self: *Snap) void {
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

    fn backspace(self: *Snap) void {
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

    fn deleteRight(self: *Snap) void {
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

    fn moveRight2(self: *Snap) void {
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

    fn moveToStart2(self: *Snap) void {
        self.cursor = self.firstNonwhitespaceIndex();
        self.updateOffsetLeft();
    }

    fn moveToEnd(self: *Snap) void {
        self.cursor = subsat(self.length, 1);
        self.updateOffsetRight();
    }

    fn moveToEnd2(self: *Snap) void {
        self.cursor = self.length;
        self.updateOffsetRight();
    }
};

const Ui = struct {
    window: Window,

    fn init() !Ui {
        const window = try curses.initscr();

        try curses.noecho();
        try window.keypad(true);
        try curses.set_escdelay(0);

        return Ui{
            .window = window,
        };
    }

    fn deinit(self: Ui) void {
        _ = self;
        curses.endwin() catch {};
    }

    fn frame(self: Ui, state: *State) !void {
        const window = self.window;

        const size = try window.getScreenSize();
        box.update(size);

        try window.clear();

        try window.move(size.rows - 1, 1);
        const mode = switch (state.mode) {
            VimMode.Normal => "NORMAL ",
            VimMode.Insert => "INSERT ",
            VimMode.Replace => "REPLACE",
            VimMode.Visual => "VISUAL ",
        };
        try window.addstr(mode);

        try self.drawBox(
            state.snap.offset > 0,
            state.snap.offset + box.width < state.snap.length,
        );

        try window.move(box.y + 1, box.x + 1);
        for (0..box.width) |i| {
            const index = i + state.snap.offset;
            if (index >= state.snap.length) {
                break;
            }
            try window.addch(state.snap.buffer[index]);
        }

        if (state.mode == .Insert) {
            curses.setCursor(.SteadyBar);
        } else if (state.mode == .Replace) {
            curses.setCursor(.SteadyUnderline);
        } else {
            curses.setCursor(.SteadyBlock);
        }

        const cursor_x: u16 = @intCast(
            box.x + min(
                @as(u32, box.width),
                subsat(state.snap.cursor, state.snap.offset),
            ) + 1,
        );
        try window.move(box.y + 1, cursor_x);

        const key = try window.getch();
        try state.handleKey(key);
    }

    fn drawBox(self: Ui, left_open: bool, right_open: bool) !void {
        const window = self.window;

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
