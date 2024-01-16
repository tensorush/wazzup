pub const PORT = 1337;
pub const HOST = "127.0.0.1";
pub const MAX_MSG_LEN = 1 << 8;
pub const MAX_NUM_CONNS_ON_CLIENT = 1 << 1;
pub const MAX_NUM_CONNS_ON_SERVER = 1 << 7;
pub const MAX_MSG_BUF_SIZE = (1 << 2) * MAX_MSG_LEN;
