const std = @import("std");

const MAX_NUM_CLIENTS = 1 << 10;
const MAX_NAME_LEN = 1 << 5;

const Client = struct {
    connection: std.net.StreamServer.Connection,
    name_buf: [MAX_NAME_LEN]u8,
    name_len: usize,
};

pub fn main() !void {
    // Define allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Memory leak has occurred!\n");
    };
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create TCP socket server
    var server = std.net.StreamServer.init(.{ .kernel_backlog = MAX_NUM_CLIENTS, .reuse_address = true, .reuse_port = true });

    // Listen on address
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 1337);
    try server.listen(address);

    // Initialize connection pool
    var clients = std.StringHashMapUnmanaged(Client){};
    try clients.ensureTotalCapacity(allocator, MAX_NUM_CLIENTS);
    defer clients.deinit(allocator);

    // Prepare event loop variables
    var connection: std.net.StreamServer.Connection = undefined;
    var name_buf: [MAX_NAME_LEN]u8 = undefined;
    var name_len: usize = undefined;

    // Start event loop
    while (true) {
        // Accept connection
        connection = try server.accept();

        // Read client name
        name_len = try connection.stream.readAll(name_buf[0..]);

        // Store client connection by name
        clients.putAssumeCapacity(name_buf[0..name_len], .{ .connection = connection, .name_buf = name_buf, .name_len = name_len });

        // TODO: Poll connections and broadcast messages
    }
}
