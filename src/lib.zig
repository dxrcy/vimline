const std = @import("std");

pub fn printStdout(comptime format: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(format, args) catch {};
}
