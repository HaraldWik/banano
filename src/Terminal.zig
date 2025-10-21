const std = @import("std");

file: std.fs.File,
original: std.posix.termios,
out: std.posix.termios,

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
    for (null_actions) |act| std.posix.sigaction(act, &action, null);

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

    //                   new buffer       hide mouse   clear         move cursor top left
    try file.writeAll("\x1b[?1049h" ++ "\x1b[?25l" ++ "\x1b[2J" ++ "\x1b[H");

    return .{ .file = file, .original = original, .out = out };
}

pub fn deinit(self: @This()) void {
    //                  old buffer       show mouse
    self.file.writeAll("\x1b[?1049l" ++ "\x1b[?25h") catch unreachable;
    std.posix.tcsetattr(self.file.handle, .FLUSH, self.original) catch unreachable;
}

pub fn getSize(self: @This()) !std.posix.winsize {
    if (!self.file.supportsAnsiEscapeCodes()) return error.AnsiUnsupported;

    var size: std.posix.winsize = undefined;
    return switch (std.posix.errno(
        std.posix.system.ioctl(
            self.file.handle,
            std.posix.T.IOCGWINSZ,
            @intFromPtr(&size),
        ),
    )) {
        .SUCCESS => size,
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

pub fn writeAt(self: @This(), pos: std.posix.winsize, bytes: []const u8) !void {
    const size = try self.getSize();
    if (pos.row > size.@"0" or pos.col > size.@"1") return;

    var buffer: [128]u8 = undefined;
    var file_writer = self.file.writer(&buffer);
    const writer: *std.Io.Writer = &file_writer.interface;
    try writer.print("\x1b[{d};{d}H", .{ pos.row, pos.col });
    try writer.writeAll(bytes);
}
