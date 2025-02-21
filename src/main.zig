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
    buffer: [MAX_INPUT]u8,
    length: u32,
    cursor: u32,
};

const keys = struct {
    const ESCAPE = 0x1b;
    const BACKSPACE = 0x107;

    const ARROW_LEFT = 0x104;
    const ARROW_RIGHT = 0x105;

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
            VimMode.Normal => "NORMAL",
            VimMode.Insert => "Insert",
        };
        try window.addstr(mode);

        try self.drawInputBox();

        try window.move(
            input_box.y + 2,
            @intCast(@as(usize, input_box.x) + state.snap.cursor + 1),
        );
        try window.addch('^');

        try window.move(input_box.y + 1, input_box.x + 1);
        for (0..state.snap.length) |i| {
            try window.addch(state.snap.buffer[i]);
        }

        const key = try window.getch();
        switch (state.mode) {
            VimMode.Normal => {
                switch (key) {
                    'q' => {
                        try curses.endwin();
                        std.process.exit(0);
                    },

                    'i' => {
                        state.mode = .Insert;
                    },

                    else => {},
                }
            },

            VimMode.Insert => {
                switch (key) {
                    keys.ESCAPE => {
                        state.mode = .Normal;
                    },

                    keys.BACKSPACE => {
                        if (state.snap.cursor > 0 and state.snap.length > 0) {
                            for (state.snap.cursor..state.snap.length) |i| {
                                state.snap.buffer[i - 1] = state.snap.buffer[i];
                            }
                            state.snap.cursor -= 1;
                            state.snap.length -= 1;
                        }
                    },

                    keys.ARROW_LEFT => {
                        if (state.snap.cursor > 0) {
                            state.snap.cursor -= 1;
                        }
                    },
                    keys.ARROW_RIGHT => {
                        if (state.snap.cursor < state.snap.length) {
                            state.snap.cursor += 1;
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
                        }
                    },

                    else => {},
                }
            },
        }
    }

    fn drawInputBox(self: Ui) !void {
        const window = self.window;

        try window.move(input_box.y, input_box.x);
        try window.addch('+');
        for (0..input_box.width) |_| {
            try window.addch('-');
        }
        try window.addch('+');
        try window.move(input_box.y + 1, input_box.x);
        try window.addch('|');
        try window.move(input_box.y + 1, input_box.x + input_box.width + 1);
        try window.addch('|');
        try window.move(input_box.y + 2, input_box.x);
        try window.addch('+');
        for (0..input_box.width) |_| {
            try window.addch('-');
        }
        try window.addch('+');
    }
};
