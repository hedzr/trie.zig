const fmtcvt = @import("fmtcvt.zig");
const trietree = @import("trie.zig");

pub const BufferPrinter = @import("bufprt.zig").BufferPrinter;

pub const Type = packed struct {
    leaf: bool = false,
    with_data: bool = false,
    modified: bool = false,
};

pub fn Node(comptime T: type) type {
    return struct {
        path: []const u8,
        fragment: ?[]u8,
        children: ?[]*Node(T),
        data: ?*T,
        // nodetype: NodeType = .Branch,
        nodetype: Type = .{}, // default is a branch node

        const Self = @This();

        pub fn setModified(self: *Self, b: bool) void {
            // if (b) {
            //     self.nodetype &= .Modified;
            // } else {
            //     self.nodetype ^= ~.Modified;
            // }
            self.nodetype.modified = b;
        }
        pub fn setHasData(self: *Self, b: bool) void {
            // if (b) {
            //     self.nodetype &= .WithData;
            // } else {
            //     self.nodetype ^= ~.WithData;
            // }
            self.nodetype.with_data = b;
        }
        pub fn setData(self: *Self, data: *T) void {
            self.data = data;
            self.setHasData(true);
        }
        pub fn isModified(self: Self) bool {
            return self.nodetype.modified;
        }
        pub fn isBranch(self: Self) bool {
            return self.nodetype.leaf == false;
        }
        pub fn isLeaf(self: Self) bool {
            return self.nodetype.leaf;
        }
        pub fn hasData(self: Self) bool {
            return self.nodetype.with_data and self.data != null;
        }
        pub fn hasChild(self: Self) bool {
            return self.children and self.children.?.len > 0;
        }

        fn min(comptime TT: type, a: TT, b: TT) TT {
            return if (a < b) a else b;
        }
        // fn max(comptime TT: type, a: TT, b: TT) TT {
        //     return if (a > b) a else b;
        // }

        fn findCommonPrefixLength(self: Self, word: []const u8) usize {
            // const minl = min(word.len, self.fragment.?.len);
            var l: usize = 0;
            if (self.fragment) |frag| {
                const ml = min(usize, word.len, frag.len);
                for (word[0..ml], frag[0..ml]) |a, b| {
                    if (a != b) return l;
                    l += 1;
                }
            }
            return l;
        }

        pub fn endsWith(self: *Self, ch: u8) bool {
            if (self.fragment) |frag| {
                if (frag.len > 0 and frag[frag.len - 1] == ch) return true;
            }
            return false;
        }

        pub const matchReturn = struct {
            node: ?*Self = null,
            parent: ?*Self = null,
            matched: bool = false,
            partialMatched: bool = false,
            lastRuneIsDelimiter: bool = false,
        }; // trie: *trietree.Trie(T),
        const delimiter = '.';
        pub fn matchR(self: *Self, word: []const u8, parentNode: *Self) matchReturn {
            const base = self;
            if (word.len == 0) return .{ .node = base };

            var matched = false;
            var partialMatched = false;
            var lastRuneIsDelimiter = false;
            var child: ?*Self = null;
            var parent: ?*Self = null;
            var srcMatchedL: usize = 0;
            var dstMatchedL: usize = 0;
            const l = base.fragment.?.len;
            const wl = word.len;
            const minL: usize = min(usize, l, wl);
            // const maxL: usize = max(usize, l, wl);

            while (srcMatchedL < minL) : (srcMatchedL += 1) {
                const ch = base.fragment.?[srcMatchedL];
                if (ch == word[srcMatchedL]) {
                    lastRuneIsDelimiter = ch == delimiter;
                    continue; // first comparing loop, assume the index to base.path and word are both identical.
                }

                dstMatchedL = srcMatchedL; // sync the index now

                // if partial matched,
                if (srcMatchedL < l) {
                    if (srcMatchedL < wl) {
                        if (lastRuneIsDelimiter) {
                            // matching "/*filepath"
                            if (ch == '*') {}
                            // matching "/:id/"
                            if (ch == ':') {}
                        }
                        // NOT matched and shall stop.
                        // eg: matching 'apple' on 'apk'
                        return .{};
                    }
                    // matched.
                    // eg: matching 'app' on 'apple', or 'apk' on 'apple'
                    return .{ .node = base, .parent = parentNode, .matched = true };
                }
            }

            if (srcMatchedL == l - 1 and base.fragment.?[srcMatchedL] == delimiter) {
                matched = true;
                child = base;
                parent = parentNode;
            } else if (minL < l and srcMatchedL == minL) {
                partialMatched = true;
                child = base;
                parent = parentNode;
            } else if (minL >= l and srcMatchedL == minL and minL > 0 and srcMatchedL > 0 and !partialMatched) {
                matched = true;
                child = base;
                parent = parentNode;
            }
            if (minL < wl) {
                if (base.children) |c| {
                    if (c.len == 0) {
                        return .{ .node = child, .parent = parent, .matched = false, .partialMatched = true, .lastRuneIsDelimiter = lastRuneIsDelimiter };
                    }
                } else {
                    return .{ .node = child, .parent = parent, .matched = false, .partialMatched = true, .lastRuneIsDelimiter = lastRuneIsDelimiter };
                }

                // restPart := word[minL:]
                if (dstMatchedL == 0) {
                    dstMatchedL = minL;
                }
                const restPart = word[dstMatchedL..];
                for (base.children.?) |c| {
                    const ret = c.matchR(restPart, self);
                    if (ret.matched or ret.partialMatched) {
                        return ret;
                    }
                }
            }
            return .{ .node = child, .parent = parent, .matched = matched, .partialMatched = partialMatched, .lastRuneIsDelimiter = lastRuneIsDelimiter };
        }

        pub const insertReturn = struct {
            node: ?*Self,
            oldData: ?*T,
        };
        pub fn insert(self: *Self, trie: *trietree.Trie(T), word: []const u8, args: anytype) !insertReturn {
            return self.insertInternal(trie, word, args);
        }
        fn insertInternal(self: *Self, trie: *trietree.Trie(T), word: []const u8, args: anytype) !insertReturn {
            const ourLen = self.fragment.?.len;
            if (ourLen == 0) {
                if (word.len > 0 and self.children.?.len == 0) {
                    const node = try self.insertAsLeaf(trie, word, args);
                    return .{ .node = node, .oldData = null };
                }
            }

            var node: ?*Self = null;
            var oldData: ?*T = null;

            const cpl = self.findCommonPrefixLength(word);
            // std.debug.print("     cpl: {d}, ourLen: {d}, word: {s}\n", .{ cpl, ourLen, word });
            if (cpl < ourLen) {
                _ = try self.split(trie, cpl, word);
            }
            if (cpl < word.len) {
                var key = word;
                if (cpl > 0) {
                    key = key[cpl..];
                    // std.debug.print("     key = {s}, word = {s}\n", .{ key, word });
                }
                const r = self.matchChildren(key);
                if (r.matched) {
                    if (r.child) |c| {
                        return c.insertInternal(trie, key, args);
                    }
                }
                // std.debug.print("     insertAsLeaf: key = {s}, owner = {s}\n", .{ key, self.fragment.? });
                node = try self.insertAsLeaf(trie, key, args);
            } else {
                node = self;
                oldData = self.data;
                const data = try NodeValue.init(trie.alloc.allocator(), args.data);
                self.setData(data);
            }
            return .{ .node = node, .oldData = oldData };
        }
        pub fn split(self: *Self, trie: *trietree.Trie(T), pos: usize, word: []const u8) !*Self {
            const d = self.fragment.?.len - pos;
            _ = word;
            // std.debug.print("     split: pos: {d}, d: {d}, frag: {s}, path: {s}, word: {s}\n", .{ pos, d, self.fragment.?, self.path, word });

            const new: *Self = try trie.allocNode(.{
                .path = try trie.alloc.allocator().dupe(u8, self.path),
                .fragment = self.fragment.?[pos..],
                .children = self.children,
                .data = self.data,
                .nodetype = self.nodetype,
            });
            // std.debug.print("     split: self.path: {s}, new.path: {s}\n", .{ self.path, new.path });

            self.* = .{
                .path = try trie.alloc.allocator().dupe(u8, self.path[0 .. self.path.len - d]),
                .fragment = self.fragment.?[0..pos],
                .children = try allocAsChildren(trie, new),
                .data = null,
                .nodetype = .{},
            };
            // std.debug.print("     split: self.path: {s}, new.path: {s}\n", .{ self.path, new.path });

            return new;
        }
        pub fn insertAsLeaf(self: *Self, trie: *trietree.Trie(T), word: []const u8, args: anytype) !*Self {
            const df = try trie.allocSlice(u8, word);
            const data = try NodeValue.init(trie.alloc.allocator(), args.data);
            const new: *Self = try trie.allocNode(.{
                .path = try trie.alloc.allocator().dupe(u8, args.path),
                .fragment = df,
                .children = null,
                .data = data,
                .nodetype = .{ .leaf = true, .with_data = true },
            });
            try self.appendChild(trie, new);
            return new;
        }

        fn matchChildren(self: Self, word: []const u8) struct { matched: bool, child: ?*Self } {
            if (self.children) |children| {
                for (children) |c| {
                    if (c.fragment) |cf| {
                        if (cf[0] == word[0]) return .{ .matched = true, .child = c };
                    }
                }
            }
            return .{ .matched = false, .child = null };
        }
        fn allocAsChildren(trie: *trietree.Trie(T), child: *Self) ![]*Self {
            const al = try trie.allocSliceWithOneElem(*Self, child);
            return al;
        }
        fn appendChild(self: *Self, trie: *trietree.Trie(T), child: *Self) !void {
            if (self.children) |c| {
                var al = try trie.allocSliceAppend(*Self, c, 1);
                al[c.len] = child;
                self.children = al;
            } else {
                self.children = try trie.allocSliceWithOneElem(*Self, child);
            }
        }

        pub fn dump(self: Self, bp: *BufferPrinter) ![]const u8 {
            return self.dumpR(bp, &self, 0);
        }
        fn dumpR(self: Self, pb: *BufferPrinter, ptr: *const Self, level: usize) ![]const u8 {
            try pb.appendRepeat(' ', level * 2);
            if (ptr.fragment) |sz| {
                _ = try pb.appendFormat("{s}", .{sz});
            }
            const tabStop = 58;
            const sep = tabStop - level * 2 - ptr.fragment.?.len; // todo, calc utf8 length of fragment
            try pb.appendRepeat(' ', sep);
            if (ptr.isBranch()) {
                _ = try pb.appendFormat("  ; [B] {s}\n", .{ptr.path});
            } else {
                if (ptr.data) |d| {
                    const dstr = try d.toString(pb.alloc);
                    _ = try pb.appendFormat("  ; [L] {s} => {s}\n", .{ ptr.path, dstr });
                } else {
                    _ = try pb.appendFormat("  ; [:] {s} => (null)\n", .{ptr.path});
                }
            }
            // _ = try pb.appendFormat("  ; {s} => {s} \n", .{ ptr.path, "(val)" });
            if (ptr.children) |c| {
                const l = level + 1;
                for (c) |child| {
                    const line = try self.dumpR(pb, child, l);
                    // try pb.print("{s}", .{line});
                    _ = line;
                }
            }
            return pb.str();
        }
    };
}

