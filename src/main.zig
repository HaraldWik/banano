const std = @import("std");
const Terminal = @import("Terminal.zig");

pub fn main() !void {
    const in_file_name = for (std.os.argv[1..]) |arg| {
        std.fs.cwd().accessZ(arg, .{}) catch continue;
        break std.mem.span(arg);
    } else "tmp";
    var file_name_buffer: [std.fs.max_name_bytes]u8 = undefined;
    const out_file_name = try std.fmt.bufPrint(&file_name_buffer, ".{s}.banano", .{in_file_name});
    const file: std.fs.File = try std.fs.cwd().createFile(out_file_name, .{});
    defer file.close();

    const terminal: Terminal = try .init(.stdout());
    defer terminal.deinit();
    try terminal.file.writeAll("\x1b[38;5;226m");

    var buffer: [std.heap.pageSize() * 16]u8 = undefined;
    var editing: std.Deque(u8) = .initBuffer(&buffer);

    while (try terminal.next()) |event| {
        switch (event) {
            .char => |char| {
                try terminal.file.writeAll(&.{char});
                editing.pushBackAssumeCapacity(char);
            },
            .enter => {
                try terminal.file.writeAll("\n\r");
                editing.pushBackAssumeCapacity('\n');
            },
            .backspace => {
                try terminal.file.writeAll("\x1b[1D\x1b[K");
                _ = editing.popBack();
            },
            .esc_code => |code| {
                switch (code) {
                    .up => try terminal.file.writeAll("\x1b[1A"),
                    .down => try terminal.file.writeAll("\x1b[1B"),

                    else => |char| {
                        std.debug.print("\n\rInvalid Esc Code {d} {c}\n\r", .{ @intFromEnum(char), @intFromEnum(char) });
                    },
                }
            },
        }
    }

    try file.writeAll(editing.buffer[editing.head..editing.len]);
    try std.fs.cwd().rename(out_file_name, in_file_name);
}
