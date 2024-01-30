const std = @import("std");
const xev = @import("xev");
const config = @import("config.zig");

const Client = struct {
    in_msg_buf: [config.MAX_MSG_LEN]u8 = undefined,
    out_msg_buf: [config.MAX_MSG_LEN]u8 = undefined,
    in_msg_len: usize = undefined,
    out_msg_len: usize = undefined,
    reader: xev.File,
    writer: xev.File,
    conn: *xev.TCP,
};

pub fn main() !void {
    // Define synchronous client IO interface
    const in = std.io.getStdIn();
    const out = std.io.getStdOut();

    // Prompt client for name
    try out.writer().print("Please enter your name not longer than {d} bytes:\n", .{config.MAX_MSG_LEN});

    // Define client connection
    const address = try std.net.Address.parseIp(config.HOST, config.PORT);
    var conn = try xev.TCP.init(address);

    // Define asynchronous client IO interface
    var client = Client{ .reader = try xev.File.init(in), .writer = try xev.File.init(out), .conn = &conn };

    // Define thread pool for event loop
    var thread_pool = xev.ThreadPool.init(.{});
    defer thread_pool.deinit();
    defer thread_pool.shutdown();

    // Define event loop
    var loop = try xev.Loop.init(.{ .entries = config.MAX_NUM_CONNS_ON_CLIENT, .thread_pool = &thread_pool });
    defer loop.deinit();

    // Prepare completion for connecting to server
    var completion: xev.Completion = undefined;

    // Connect to server
    conn.connect(&loop, &completion, address, Client, &client, connectCallback);

    // Enter event loop
    try loop.run(.until_done);
}

/// Once connected to server, start scanning client input and receiving messages from server.
fn connectCallback(client_opt: ?*Client, loop: *xev.Loop, completion: *xev.Completion, conn: xev.TCP, err: xev.ConnectError!void) xev.CallbackAction {
    _ = err catch unreachable;
    var client = client_opt.?;

    client.reader.read(loop, completion, .{ .slice = client.in_msg_buf[0..] }, Client, client, scanCallback);
    conn.read(loop, completion, .{ .slice = client.out_msg_buf[0..] }, Client, client, receiveCallback);

    return .disarm;
}

/// Once client input is scanned, send message to server and keep scanning client input.
fn scanCallback(client_opt: ?*Client, loop: *xev.Loop, completion: *xev.Completion, _: xev.File, read_buf: xev.ReadBuffer, msg_len_err: xev.ReadError!usize) xev.CallbackAction {
    const msg_len = msg_len_err catch unreachable;
    var client = client_opt.?;

    client.conn.write(loop, completion, .{ .slice = read_buf.slice[0..msg_len] }, void, null, (struct {
        fn callback(_: ?*void, _: *xev.Loop, _: *xev.Completion, _: xev.TCP, _: xev.WriteBuffer, r: xev.WriteError!usize) xev.CallbackAction {
            _ = r catch unreachable;
            return .disarm;
        }
    }).callback);

    return .rearm;
}

/// Once message is received from server, print message to client output and keep receiving messages from server.
fn receiveCallback(client_opt: ?*Client, loop: *xev.Loop, completion: *xev.Completion, _: xev.TCP, read_buf: xev.ReadBuffer, msg_len_err: xev.ReadError!usize) xev.CallbackAction {
    const msg_len = msg_len_err catch unreachable;
    var client = client_opt.?;

    client.writer.write(loop, completion, .{ .slice = read_buf.slice[0..msg_len] }, void, null, (struct {
        fn callback(_: ?*void, _: *xev.Loop, _: *xev.Completion, _: xev.File, _: xev.WriteBuffer, r: xev.WriteError!usize) xev.CallbackAction {
            _ = r catch unreachable;
            return .disarm;
        }
    }).callback);

    return .rearm;
}
