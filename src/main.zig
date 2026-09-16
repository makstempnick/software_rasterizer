const std = @import("std");
const App = @import("App.zig");

pub fn main() !void {
    var allocator = std.heap.DebugAllocator(.{}).init;

    const gpa = allocator.allocator();

    var app = try App.init(gpa);

    defer {
        app.deinit(gpa);
        _ = allocator.deinit();
    }

    try app.start();
}
