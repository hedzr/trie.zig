pub const Node = nodeobj.Node;
pub const NodeValue = nodeobj.NodeValue;
pub const NodeValueType = nodeobj.NodeValueType;
pub const NodeType = nodeobj.Type;
pub const BufferPrinter = @import("bufprt.zig").BufferPrinter;

const nodeobj = @import("node.zig");
const fmtcvt = @import("fmtcvt.zig");

pub fn Trie(comptime T: type) type {
    return struct {
        prefix: []const u8,
        root: *Node(T) = undefined,

        jointBuffer: ?[]u8 = null,
        jointSize: usize = 0,

        alloc: std.heap.ArenaAllocator,
        allocSave: std.mem.Allocator,
        const Self = @This();
        const delimiter: u8 = '.';
        pub fn init(alloc: std.mem.Allocator, prefix: []const u8) !Self {
            var v = Self{
                .alloc = std.heap.ArenaAllocator.init(alloc),
                .allocSave = alloc,
                .prefix = prefix,
            };
            const df = try v.allocSlice(u8, prefix);
            v.root = try v.allocNode(.{
                .path = prefix,
                .fragment = df,
                .children = null,
                .data = null,
            });
            return v;
        }
        pub fn deinit(self: *Self) void {
            self.alloc.deinit();
        }

        pub fn allocPrint(self: *Self, comptime fmt: []const u8, args: anytype) std.fmt.AllocPrintError![]u8 {
            return std.fmt.allocPrint(self.alloc.allocator(), fmt, args);
        }

        pub fn allocSlice(self: *Self, comptime TT: type, content: []const TT) ![]TT {
            const dest = try self.alloc.allocator().alloc(TT, content.len);
            std.mem.copyForwards(TT, dest, content);
            return dest;
        }
        pub fn allocSliceWithOneElem(self: *Self, comptime TT: type, content: TT) ![]TT {
            const dest = try self.alloc.allocator().alloc(TT, 1);
            // std.mem.copyForwards(TT, dest, &content);
            dest[0] = content;
            return dest;
        }
        pub fn allocSliceAppend(self: *Self, comptime TT: type, content: []const TT, appendSize: usize) ![]TT {
            const dest = try self.alloc.allocator().alloc(TT, content.len + appendSize);
            std.mem.copyForwards(TT, dest, content);
            return dest;
        }
        fn allocObj(self: *Self, comptime TT: type, props: anytype) !*TT {
            const ptr = try self.alloc.allocator().create(TT);
            ptr.* = props;
            return ptr;
        }
        pub fn allocNode(self: *Self, props: Node(T)) !*Node(T) {
            const node = try self.allocObj(Node(T), props);
            return node;
        }
        pub fn allocValue(self: *Self, props: Node(T)) !*NodeValue(T) {
            const val = try self.allocObj(NodeValue(T), props);
            return val;
        }
        fn allocate(self: *Self, size: usize) Error!void {
            // const dest = try self.alloc.allocator().alloc(u8, size);
            // return dest;
            if (self.jointBuffer) |buffer| {
                if (size < self.jointSize) self.jointSize = size; // Clamp size to capacity
                self.jointBuffer = self.alloc.allocator().realloc(buffer, size) catch {
                    return Error.OutOfMemory;
                };
            } else {
                self.jointBuffer = self.alloc.allocator().alloc(u8, size) catch {
                    return Error.OutOfMemory;
                };
            }
        }

        pub const Error = error{
            OutOfMemory,
            InvalidRange,
        };

        // fn anyToVal(val: anytype) NodeValue {
        //     switch (@TypeOf(val)) {
        //         comptime_int => return .{
        //             .int = val,
        //         },
        //         else => return .{
        //             .nothing = undefined,
        //         },
        //     }
        // }

        pub fn join(self: *Self, args: anytype) ![]const u8 {
            return self.joinS(self.prefix, args);
        }
        fn joinS(self: *Self, pre: []const u8, args: anytype) ![]const u8 {
            var p = pre;
            inline for (args, 0..) |v, i| {
                p = try self.join2(p, v);
                // print("{}. {any}\n", .{ i, v });
                _ = i;
            }
            return p;
        }
        fn join2(self: *Self, pre: []const u8, sz: []const u8) ![]const u8 {
            if (sz.len == 0) return self.str();

            const totalSize = pre.len + sz.len + 1;
            if (self.jointBuffer) |buffer| {
                if (totalSize > buffer.len) {
                    try self.allocate((totalSize) * 2);
                }
            } else {
                try self.allocate((sz.len) * 2);
            }

            const buffer = self.jointBuffer.?;
            var i: usize = 0;
            var pos: usize = 0;
            while (i < pre.len) : (i += 1) {
                buffer[pos] = pre[i];
                pos += 1;
            }
            if (pos > 0) {
                buffer[pos] = delimiter;
                pos += 1;
            }
            i = 0;
            while (i < sz.len) : (i += 1) {
                buffer[pos] = sz[i];
                pos += 1;
            }
            buffer[pos] = 0;

            // var added = str.len + 1;
            // if (index == self.len()) {
            //     var i: usize = 1;
            //     buffer[self.jointSize] = delimiter;
            //     while (i < str.len) : (i += 1) {
            //         buffer[self.jointSize + i] = str[i];
            //     }
            // } else {
            //     if (Self.utf8getIndex(buffer, index, true)) |k| {
            //         var i: usize = buffer.len - 1;
            //         while (i >= k) : (i -= 1) {
            //             if (i + str.len < buffer.len) {
            //                 buffer[i + str.len] = buffer[i];
            //             }

            //             if (i == 0) break;
            //         }

            //         buffer[index] = delimiter;
            //         i = 1;
            //         while (i < str.len) : (i += 1) {
            //             buffer[index + i] = str[i];
            //         }
            //         added += 1;
            //     }
            // }

            self.jointSize = pos;
            return self.str();
        }
        fn utf8getIndex(unicode: []const u8, index: usize, real: bool) ?usize {
            var i: usize = 0;
            var j: usize = 0;
            while (i < unicode.len) {
                if (real) {
                    if (j == index) return i;
                } else {
                    if (i == index) return j;
                }
                i += Self.utf8getSize(unicode[i]);
                j += 1;
            }

            return null;
        }
        inline fn utf8getSize(char: u8) u3 {
            return std.unicode.utf8ByteSequenceLength(char) catch {
                return 1;
            };
        }
        inline fn utf8isByte(byte: u8) bool {
            return ((byte & 0x80) > 0) and (((byte << 1) & 0x80) == 0);
        }

        fn len(self: Self) usize {
            if (self.jointBuffer) |buffer| {
                var length: usize = 0;
                var i: usize = 0;
                while (i < self.jointSize) {
                    i += Self.utf8getSize(buffer[i]);
                    length += 1;
                }
                return length;
            }
            return 0;
        }
        pub fn str(self: Self) []const u8 {
            if (self.jointBuffer) |buffer| return buffer[0..self.jointSize];
            return "";
        }

        //
        // APIs ----------------------------------------
        //

        // pub fn subtree(self: Self, newPrefix: []const u8) !Self {
        //     const v = Self{
        //         .alloc = std.heap.ArenaAllocator.init(self.allocSave),
        //         .allocSave = self.allocSave,
        //         .prefix = newPrefix,
        //         .root = self.root,
        //     };
        //     return v;
        // }

        pub fn set(self: *Self, key: []const u8, val: anytype) !void {
            const keyPath = try self.join2(self.prefix, key);
            // std.debug.print("---- trie.set({s}): val ({}): {any} \n", .{ keyPath, @TypeOf(val), val });
            const ret = try self.root.insert(self, keyPath, .{ .path = keyPath, .data = val });
            if (ret.oldData) |ptr| {
                self.alloc.allocator().destroy(ptr);
            }

            // const dstr = try self.dump();
            // std.debug.print("t.dump: \n{s} \n\n", .{dstr});
        }
        pub fn get(self: Self, key: []const u8) !NodeValue {
            _ = .{ self, key };
            return .{ .string = "" };
        }

        pub fn dump(self: *Self) ![]const u8 {
            const alloc = self.alloc.allocator();
            const bp = try BufferPrinter.init(alloc);
            return self.root.dump(bp);
        }
    };
}

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

