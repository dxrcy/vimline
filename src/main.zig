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
    Replace,
    Visual,
};

const Snap = struct {
    buffer: [MAX_INPUT]u8,
    length: u32,
    cursor: u32,
    offset: u32,
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

    @memcpy(state.snap.buffer[0..6], "abcdef");
    state.snap.length = 6;
    state.snap.cursor = 6;

    const ui = try Ui.init();
    defer ui.deinit();

    while (true) {
        try ui.frame(&state);
    }
}

const Ui = struct {
    window: curses.Window,

    const InputBox = struct {
        x: u16,
        y: u16,
        width: u16,
    };
    var input_box = InputBox{
        .x = 2,
        .y = 5,
        .width = 40,
    };

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

        try window.move(size.rows - 1, 0);
        const mode = switch (state.mode) {
            VimMode.Normal => "NORMAL ",
            VimMode.Insert => "INSERT ",
            VimMode.Replace => "REPLACE",
            VimMode.Visual => "VISUAL ",
        };
        try window.addstr(mode);

        try self.drawInputBox();

        try window.move(input_box.y + 1, input_box.x + 1);
        for (0..input_box.width) |i| {
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
            subsat(input_box.x + state.snap.cursor, state.snap.offset) + 1,
        );
        try window.move(input_box.y + 1, cursor_x);

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
                        saveInput(state);
                        std.process.exit(0);
                    },

                    'h', keys.ARROW_LEFT => {
                        if (state.snap.cursor > 0) {
                            state.snap.cursor -= 1;
                            updateOffsetLeft(&state.snap);
                        }
                    },
                    'l', keys.ARROW_RIGHT => {
                        if (state.snap.cursor < state.snap.length) {
                            state.snap.cursor += 1;
                            updateOffsetRight(&state.snap);
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
                        saveInput(state);
                        std.process.exit(0);
                    },

                    keys.BACKSPACE => {
                        if (state.snap.cursor > 0 and state.snap.length > 0) {
                            for (state.snap.cursor..state.snap.length) |i| {
                                state.snap.buffer[i - 1] = state.snap.buffer[i];
                            }
                            state.snap.cursor -= 1;
                            state.snap.length -= 1;
                            updateOffsetLeft(&state.snap);
                        }
                    },

                    keys.ARROW_LEFT => {
                        if (state.snap.cursor > 0) {
                            state.snap.cursor -= 1;
                            updateOffsetLeft(&state.snap);
                        }
                    },
                    keys.ARROW_RIGHT => {
                        if (state.snap.cursor < state.snap.length) {
                            state.snap.cursor += 1;
                            updateOffsetRight(&state.snap);
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
                            updateOffsetRight(&state.snap);
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

    fn drawInputBox(self: Ui) !void {
        const window = self.window;

        try window.move(input_box.y, input_box.x);
        try window.addch(curses.acs.ULCORNER);
        for (0..input_box.width) |_| {
            try window.addch(curses.acs.HLINE);
        }
        try window.addch(curses.acs.URCORNER);

        try window.move(input_box.y + 1, input_box.x);
        try window.addch(curses.acs.VLINE);
        try window.move(input_box.y + 1, input_box.x + input_box.width + 1);
        try window.addch(curses.acs.VLINE);

        try window.move(input_box.y + 2, input_box.x);
        try window.addch(curses.acs.LLCORNER);
        for (0..input_box.width) |_| {
            try window.addch(curses.acs.HLINE);
        }
        try window.addch(curses.acs.LRCORNER);
    }
};

fn saveInput(state: *const State) void {
    const input = state.snap.buffer[0..state.snap.length];
    const stdout = std.io.getStdOut().writer();
    stdout.print("{s}\n", .{input}) catch {};
}

const padding = struct {
    const LEFT = 5;
    const RIGHT_FULL = 3;
    const RIGHT_EMPTY = 1;
};

fn updateOffsetLeft(snap: *Snap) void {
    if (snap.cursor < snap.offset + padding.LEFT) {
        snap.offset = subsat(snap.cursor, padding.LEFT);
    }
}

fn updateOffsetRight(snap: *Snap) void {
    const width = Ui.input_box.width;

    const padding_right: u32 = if (snap.cursor + 1 >= snap.length)
        padding.RIGHT_EMPTY
    else
        padding.RIGHT_FULL;

    if (snap.cursor + padding_right > snap.offset + width) {
        snap.offset = subsat(snap.cursor + padding_right, width);
    }
}

fn subsat(lhs: anytype, rhs: anytype) @TypeOf(lhs) {
    if (rhs >= lhs) {
        return 0;
    }
    return lhs - rhs;
}
