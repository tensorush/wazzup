const xev = @import("xev");
const config = @import("config.zig");

const Client = @This();

out_msg_buf: [config.MAX_MSG_LEN]u8 = undefined,
in_msg_buf: [config.MAX_MSG_LEN]u8 = undefined,
out_completion: xev.Completion = undefined,
socket: xev.TCP = undefined,
reader: xev.File,
writer: xev.File,

/// Once connected to server, start scanning client input and receiving messages from server.
pub fn connectCallback(client_opt: ?*Client, loop: *xev.Loop, in_completion: *xev.Completion, socket: xev.TCP, err: xev.ConnectError!void) xev.CallbackAction {
    _ = err catch unreachable;
    var client = client_opt.?;
    client.socket = socket;

    client.reader.read(loop, in_completion, .{ .slice = client.in_msg_buf[0..] }, Client, client, scanCallback);
    socket.read(loop, &client.out_completion, .{ .slice = client.out_msg_buf[0..] }, Client, client, receiveCallback);

    return .disarm;
}

/// Once client input is scanned, send message to server and keep scanning client input.
fn scanCallback(client_opt: ?*Client, loop: *xev.Loop, in_completion: *xev.Completion, _: xev.File, read_buf: xev.ReadBuffer, msg_len_err: xev.ReadError!usize) xev.CallbackAction {
    const msg_len = msg_len_err catch unreachable;
    var client = client_opt.?;

    client.socket.write(loop, in_completion, .{ .slice = read_buf.slice[0..msg_len] }, void, null, (struct {
        fn callback(_: ?*void, _: *xev.Loop, _: *xev.Completion, _: xev.TCP, _: xev.WriteBuffer, r: xev.WriteError!usize) xev.CallbackAction {
            _ = r catch unreachable;
            return .disarm;
        }
    }).callback);

    return .rearm;
}

/// Once message is received from server, print message to client output and keep receiving messages from server.
fn receiveCallback(client_opt: ?*Client, loop: *xev.Loop, out_completion: *xev.Completion, _: xev.TCP, read_buf: xev.ReadBuffer, msg_len_err: xev.ReadError!usize) xev.CallbackAction {
    const msg_len = msg_len_err catch unreachable;
    var client = client_opt.?;

    client.writer.write(loop, out_completion, .{ .slice = read_buf.slice[0..msg_len] }, void, null, (struct {
        fn callback(_: ?*void, _: *xev.Loop, _: *xev.Completion, _: xev.File, _: xev.WriteBuffer, r: xev.WriteError!usize) xev.CallbackAction {
            _ = r catch unreachable;
            return .disarm;
        }
    }).callback);

    return .rearm;
}
