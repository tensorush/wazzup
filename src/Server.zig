const std = @import("std");
const xev = @import("xev");
const config = @import("config.zig");

const Server = @This();

const SocketSet = std.AutoHashMapUnmanaged(xev.TCP, void);
const SocketMsgBufMap = std.AutoHashMapUnmanaged(xev.TCP, MsgBuf);
const SocketCompletionMap = std.AutoHashMapUnmanaged(xev.TCP, xev.Completion);

const MsgBuf = struct {
    items: [config.MAX_NUM_MSGS][config.MAX_MSG_LEN]u8 = undefined,
    idx: usize = 0,

    pub fn next(self: *MsgBuf) []u8 {
        defer self.idx = (self.idx + 1) % config.MAX_NUM_MSGS;
        return self.items[self.idx][0..];
    }
};

socket_completion_map: SocketCompletionMap = SocketCompletionMap{},
socket_msg_buf_map: SocketMsgBufMap = SocketMsgBufMap{},

/// Initialize server.
pub fn init(allocator: std.mem.Allocator) !Server {
    var server = Server{};
    try server.socket_msg_buf_map.ensureTotalCapacity(allocator, config.MAX_NUM_SOCKETS);
    try server.socket_completion_map.ensureTotalCapacity(allocator, config.MAX_NUM_SOCKETS);
    return server;
}

/// Deinitialize server.
pub fn deinit(self: *Server, allocator: std.mem.Allocator) void {
    self.socket_msg_buf_map.deinit(allocator);
    self.socket_completion_map.deinit(allocator);
}

/// Once client connection is accepted, receive message and keep accepting new client connections.
pub fn acceptCallback(server_opt: ?*Server, loop: *xev.Loop, in_completion: *xev.Completion, socket_err: xev.AcceptError!xev.TCP) xev.CallbackAction {
    const socket = socket_err catch unreachable;

    var server = server_opt.?;
    server.socket_msg_buf_map.putAssumeCapacity(socket, MsgBuf{});
    server.socket_completion_map.putAssumeCapacity(socket, undefined);

    var msg_buf = server.socket_msg_buf_map.getPtr(socket).?;
    socket.read(loop, in_completion, .{ .slice = msg_buf.next() }, Server, server, receiveCallback);

    return .rearm;
}

/// Once message is received, broadcast message and keep receiving messages from this client connection.
fn receiveCallback(server_opt: ?*Server, loop: *xev.Loop, _: *xev.Completion, socket: xev.TCP, read_buf: xev.ReadBuffer, msg_len_err: xev.ReadError!usize) xev.CallbackAction {
    const msg_len = msg_len_err catch |err| switch (err) {
        error.EOF => return .rearm,
        else => unreachable,
    };
    var server = server_opt.?;

    var socket_iter = server.socket_msg_buf_map.keyIterator();
    var out_completion: *xev.Completion = undefined;
    while (socket_iter.next()) |next_socket| {
        if (next_socket.fd != socket.fd) {
            out_completion = server.socket_completion_map.getPtr(socket).?;
            next_socket.write(loop, out_completion, .{ .slice = read_buf.slice[0..msg_len] }, void, null, (struct {
                fn callback(_: ?*void, _: *xev.Loop, _: *xev.Completion, _: xev.TCP, _: xev.WriteBuffer, r: xev.WriteError!usize) xev.CallbackAction {
                    _ = r catch unreachable;
                    return .disarm;
                }
            }).callback);
        }
    }

    return .rearm;
}
