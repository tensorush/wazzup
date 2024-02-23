const std = @import("std");

pub const MAX_MSG_LEN: usize = 1 << 8;
pub const MAX_NUM_MSGS: usize = 1 << 2;
pub const MAX_NUM_SOCKETS: usize = 1 << 7;
pub const IP_ADDRESS = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 1337);
