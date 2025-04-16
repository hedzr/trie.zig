# trie.zig

`trie.zig` implement a Trie-tree structure in zig-lang.

`trie.zig` provides a key value storage identified by the dotted path, such as `app.logging.file` => `/var/log/app/stdout.log`.

`trie.zig` allows these value to be inserted: string, int, float, and boolean. The future vision includes supporting a broader array of data types, which is dependent on the usefulness of zig-lang's syntax as it evolves.

## Usage

The usage is,

```zig
const std = @import("std");
const trie = @import("trie_lib");

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
    try writer.print("\nt.dump: \n{s} \n", .{dstr});

    var v = try t.get("deb.target");
    try writer.print("\ndeb.target: {s} \n", .{v.string});

    v = try t.get("debfile");
    try writer.print("debfile: {s} \n", .{v.string});
    v = try t.get("deb.install");
    try writer.print("deb.install: {} \n", .{v.boolean});
    v = try t.get("logging.interval");
    try writer.print("logging.interval: {} \n", .{v.int});
    v = try t.get("logging.rotate");
    try writer.print("logging.rotate: {} \n", .{v.boolean});
    v = try t.get("debug");
    try writer.print("debug: {} \n", .{v.boolean});
}
```

### Import `trie.zig`

#### Dependency in `build.zig.zon`

In your `build.zig.zon`, add a reference to `trie.zig`:

```zig
.{
  .name = "my-app",
  .paths = .{""},
  .version = "0.0.0",
  .dependencies = .{
    .trie_lib = .{
      .url = "https://github.com/hedzr/trie.zig/archive/master.tar.gz",
      .hash = "$INSERT_HASH_HERE"
    },
  },
}
```

The hash can be found after run this fetch:

```bash
zig fetch https://github.com/hedzr/trie.zig/archive/master.tar.gz
```

Instead of `master` you can use a specific commit/tag.

#### Dependency in `build.zig`

Suppose you should already have an executable, something like:

```zig
    const exe = b.addExecutable(.{
        .name = "hotiz",
        .root_module = exe_mod,
    });
```

Add the following line:

```zig
exe.root_module.addImport("trie_lib", b.dependency("trie_lib", .{}).module("trie_lib"));
```

You can now `const trie = @import("trie_lib");` in your project.

## LICENSE

Apache 2.0
