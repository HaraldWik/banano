const std = @import("std");

file: std.fs.File,
original: std.posix.termios,
out: std.posix.termios,

pub const Size = struct { row: u16 = 0, col: u16 = 0 };
pub const Position = Size;

pub const EscCode = enum(u8) {
    esc = 27, // Not sure if this is an escape code?

    up = 65,
    down = 66,
    left = 67,
    right = 68,

    _,
};

pub const Event = union(enum) {
    char: u8,
    enter: void,
    backspace: void,
    esc_code: EscCode,
};

pub fn init(file: std.fs.File) !@This() {
    const original: std.posix.termios = try std.posix.tcgetattr(file.handle);
    var out: std.posix.termios = original;

    var action: std.posix.Sigaction = .{
        .handler = .{ .handler = std.posix.SIG.IGN },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    const null_actions: []const u8 = &.{ std.posix.SIG.HUP, std.posix.SIG.INT, std.posix.SIG.QUIT, std.posix.SIG.TERM, std.posix.SIG.PIPE, std.posix.SIG.ALRM };
    for (null_actions) |null_action| std.posix.sigaction(null_action, &action, null);

    out.iflag = .{
        .BRKINT = false,
        .ICRNL = false,
        .INPCK = false,
        .ISTRIP = false,
        .IXON = false,
    };
    out.oflag = .{};
    out.cflag = .{
        .CSIZE = .CS8, // 8-bit chars
    };
    out.lflag = .{
        .ECHO = false,
        .ICANON = false,
        .IEXTEN = false,
        .ISIG = false,
    };

    out.cc[@intFromEnum(std.posix.V.TIME)] = 0;
    out.cc[@intFromEnum(std.posix.V.MIN)] = 1;
    try std.posix.tcsetattr(file.handle, .FLUSH, out);
    // hide mouse "\x1b[?25l"
    //                   new buffer     clear         move cursor top left
    try file.writeAll("\x1b[?1049h" ++ "\x1b[2J" ++ "\x1b[H");

    return .{ .file = file, .original = original, .out = out };
}

pub fn deinit(self: @This()) void {
    // show mouse "\x1b[?25h"
    //                  old buffer
    self.file.writeAll("\x1b[?1049l") catch unreachable;
    std.posix.tcsetattr(self.file.handle, .FLUSH, self.original) catch unreachable;
}

pub fn getSize(self: @This()) !Size {
    if (!self.file.supportsAnsiEscapeCodes()) return error.AnsiUnsupported;

    var size: std.posix.winsize = undefined;
    return switch (std.posix.errno(
        std.posix.system.ioctl(
            self.file.handle,
            std.posix.T.IOCGWINSZ,
            @intFromPtr(&size),
        ),
    )) {
        .SUCCESS => .{
            .row = size.row,
            .col = size.col,
        },
        else => error.IoctlError,
    };
}

pub fn next(self: @This()) !?Event {
    var buffer: [3]u8 = undefined;
    var file_reader = self.file.reader(&buffer);
    const reader: *std.Io.Reader = &file_reader.interface;

    return switch (reader.takeByte() catch return null) {
        3 => null, // Exit
        27 => .{ .esc_code = @enumFromInt((try reader.take(2))[1]) }, // Escape codes
        13 => .enter,
        127 => .backspace,
        else => |char| .{ .char = char },
    };
}

pub fn setCursor(self: @This(), pos: Position) !void {
    var buffer: [64]u8 = undefined;
    try self.file.writeAll(try std.fmt.bufPrint(&buffer, "\x1b[{d};{d}H", .{ pos.row + 1, pos.col + 1 }));
}

pub fn getCursor(self: @This()) !Position {
    const stdin: std.fs.File = .stdin();

    try self.file.writeAll("\x1b[6n");

    var buffer: [32]u8 = undefined;
    const n = try stdin.read(&buffer);
    const response = buffer[0..n];

    if (response.len < 4 or response[0] != 0x1b or response[1] != '[') return error.InvalidResponse;

    var it = std.mem.tokenizeScalar(u8, response[2..], ';');
    const row_str = it.next() orelse return error.ParseFail;
    const col_str = it.next() orelse return error.ParseFail;

    const row = try std.fmt.parseInt(u16, row_str, 10);
    const col = try std.fmt.parseInt(u16, col_str[0 .. col_str.len - 1], 10);

    return .{ .row = row, .col = col };
}

pub fn writeAt(self: @This(), pos: Position, bytes: []const u8) !void {
    const size = try self.getSize();
    if (pos.row > size.row or pos.col > size.col) return;

    try self.setCursor(pos);
    try self.file.writeAll(bytes);
}

pub fn printAt(self: @This(), pos: Position, buffer: []u8, comptime fmt: []const u8, args: anytype) !void {
    try self.writeAt(pos, try std.fmt.bufPrint(buffer, fmt, args));
}

pub fn clear(self: @This()) !void {
    try self.file.writeAll("\x1b[2J\x1b[H");
}
