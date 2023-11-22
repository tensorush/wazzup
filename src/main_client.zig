const std = @import("std");
const main_server = @import("main_server.zig");

pub fn main() !void {
    // Define allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Memory leak has occurred!\n");
    };
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize standard input reader
    const std_in = std.io.getStdIn();
    const reader = std_in.reader();

    // Initialize standard output writer
    const std_out = std.io.getStdOut();
    const writer = std_out.writer();

    // Get client name
    writer.writeAll("Enter your name:\n");
    var name_buf: [main_server.MAX_NAME_LEN]u8 = undefined;
    const name_len = reader.readAll(name_buf[0..]);

    // Connect to server
    const stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", 1337);
    try stream.writeAll(name_buf[0..name_len]);

    // TODO: Spawn another thread to poll server connection and receive messages

    // Prepare event loop variables
    var msg_buf: [main_server.MAX_MSG_LEN]u8 = undefined;
    var msg_len: usize = undefined;

    // Start event loop
    while (true) {
        // Read message
        msg_len = try reader.readAll(msg_buf[0..]);

        // Send message
        try stream.writeAll(msg_buf[0..msg_len]);
    }
}
