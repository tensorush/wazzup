const std = @import("std");
const config = @import("config.zig");

pub fn main() !void {
    // Define allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Memory leak has occurred!");
    };
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    // Define standard IO handles
    const std_reader = std.io.getStdIn().reader();
    const std_writer = std.io.getStdOut().writer();

    // Connect to server
    const stream = try std.net.tcpConnectToHost(allocator, config.HOST, config.PORT);
    const stream_writer = stream.writer();
    const stream_reader = stream.reader();

    // Prompt client for name
    try std_writer.print("Please, enter your name, not longer than {d} bytes:\n", .{config.MAX_NAME_LEN});

    // Receive client's name
    while (std_reader.streamUntilDelimiter(stream_writer, '\n', config.MAX_MSG_LEN)) {} else |err| switch (err) {
        error.EndOfStream, error.StreamTooLong => try stream_writer.writeByte('\n'),
        else => |e| return e,
    }

    // Receive another client's name
    while (stream_reader.streamUntilDelimiter(std_writer, '\n', config.MAX_MSG_LEN)) {} else |err| switch (err) {
        error.EndOfStream, error.StreamTooLong => try std_writer.writeByte('\n'),
        else => |e| return e,
    }
}
