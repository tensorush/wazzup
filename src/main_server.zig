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

    // Define server connection
    const address = try std.net.Address.parseIp(config.HOST, config.PORT);
    var conn = try xev.TCP.init(address);

    // Listen for client connections
    try conn.bind(address);
    try conn.listen(config.MAX_NUM_CONNS_ON_SERVER);

    // Define thread pool for event loop
    var thread_pool = xev.ThreadPool.init(.{});
    defer thread_pool.deinit();
    defer thread_pool.shutdown();

    // Define event loop
    var loop = try xev.Loop.init(.{ .entries = config.MAX_NUM_CONNS_ON_SERVER, .thread_pool = &thread_pool });
    defer loop.deinit();

    // Prepare completion for accepting client connections
    var completion: xev.Completion = undefined;

    // Pre-allocate client message buffers
    var msg_bufs = MsgBufs{};
    try msg_bufs.ensureTotalCapacity(allocator, config.MAX_NUM_CONNS_ON_SERVER);
    defer msg_bufs.deinit(allocator);

    // Accept client connections
    conn.accept(&loop, &completion, MsgBufs, &msg_bufs, acceptCallback);

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
fn receiveCallback(msg_bufs_opt: ?*MsgBufs, loop: *xev.Loop, completion: *xev.Completion, conn: xev.TCP, read_buf: xev.ReadBuffer, msg_len_err: xev.ReadError!usize) xev.CallbackAction {
    const msg_len = msg_len_err catch unreachable;
    var msg_bufs = msg_bufs_opt.?;

    var conn_iter = msg_bufs.keyIterator();
    while (conn_iter.next()) |next_conn| {
        if (next_conn.fd != conn.fd) {
            next_conn.write(loop, completion, .{ .slice = read_buf.slice[0..msg_len] }, void, null, (struct {
                fn callback(_: ?*void, _: *xev.Loop, _: *xev.Completion, _: xev.TCP, _: xev.WriteBuffer, r: xev.WriteError!usize) xev.CallbackAction {
                    _ = r catch unreachable;
                    return .disarm;
                }
            }).callback);
        }
    }

    var msg_buf = msg_bufs.getPtr(conn).?;
    msg_buf.discard(msg_len);

    return .rearm;
}
