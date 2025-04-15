//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const trie = @import("trie_lib");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try trie_test(stdout);

    try bw.flush(); // Don't forget to flush!
}

fn trie_test(writer: anytype) !void {
    const GPA = std.heap.GeneralPurposeAllocator;
    // var general_purpose_allocator = GPA(.{}){};
    // const gpa = general_purpose_allocator.allocator();
    var gpa = GPA(.{ .enable_memory_limit = true }){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var t = try trie.Trie(trie.NodeValue).init(allocator, "app");
    defer t.deinit();

    try t.set("logging.file", "/var/log/app/stdout.log");
    try t.set("logging.rotate", true);
    try t.set("logging.interval", 3 * 24 * 60 * 60 * 1000 * 1000); // 3 days
    try t.set("debug", false);
    try t.set("deb.install", false);
    try t.set("deb.target", "app-debug.deb");
    try t.set("debfile", "app-release.deb");

    // print("t: {s} \n", .{try t.dump()});
    const dstr = try t.dump();
    try writer.print("t.dump: \n{s} \n", .{dstr});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(trie.version, trie.version);
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
