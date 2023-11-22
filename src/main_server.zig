const std = @import("std");

pub const MAX_MSG_LEN = 1 << 8;
pub const MAX_NAME_LEN = 1 << 5;
const MAX_NUM_CLIENTS = 1 << 10;

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
    defer server.deinit();

    // Listen on address
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 1337);
    try server.listen(address);

    // Initialize connection pool
    var mutex = std.Thread.Mutex{};
    var clients = std.StringHashMapUnmanaged(std.net.StreamServer.Connection){};
    try clients.ensureTotalCapacity(allocator, MAX_NUM_CLIENTS);
    defer clients.deinit(allocator);

    // Prepare event loop variables
    var connection: std.net.StreamServer.Connection = undefined;
    var name_buf: [MAX_NAME_LEN]u8 = undefined;
    var name_len: usize = undefined;
    var name: []u8 = undefined;

    // TODO: Spawn threads to poll client connections and broadcast messages

    // Start event loop
    while (true) {
        // Accept connection
        connection = try server.accept();

        // Read client name
        name_len = try connection.stream.readAll(name_buf[0..]);

        // Allocate name copy
        name = try allocator.alloc(u8, name_len);
        @memcpy(name, name_buf[0..name_len]);

        // Store client connection by client name
        mutex.lock();
        defer mutex.unlock();

        clients.putAssumeCapacity(name, .{ .connection = connection });
    }
}
