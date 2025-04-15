//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

pub const version = "v0.3.0";

test "basic functionality" {
    // try testing.expect(trie_add(3, 7) == 10);
}

pub usingnamespace @import("./trie.zig");
