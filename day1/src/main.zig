const std = @import("std");

const word_digits = [_][]const u8{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };
const num_digits = [_][]const u8{ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" };

fn trebuchet(allocator: anytype, reader: anytype) !usize {
    const ReaderType = @TypeOf(reader);
    std.debug.assert(@hasDecl(ReaderType, "read"));

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();
    var line_count: usize = 1;

    var digits: [2]?u8 = .{ null, null };

    var sum: usize = 0;

    while (true) {
        // std.debug.print("processing line {d}\n", .{line_count});
        reader.streamUntilDelimiter(line.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => {
                if (line.items.len == 0) break;
            },
            else => return err,
        };
        var utf8 = (try std.unicode.Utf8View.init(line.items)).iterator();
        while (utf8.nextCodepointSlice()) |cs| {
            var matched = false;
            const rem_bytes_count = line.items.len - (@intFromPtr(cs.ptr) - @intFromPtr(line.items.ptr));
            // std.debug.print("remaining bytes is {d}\n", .{rem_bytes_count});
            const rem_bytes = cs.ptr[0..rem_bytes_count];

            for (num_digits, 0..) |char, digit| {
                if (std.mem.startsWith(u8, rem_bytes, char)) {
                    matched = true;
                    // std.debug.print("matched number {s}\n", .{char});
                    if (digits[0] == null) {
                        digits[0] = @intCast(digit);
                        digits[1] = @intCast(digit);
                    } else {
                        digits[1] = @intCast(digit);
                    }
                    var skip_bytes = char.len - 1;
                    while (skip_bytes > 0 and utf8.nextCodepointSlice() != null) : (skip_bytes -= 1) {}
                    break;
                }
            }
            if (matched) {
                // std.debug.print("matched a number so moving to next\n", .{});
                continue;
            }
            for (word_digits, 0..) |word, i| {
                const digit = i + 1;
                if (std.mem.startsWith(u8, rem_bytes, word)) {
                    matched = true;
                    // std.debug.print("matched string {s}\n", .{word});
                    if (digits[0] == null) {
                        digits[0] = @intCast(digit);
                        digits[1] = @intCast(digit);
                    } else {
                        digits[1] = @intCast(digit);
                    }
                    // var skip_bytes = word.len - 1;
                    // while (skip_bytes > 0 and utf8.nextCodepointSlice() != null) : (skip_bytes -= 1) {}
                    break;
                }
            }
            if (matched) {
                // std.debug.print("matched a number from a string so moving to next\n", .{});
                continue;
            }
        }
        std.debug.print("found digits for line {any}", .{digits});

        var line_value: u32 = 0;
        for (digits, 0..) |value, i| {
            const val = value orelse std.debug.panic("unexpected null digit {any} in line {d}", .{ digits, line_count });
            const exponent = @as(u32, @intCast(digits.len - 1 - i));
            line_value += val * std.math.pow(u32, 10, exponent);
            digits[i] = null;
        }

        sum += line_value;
        std.debug.print(" added {?} to running total of {d}\n", .{ line_value, sum });
        line.clearRetainingCapacity();
        line_count += 1;
    }

    std.debug.print("processed {d} lines\n", .{line_count - 1});
    return sum;
}

pub fn main() !void {
    std.debug.print("Day 1 - Trebuchet\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const reader = file.reader();

    const result = trebuchet(allocator, reader) catch |e| {
        std.debug.panic("could not produce a total: {!}", .{e});
    };

    std.debug.print("the total: {d}\n", .{result});
}

test "a single line with two digits" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u21).init(allocator);
    defer list.deinit();

    const data = "a12b\n";
    var fbs = std.io.fixedBufferStream(data);

    const result = try trebuchet(allocator, fbs.reader());
    try std.testing.expectEqual(12, result);
}

test "multiple lines with two digits" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u21).init(allocator);
    defer list.deinit();

    const data = "a12b\na23b\na45\n";
    var fbs = std.io.fixedBufferStream(data);

    const result = try trebuchet(allocator, fbs.reader());
    try std.testing.expectEqual(12 + 23 + 45, result);
}

test "multiple lines with word digits" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u21).init(allocator);
    defer list.deinit();

    const data = "two1nine\neightwothree\nabcone2threexyz\nxtwone3four\n4nineeightseven2\nzoneight234\n7pqrstsixteen\n";
    var fbs = std.io.fixedBufferStream(data);

    const result = try trebuchet(allocator, fbs.reader());
    try std.testing.expectEqual(29 + 83 + 13 + 24 + 42 + 14 + 76, result);
}

test "lines with word one" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u21).init(allocator);
    defer list.deinit();

    const data = "one\n";
    var fbs = std.io.fixedBufferStream(data);

    const result = try trebuchet(allocator, fbs.reader());
    try std.testing.expectEqual(11, result);
}

test "lines with word eight" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u21).init(allocator);
    defer list.deinit();

    const data = "abceightdef\n";
    var fbs = std.io.fixedBufferStream(data);

    const result = try trebuchet(allocator, fbs.reader());
    try std.testing.expectEqual(88, result);
}

test "lines with words that overlap" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u21).init(allocator);
    defer list.deinit();

    const data = "abceightwodef\n";
    var fbs = std.io.fixedBufferStream(data);

    const result = try trebuchet(allocator, fbs.reader());
    try std.testing.expectEqual(82, result);
}

test "lines with word zero should not be included" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u21).init(allocator);
    defer list.deinit();

    const data = "abczero1def\n";
    var fbs = std.io.fixedBufferStream(data);

    const result = try trebuchet(allocator, fbs.reader());
    try std.testing.expectEqual(11, result);
}

test "line without a trailing newline" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u21).init(allocator);
    defer list.deinit();

    const data = "abc1def";
    var fbs = std.io.fixedBufferStream(data);

    const result = try trebuchet(allocator, fbs.reader());
    try std.testing.expectEqual(11, result);
}
