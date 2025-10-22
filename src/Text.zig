const std = @import("std");

allocator: std.mem.Allocator,

str: std.ArrayList(u8),
len: usize,

pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !@This() {
    return .{
        .allocator = allocator,
        .str = try std.ArrayList(u8).initCapacity(allocator, capacity),
        .len = 0,
    };
}

pub fn deinit(self: *@This()) void {
    self.str.deinit(self.allocator);
}

pub fn insert(self: *@This(), index: usize, char: u8) !void {
    if (index > self.len) return error.OutOfBounds;

    try self.str.ensureTotalCapacity(self.allocator, self.len + 1);

    self.str.items.len += 1;

    if (index < self.len) {
        std.mem.copyBackwards(
            u8,
            self.str.items[index + 1 .. self.len],
            self.str.items[index .. self.len - 1],
        );
    }

    self.str.items[index] = char;
    self.len += 1;
}

pub fn insertSlice(self: *@This(), index: usize, str: []const u8) !void {
    for (str, 0..) |char, i| try self.insert(index + i, char);
}

pub fn delete(self: *@This(), index: usize) void {
    if (self.len == 0) return;

    if (index >= self.len) return;

    @memcpy(self.str.items[index .. self.len - 1], self.str.items[index + 1 .. self.len]);

    self.len -= 1;
}
