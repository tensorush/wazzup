const std = @import("std");
const xev = @import("xev");
const Server = @import("Server.zig");
const config = @import("config.zig");

pub fn main() !void {
    // Define allocator.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Memory leak has occurred!");
    };
    const allocator = gpa.allocator();

    // Open TCP socket.
    var socket = try xev.TCP.init(config.IP_ADDRESS);

    // Listen for client connections.
    try socket.bind(config.IP_ADDRESS);
    try socket.listen(config.MAX_NUM_SOCKETS);

    // Define thread pool for event loop.
    var thread_pool = xev.ThreadPool.init(.{});
    defer thread_pool.deinit();
    defer thread_pool.shutdown();

    // Define event loop.
    var loop = try xev.Loop.init(.{ .entries = config.MAX_NUM_SOCKETS, .thread_pool = &thread_pool });
    defer loop.deinit();

    // Declare completion for accepting connections and receiving messages from clients.
    var in_completion: xev.Completion = undefined;

    // Pre-allocate server resources.
    var server = try Server.init(allocator);
    defer server.deinit(allocator);

    // Accept client connections.
    socket.accept(&loop, &in_completion, Server, &server, Server.acceptCallback);

    // Enter event loop.
    try loop.run(.until_done);
}