pub const NodeType = enum(i16) {
    Branch,
    Leaf = 1,
    WithData = 8,
    Modified = 128,
};

pub const NodeValueType = enum {
    nothing,
    int,
    float,
    boolean,
    string,
};

pub const NodeValue = union(NodeValueType) {
    nothing: void,
    int: i64,
    float: f64,
    boolean: bool,
    string: []const u8,

    const Self = @This();
    pub fn init(alloc: std.mem.Allocator, v: anytype) !*Self {
        const ptr = try alloc.create(Self);
        // std.debug.print("      // ptr = {any}\n", .{ptr});
        ptr.* = try instance(v);
        return ptr;
    }
    fn instance(v: anytype) !Self {
        // std.debug.print("    NodeValue.set({any})\n", .{v});
        switch (@typeInfo(@TypeOf(v))) {
            .comptime_int, .int => {
                return .{ .int = std.math.cast(i64, v) orelse return error.Overflow };
            },
            .comptime_float, .float => return .{ .float = std.math.lossyCast(f64, v) },
            .bool => return .{ .boolean = v },
            // .@"struct" => |info| if (info.is_tuple) {},
            // .@"union" => |info| if (info.tag_type) |tag_type| {},
            // .array => return encode(arena, &input),
            .pointer => |info| switch (info.size) {
                .one => switch (@typeInfo(info.child)) {
                    .array => |child_info| {
                        // const Slice = []const child_info.child;
                        // // return encode(arena, @as(Slice, v));
                        // // _ = Slice;
                        // std.debug.print("  {}, {s}\n", .{ Slice, v });
                        _ = child_info;
                        return .{ .string = v };
                    },
                    else => {
                        @compileError("Unhandled type: {s}" ++ @typeName(info.child));
                    },
                },
                .slice => {
                    if (info.child == u8) {
                        // return Value{ .string = try arena.dupe(u8, input) };
                        @compileError("Cannot set a *[]u8 into .string field, need arena.dup it at first. Unhandled type: {s}" ++ @typeName(info.child));
                    }

                    // var list = std.ArrayList(Value).init(arena);
                    // errdefer list.deinit();
                    // try list.ensureTotalCapacityPrecise(input.len);

                    // for (input) |elem| {
                    //     if (try encode(arena, elem)) |value| {
                    //         list.appendAssumeCapacity(value);
                    //     } else {
                    //         log.debug("Could not encode value in a list: {any}", .{elem});
                    //         return error.CannotEncodeValue;
                    //     }
                    // }

                    // return Value{ .list = try list.toOwnedSlice() };
                },
                else => {
                    @compileError("Unhandled type: {s}" ++ @typeName(@TypeOf(v)));
                },
            },
            // .optional => return if (input) |val| encode(arena, val) else null,
            // .null => null;
            else => {
                @compileError("Unhandled type: {s}" ++ @typeName(@TypeOf(v)));
            },
        }
        // switch (@TypeOf(v)) {
        //     int: self.int = v,
        //     float: self.float = v,
        //     @"bool": self.boolean = v,
        // }
    }
    pub fn get(self: Self) bool {
        switch (self) {
            NodeValueType.int => |v| return v,
            NodeValueType.float => |v| return v,
            NodeValueType.boolean => |v| return v,
            NodeValueType.string => |v| return v,
            else => return undefined,
        }
    }
    // pub fn as(self: Self, comptime T: type) T {
    //     switch (self) {
    //         NodeValueType.int => |v| return v,
    //         NodeValueType.float => |v| return v,
    //         NodeValueType.boolean => |v| return v,
    //         NodeValueType.string => |v| return v,
    //         else => return undefined,
    //     }
    // }
    pub fn toString(self: Self, alloc: std.mem.Allocator) ![]const u8 {
        switch (self) {
            NodeValueType.int => |v| return fmtcvt.allocNumericToStr(alloc, v),
            NodeValueType.float => |v| return fmtcvt.allocNumericToStr(alloc, v),
            NodeValueType.boolean => |v| return if (v) "true" else "false",
            NodeValueType.string => |v| return v,
            else => return "(nothing)",
        }
    }
    // pub fn as1(self: Self, t:NodeValueType) T {
    //     switch (self) {
    //         NodeValueType.int => |v| return v,
    //         NodeValueType.float => |v| return v,
    //         NodeValueType.boolean => |v| return v,
    //         NodeValueType.string => |v| return v,
    //         else => return undefined,
    //     }
    // }

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
