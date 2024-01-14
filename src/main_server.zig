const std = @import("std");
const xev = @import("xev");
const config = @import("config.zig");

const MsgBufs = std.AutoHashMapUnmanaged(xev.TCP, MsgBuf);
const MsgBuf = std.fifo.LinearFifo(u8, .{ .Static = config.MAX_MSG_BUF_SIZE });

pub fn main() !void {
    // Define allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Memory leak has occurred!");
    };
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    // Pre-allocate client message buffers
    var msg_bufs = MsgBufs{};
    try msg_bufs.ensureTotalCapacity(allocator, config.MAX_NUM_CONNS);
    defer msg_bufs.deinit(allocator);

    // Define thread pool for event loop
    var thread_pool = xev.ThreadPool.init(.{});
    defer thread_pool.deinit();

    // Define event loop
    var loop = try xev.Loop.init(.{ .entries = config.MAX_NUM_CONNS, .thread_pool = &thread_pool });
    defer loop.deinit();

    // Prepare completion for accepting client connections
    var accept_completion: xev.Completion = undefined;

    // Define TCP server
    const address = try std.net.Address.parseIp(config.HOST, config.PORT);
    var server = try xev.TCP.init(address);

    // Listen for TCP connections
    try server.bind(address);
    try server.listen(config.KERNEL_BACKLOG);

    // Accept client connections
    server.accept(&loop, &accept_completion, MsgBufs, &msg_bufs, acceptCallback);

    // Enter event loop
    try loop.run(.until_done);
}

/// Once client connection is accepted, receive message and keep accepting new client connections.
fn acceptCallback(msg_bufs_opt: ?*MsgBufs, loop: *xev.Loop, completion: *xev.Completion, conn_err: xev.AcceptError!xev.TCP) xev.CallbackAction {
    const conn = conn_err catch unreachable;

    var msg_bufs = msg_bufs_opt.?;
    msg_bufs.putAssumeCapacity(conn, MsgBuf.init());

    var msg_buf = msg_bufs.getPtr(conn).?;
    var msg_slice = msg_buf.writableWithSize(config.MAX_MSG_LEN) catch unreachable;
    conn.read(loop, completion, .{ .slice = msg_slice[0..] }, MsgBufs, msg_bufs, receiveCallback);

    return .rearm;
}

/// Once message is received, broadcast message and keep receiving messages from this client connection.
fn receiveCallback(msg_bufs_opt: ?*MsgBufs, loop: *xev.Loop, completion: *xev.Completion, cur_conn: xev.TCP, read_buf: xev.ReadBuffer, msg_len_err: xev.ReadError!usize) xev.CallbackAction {
    const msg_len = msg_len_err catch unreachable;
    var conn_iter = msg_bufs_opt.?.keyIterator();

    while (conn_iter.next()) |conn| {
        if (conn.fd != cur_conn.fd) {
            conn.write(loop, completion, .{ .slice = read_buf.slice[0..msg_len] }, void, null, broadcastCallback);
        }
    }

    return .rearm;
}

/// Once message is broadcasted, there is no need to do anything else.
fn broadcastCallback(userdata: ?*void, loop: *xev.Loop, completion: *xev.Completion, conn: xev.TCP, write_buf: xev.WriteBuffer, msg_len_err: xev.WriteError!usize) xev.CallbackAction {
    _ = userdata;
    _ = loop;
    _ = completion;
    _ = conn;
    _ = write_buf;
    _ = msg_len_err catch unreachable;
    return .disarm;
}
