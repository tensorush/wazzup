const std = @import("std");
const xev = @import("xev");
const Client = @import("Client.zig");
const config = @import("config.zig");

pub fn main() !void {
    // Define synchronous client IO interface.
    const out = std.io.getStdOut();
    const in = std.io.getStdIn();

    // Prompt client for name.
    try out.writer().print("Please enter your name not longer than {d} bytes:\n", .{config.MAX_MSG_LEN});

    // Define asynchronous client IO interface.
    var client = Client{ .writer = try xev.File.init(out), .reader = try xev.File.init(in) };

    // Define thread pool for event loop.
    var thread_pool = xev.ThreadPool.init(.{});
    defer thread_pool.deinit();
    defer thread_pool.shutdown();

    // Define event loop.
    var loop = try xev.Loop.init(.{ .entries = config.MAX_NUM_SOCKETS, .thread_pool = &thread_pool });
    defer loop.deinit();

    // Open TCP socket.
    var socket = try xev.TCP.init(config.IP_ADDRESS);

    // Declare completion for scanning input and sending messages to server.
    var in_completion: xev.Completion = undefined;

    // Connect to server.
    socket.connect(&loop, &in_completion, config.IP_ADDRESS, Client, &client, Client.connectCallback);

    // Enter event loop.
    try loop.run(.until_done);
}
