pub const BufferPrinter = struct {
    buffer: []u8,
    formatted: []u8,
    cap: usize,
    alloc: std.mem.Allocator,

    const initialSize = 1024;
    const blockSize = 4096;
    const SelfObj = @This();
    pub fn init(alloc: std.mem.Allocator) !*SelfObj {
        const buf = try alloc.alloc(u8, if (initialSize > 0) initialSize else blockSize);
        const ptr = try alloc.create(SelfObj);
        ptr.* = .{
            .buffer = buf,
            .formatted = buf[0..0],
            .cap = blockSize,
            .alloc = alloc,
        };
        return ptr;
    }
    pub fn deinit(self: *SelfObj) void {
        self.alloc.free(self.buffer);
        self.alloc.destroy(self);
    }

    pub fn str(self: SelfObj) []const u8 {
        return self.formatted;
    }

    fn enlarge(self: *SelfObj) !void {
        const dest = try self.alloc.alloc(u8, self.cap + blockSize);
        std.mem.copyForwards(u8, dest, self.buffer);
        self.cap += blockSize;
        const old = self.buffer;
        self.buffer = dest;
        self.alloc.free(old);
    }

    // pub inline fn comptimePrint(comptime fmt: []const u8, args: anytype) *const [count(fmt, args):0]u8 {
    //     comptime {
    //         var buf: [count(fmt, args):0]u8 = undefined;
    //         _ = bufPrint(&buf, fmt, args) catch unreachable;
    //         buf[buf.len] = 0;
    //         return &buf;
    //     }
    // }

    pub fn appendFormat(self: *SelfObj, comptime fmt: []const u8, args: anytype) ![]u8 {
        var dest: []u8 = undefined;
        var formattedSize = self.formatted.len;
        const buf = self.buffer[formattedSize..];
        // @compileLog("appendFormat() - fmt is " ++ fmt);
        // std.debug.print("    format(append): fmt: \"{s}\", args: {any}\n", .{ fmt, args });
        dest = std.fmt.bufPrint(buf, fmt, args) catch {
            try self.enlarge();
            const bufnew = self.buffer[formattedSize..];
            dest = try std.fmt.bufPrint(bufnew, fmt, args);
            formattedSize += dest.len;
            self.formatted = self.buffer[0..formattedSize];
            return self.formatted;
        };
        formattedSize += dest.len;
        self.formatted = self.buffer[0..formattedSize];
        return self.formatted; // self.buffer[0..];
    }
    pub fn format(self: *SelfObj, comptime fmt: []const u8, args: anytype) ![]u8 {
        self.formatted = std.fmt.bufPrint(self.buffer, fmt, args) catch {
            try self.enlarge();
            // @compileLog("format() - fmt is " ++ fmt);
            // std.debug.print("    format: fmt: \"{s}\", args: {any}\n", .{ fmt, args });
            self.formatted = try std.fmt.bufPrint(self.buffer, fmt, args);
            return self.formatted;
        };

        return self.formatted; // self.buffer[0..];
    }
    pub fn appendRepeat(self: *SelfObj, ch: u8, n: usize) !void {
        if (self.buffer.len + n >= self.cap) {
            try self.enlarge();
        }
        const formattedSize = self.formatted.len;
        var buf = self.buffer[formattedSize..];
        for (0..n) |i| {
            buf[i] = ch;
            // std.mem.copyForwards(u8, buf[self.size * i ..], buf[0..self.size]);
        }
        self.formatted = self.buffer[0 .. formattedSize + n];
    }
    pub fn repeat(self: *SelfObj, ch: u8, n: usize) !void {
        if (self.buffer.len + n >= self.cap) {
            try self.enlarge();
        }
        self.buffer[0] = ch;
        for (0..n) |i| {
            self.buffer[i] = ch;
            // std.mem.copyForwards(u8, self.buffer[i .. i + 1], self.buffer[0..1]);
        }
        self.formatted = self.buffer[0..n];
    }
};

const std = @import("std");
const builtin = std.builtin;
const debug = std.debug;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const assert = debug.assert;
const eql = mem.eql;
const expect = testing.expect;
const expectError = std.testing.expectError;
const print = debug.print;

const test_allocator = std.testing.allocator;

test "bufprinter" {
    const bp = try BufferPrinter.init(test_allocator);
    defer bp.deinit();

    try bp.repeat(' ', 4);
    var sz = try bp.format("{s}", .{"hello"});
    print("\n{s}\n", .{sz});
    try bp.appendRepeat(' ', 4);
    sz = try bp.appendFormat("{s} {s}", .{ ",", "world!" });
    print("{s}\n", .{sz});

    try bp.repeat(' ', 4);
    sz = try bp.appendFormat("{s} {s}", .{ "hello", "world" });
    print("{s}\n", .{sz});
}
