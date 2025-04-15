fn int2string(n: i64) !void {
    // const n = 42;
    var buf: [256]u8 = undefined;
    const str = try std.fmt.bufPrint(&buf, "{}", .{n});
    std.debug.print("{s}\n", .{str});

    // const integer = fmt.parseInt(i32, "-1425"); // Interprets string as an i32 value.
    // const float = fmt.parseFloat(f64, "25125.1254242535"); // Interprets strings as an f64 value.
}

fn usizeToStr(v: usize) ![]const u8 {
    return std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{v});
}

fn numericToStr(v: anytype) ![]const u8 {
    return std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{v});
}

pub fn allocNumericToStr(allocator: std.mem.Allocator, v: anytype) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{v});
}

pub fn allocAnyToStr(allocator: std.mem.Allocator, v: anytype) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{any}", .{v});
}

// not work
fn anyToStr(max_buf_len: comptime_int, v: anytype) ![]const u8 {
    var buf: [max_buf_len]u8 = undefined;
    _ = try std.fmt.bufPrint(&buf, "{}", .{v});
    return buf[0..];
}

fn bufAnyToStr(buf: []u8, v: anytype) ![]u8 {
    const numAsString = try std.fmt.bufPrint(buf, "{}", .{v});
    return numAsString;
}

fn copyIntStr(n: usize) []const u8 {
    var buffer: [4096]u8 = undefined;
    const result = std.fmt.bufPrintZ(buffer[0..], "{d}", .{n}) catch unreachable;
    return @as([]const u8, result);
}

test "strings 1" {
    std.debug.print("\n", .{});

    const testNumber: u128 = 91;

    // not work,
    const numAsString = try anyToStr(20, testNumber);
    std.debug.print("num: {s} \n", .{numAsString});

    var buffer: [4096]u8 = undefined;
    const ns = try bufAnyToStr(buffer[0..], testNumber);
    std.debug.print("num(ok): {s} \n", .{ns});

    const str = try numericToStr(testNumber);
    std.debug.print("numericToStr(num): {s} \n", .{str});
}

const time = struct {
    const Nanosecond: i64 = 1;
    const Microsecond: i64 = 1000 * time.Nanosecond;
    const Milisecond: i64 = 1000 * time.Microsecond;
    const Second: i64 = 1000 * time.Milisecond;
    const Minute: i64 = 60 * time.Second;
    const Hour: i64 = 60 * time.Minute;
};

const Duration = struct {
    ns: u64,
    const Self = @This();
    pub fn from(ns: i64) Self {
        return .{ .ns = @intCast(ns) };
    }
    pub fn fmt(self: Self) @typeInfo(@TypeOf(std.fmt.fmtDuration)).@"fn".return_type.? {
        return std.fmt.fmtDuration(self.ns);
    }
};

test "durations" {
    const d1 = 5 * time.Second;
    const d2 = time.Second / 4;
    const d3 = 250 * time.Milisecond;
    const sum = d1 + d2 + d3;

    print("d1 = {d}\n", .{Duration.from(d1).fmt()});
    print("d2 = {d}\n", .{duration(d2)});
    print("d3 = {d}\n", .{duration(d3)});
    print("sum = {d}\n", .{duration(sum)});

    // Output:
    // d1 = 5s
    // d2 = 250ms
    // d3 = 250ms
    // sum = 5.5s
}

const ConvertError = error //we create an error that means we will return if the value was too high or too low
    {
        TooBig,
        TooSmall,
    };

fn convertToI64(input: u64) !i64 {
    const MAX_I64: i64 = std.math.maxInt(i64); //get the maximum possible value for an i64 from the standard library

    const MIN_I64: i64 = std.math.minInt(i64); //get the minimum possible value for an i64 from the standard library

    if (input > MAX_I64) { //if it's higher than the max value
        return ConvertError.TooBig; //return an error
    }
    if (input < MIN_I64) { //if it's lower than the min value
        return ConvertError.TooSmall; //return an error
    }
    return @intCast(input); //otherwise return the input casted to an i64
}

test "u64 to i64" {
    const number: u64 = 40000;
    const number2: i64 = convertToI64(number) catch 0; //if there was an error, then make the default value 0

    std.debug.print("number2 {}\n", .{number2}); //print the converted number
}

pub fn parseIntSample(comptime T: type, buf: []const u8, base: u8) std.ParseIntError!T {
    return std.parseIntWithGenericCharacter(T, u8, buf, base);
}

test "string to int" {
    const foo = "22";

    const integer = try std.fmt.parseInt(i32, foo, 10);
    std.debug.print("integer {}\n", .{integer}); //print the converted number
}

const std = @import("std");

const print = std.debug.print;
const duration = std.fmt.fmtDuration;