test "simple" {
    print("\n", .{});

    var conf = try Trie(NodeValue).init(test_allocator, "app");
    defer conf.deinit();
    try conf.set("a.b.c", 1);
    try conf.set("a.b.d", 2);
    try conf.set("a.b.b", true);
    try conf.set("a.b", "hello");
    print("conf: {} \n", .{conf});
    print("conf: {} \n", .{(try conf.get("a.b")).as([]const u8)});
}

// fn varargTest(args: anytype) !void {
//     inline for (args, 0..) |v, i| {
//         // try expect(v);
//         print("{}. {any}\n", .{ i, v });
//     }
// }
//
// test "anytype as vararg parameter" {
//     try varargTest(.{
//         @as(u32, 1234),
//         @as(f64, 12.34),
//         true,
//         "hi",
//     });
// }

test "trie.join" {
    print("\n", .{});

    var t = try Trie(i32).init(test_allocator, "app");
    defer t.deinit();

    var s = try t.join(.{"debug"});
    print("s: {s}, {} \n", .{ s, t.jointSize });
    try expect(eql(u8, s, "app.debug"));

    s = try t.join(.{ "logging", "file" });
    print("s: {s}, {} \n", .{ s, t.jointSize });
    try expect(eql(u8, s, "app.logging.file"));

    var t1 = try Trie(i32).init(test_allocator, "");
    defer t1.deinit();
    s = try t1.join(.{ "app", "logging", "file" });
    print("s: {s}, {} \n", .{ s, t1.jointSize });
    try expect(eql(u8, s, "app.logging.file"));
}

test "trie.set / node.insert" {
    print("\n", .{});

    var t = try Trie(NodeValue).init(test_allocator, "app");
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
    print("t.dump: \n{s} \n", .{dstr});
}
