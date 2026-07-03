const std = @import("std");
const Screen = @import("Screen.zig");
const Text = @import("Text.zig");
const ansi = @import("ansi.zig");

const color = "\x1b[38;5;226m"; // Banana color

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);

    const in_file_name: ?[:0]const u8 = for (args[1..]) |arg| {
        std.Io.Dir.cwd().access(io, arg, .{}) catch continue;
        break arg;
    } else null;
    var file_name_buffer: [std.fs.max_name_bytes]u8 = undefined;
    const out_file_name = try std.fmt.bufPrint(&file_name_buffer, ".{s}.banano", .{in_file_name orelse "tmp"});
    const file: std.Io.File = try std.Io.Dir.cwd().createFile(io, out_file_name, .{});
    defer file.close(io);

    var screen: Screen = try .init(io, .stdout());
    defer screen.deinit();
    try screen.file.writeStreamingAll(io, color);

    var text: Text = try .initCapacity(gpa, size: {
        const file_size: usize = @intCast((try file.stat(io)).size);
        break :size @max(std.heap.pageSize(), file_size);
    });
    defer text.deinit();

    if (in_file_name) |name| {
        const in: std.Io.File = try std.Io.Dir.cwd().openFile(io, name, .{});
        defer in.close(io);

        var buffer: []u8 = try gpa.alloc(u8, @intCast((try in.stat(io)).size));
        defer gpa.free(buffer);
        const n = try in.readStreaming(io, &.{buffer});
        try text.insertSlice(0, buffer[0..n]);
        try screen.writeAt(.{ .row = 3 }, name);
    }

    try draw(screen, text, in_file_name orelse "new file");

    var cursor: Screen.Position = .{ .row = 1 };

    while (try screen.nextEvent()) |event| {
        const size: Screen.Size = try screen.getSize();

        switch (event) {
            .char => |char| {
                if (std.ascii.isControl(char)) continue;

                try text.insert(text.len, char);
                cursor.col += 1;
            },
            .enter => {
                try text.insertSlice(text.len, "\n\r");
                cursor.row = 0;
                cursor.col += 1;
            },
            .backspace => {
                if (text.len <= 0) continue;

                text.delete(text.len - 1);
                cursor.col -|= 1;
            },
            .esc_code => |code| {
                switch (code) {
                    .up => try screen.file.writeStreamingAll(io, "\x1b[1A"),
                    .down => try screen.file.writeStreamingAll(io, "\x1b[1B"),

                    else => |char| {
                        var buffer: [64]u8 = undefined;
                        try screen.printAt(.{ .row = size.row }, &buffer, "Unhandled esc code {d} {c}", .{ @intFromEnum(char), @intFromEnum(char) });
                    },
                }
            },
        }
        try draw(screen, text, in_file_name orelse "new file");
    }

    try file.writeStreamingAll(io, text.str.items[0..text.len]);
    try std.Io.Dir.cwd().rename(out_file_name, .cwd(), in_file_name orelse "new", io);
}

pub fn draw(screen: Screen, text: Text, file_name: [:0]const u8) !void {
    const size = try screen.getSize();

    try screen.clear();
    try screen.writeAt(.{}, ansi.inverted);
    try screen.writeAt(.{}, "Banano");
    try screen.writeAt(.{ .col = @divTrunc(size.col, 2) }, file_name);
    try screen.writeAt(.{}, ansi.reset ++ color);
    try screen.writeAt(.{ .row = 1 }, text.str.items[0..text.len]);
}
