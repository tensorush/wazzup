const std = @import("std");

const MAX_MSG_LEN = 1 << 8;

pub fn main() !void {
    // Define allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Memory leak has occurred!\n");
    };
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create client
    const stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", 1337);

    // Initialize standard input reader
    const std_in = std.io.getStdIn();
    const reader = std_in.reader();

    // Prepare event loop variables
    var msg_buf: [MAX_MSG_LEN]u8 = undefined;
    var msg_len: usize = undefined;

    // Start event loop
    while (true) {
        msg_len = try reader.readAll(msg_buf[0..]);

        try stream.writeAll(msg_buf[0..msg_len]);
    }
}
