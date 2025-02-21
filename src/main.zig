const std = @import("std");
const print = std.debug.print;

const curses = @import("./curses.zig");
const acs = curses.acs;
const ScreenSize = curses.ScreenSize;
const Window = curses.Window;

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

    // temporary
    @memcpy(state.snap.buffer[0..6], "abcdef");
    state.snap.length = 6;
    state.snap.cursor = 6;

    const ui = try Ui.init();
    defer ui.deinit();

    while (true) {
        try ui.frame(&state);
    }
}

const State = struct {
    mode: VimMode,
    snap: Snap,

    fn writeFinalSnap(self: *const State) void {
        const text = self.snap.buffer[0..self.snap.length];
        const stdout = std.io.getStdOut().writer();
        stdout.print("{s}\n", .{text}) catch {};
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

    fn updateOffsetRight(self: *Snap, width: u16) void {
        const padding_right: u32 = if (self.cursor + 1 >= self.length)
            box_padding.RIGHT_EMPTY
        else
            box_padding.RIGHT_FULL;

        if (self.cursor + padding_right > self.offset + width) {
            self.offset = subsat(self.cursor + padding_right, width);
        }
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

        try window.clear();

        const size = try window.getScreenSize();
        const box = Box.fromScreenSize(size);

        try window.move(size.rows - 1, 1);
        const mode = switch (state.mode) {
            VimMode.Normal => "NORMAL ",
            VimMode.Insert => "INSERT ",
            VimMode.Replace => "REPLACE",
            VimMode.Visual => "VISUAL ",
        };
        try window.addstr(mode);

        try self.drawBox(box);

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
            subsat(box.x + state.snap.cursor, state.snap.offset) + 1,
        );
        try window.move(box.y + 1, cursor_x);

        const key = try window.getch();
        switch (state.mode) {
            .Normal => {
                switch (key) {
                    'q' => {
                        try curses.endwin();
                        std.process.exit(0);
                    },

                    keys.RETURN => {
                        try curses.endwin();
                        state.writeFinalSnap();
                        std.process.exit(0);
                    },

                    'h', keys.ARROW_LEFT => {
                        if (state.snap.cursor > 0) {
                            state.snap.cursor -= 1;
                            state.snap.updateOffsetLeft();
                        }
                    },
                    'l', keys.ARROW_RIGHT => {
                        if (state.snap.cursor < state.snap.length) {
                            state.snap.cursor += 1;
                            state.snap.updateOffsetRight(box.width);
                        }
                    },

                    'i' => {
                        state.mode = .Insert;
                    },

                    'r' => {
                        state.mode = .Replace;
                    },

                    // TODO: v
                    // TODO: V
                    // TODO: a
                    // TODO: I
                    // TODO: A
                    // TODO: w
                    // TODO: e
                    // TODO: b
                    // TODO: W
                    // TODO: E
                    // TODO: B
                    // TODO: ^, _
                    // TODO: 0
                    // TODO: $
                    // TODO: D
                    // TODO: x
                    // TODO: 0
                    // TODO: u
                    // TODO: <C-r>

                    else => {},
                }
            },

            .Insert => {
                switch (key) {
                    keys.ESCAPE => {
                        state.mode = .Normal;
                    },

                    keys.RETURN => {
                        try curses.endwin();
                        state.writeFinalSnap();
                        std.process.exit(0);
                    },

                    keys.BACKSPACE => {
                        if (state.snap.cursor > 0 and state.snap.length > 0) {
                            for (state.snap.cursor..state.snap.length) |i| {
                                state.snap.buffer[i - 1] = state.snap.buffer[i];
                            }
                            state.snap.cursor -= 1;
                            state.snap.length -= 1;
                            state.snap.updateOffsetLeft();
                        }
                    },

                    keys.ARROW_LEFT => {
                        if (state.snap.cursor > 0) {
                            state.snap.cursor -= 1;
                            state.snap.updateOffsetLeft();
                        }
                    },
                    keys.ARROW_RIGHT => {
                        if (state.snap.cursor < state.snap.length) {
                            state.snap.cursor += 1;
                            state.snap.updateOffsetRight(box.width);
                        }
                    },

                    keys.PRINTABLE_START...keys.PRINTABLE_END => {
                        if (state.snap.length < MAX_INPUT) {
                            var i = state.snap.length;
                            while (i > state.snap.cursor) : (i -= 1) {
                                state.snap.buffer[i] = state.snap.buffer[i - 1];
                            }
                            state.snap.buffer[state.snap.cursor] = @intCast(key);
                            state.snap.cursor += 1;
                            state.snap.length += 1;
                            state.snap.updateOffsetRight(box.width);
                        }
                    },

                    else => {},
                }
            },

            .Replace => {
                switch (key) {
                    keys.PRINTABLE_START...keys.PRINTABLE_END => {
                        state.snap.buffer[state.snap.cursor] = @intCast(key);
                        state.mode = .Normal;
                    },

                    else => {
                        state.mode = .Normal;
                    },
                }
            },

            .Visual => {
                // TODO
            },
        }
    }

    fn drawBox(self: Ui, box: Box) !void {
        const window = self.window;

        try window.move(box.y, box.x);
        try window.addch(acs.ULCORNER);
        for (0..box.width) |_| {
            try window.addch(acs.HLINE);
        }
        try window.addch(acs.URCORNER);

        try window.move(box.y + 1, box.x);
        try window.addch(acs.VLINE);
        try window.move(box.y + 1, box.x + box.width + 1);
        try window.addch(acs.VLINE);

        try window.move(box.y + 2, box.x);
        try window.addch(acs.LLCORNER);
        for (0..box.width) |_| {
            try window.addch(acs.HLINE);
        }
        try window.addch(acs.LRCORNER);
    }
};

const Box = struct {
    x: u16,
    y: u16,
    width: u16,

    fn fromScreenSize(size: ScreenSize) Box {
        const width = min(size.cols - box_size.MARGIN * 2 - 2, box_size.MAX_WIDTH);
        const x = (size.cols - width) / 2 - 1;
        const y = size.rows / 2 - 1;
        return Box{ .width = width, .x = x, .y = y };
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
