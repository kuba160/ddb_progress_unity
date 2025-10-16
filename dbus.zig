// SPDX-FileCopyrightText: 2025 Jakub Wasylków <kuba_160@protonmail.com>
// SPDX-License-Identifier: Zlib
const std = @import("std");
const c = @cImport({
    @cInclude("dbus/dbus.h");
});

const DBusError = extern struct {
    name: [*c]const u8,
    message: [*c]const u8,
    dummy: isize,
    padding: *opaque {},
    fn cast(self: *@This()) *c.DBusError {
        return @ptrCast(self);
    }
};

pub const dbus_error = error{
    /// Connection to specified bus failed
    ConnectionFailed,
    /// Memory allocation failed
    AllocationFailed,
    /// Sending message failed
    SendFailed,
    /// Parsing object failed
    /// (currently only returned when runtime value like OBJECT_PATH is invalid)
    ParseFailed,
};

pub const dbus_connection = struct {
    conn: *c.DBusConnection,

    pub const bus_type = enum(c_uint) {
        session = c.DBUS_BUS_SESSION,
        system = c.DBUS_BUS_SYSTEM,
        starter = c.DBUS_BUS_STARTER,
    };

    pub fn init(bus: bus_type) dbus_error!@This() {
        var err: DBusError = undefined;
        c.dbus_error_init(err.cast());
        const conn_opt = c.dbus_bus_get(@intFromEnum(bus), err.cast());
        if (c.dbus_error_is_set(err.cast()) != 0) {
            c.dbus_error_free(err.cast());
            return dbus_error.ConnectionFailed;
        }
        if (conn_opt) |conn| {
            return .{ .conn = conn };
        }
        return dbus_error.ConnectionFailed;
    }

    pub fn init_with_error(
        bus: bus_type,
        allocator: std.mem.Allocator,
        error_name: *[]const u8,
        error_message: *[]const u8,
    ) dbus_error!@This() {
        var err: DBusError = undefined;
        c.dbus_error_init(&err);
        const conn = c.dbus_bus_get(@intFromEnum(bus), &err);
        if (c.dbus_error_is_set(&err) != 0) {
            error_name = allocator.dupe(u8, err.name) catch return dbus_error.AllocationFailed;
            error_message = allocator.dupe(u8, err.message) catch return dbus_error.AllocationFailed;
            c.dbus_error_free(&err);
            return dbus_error.ConnectionFailed;
        } else if (conn == null) {
            return dbus_error.ConnectionFailed;
        }
        return .{ .conn = conn };
    }

    pub fn deinit(self: @This()) void {
        c.dbus_connection_unref(self.conn);
    }
};

pub const dbus_message = struct {
    msg: *c.DBusMessage,

    pub inline fn init_signal(path: [:0]const u8, iface: [:0]const u8, name: [:0]const u8) dbus_error!@This() {
        const msg = c.dbus_message_new_signal(path, iface, name) orelse return dbus_error.AllocationFailed;
        return .{ .msg = msg };
    }

    pub inline fn init_method_call(
        destination: [:0]const u8,
        path: [:0]const u8,
        iface: [:0]const u8,
        method: [:0]const u8,
    ) dbus_error!@This() {
        const dest = if (destination.len == 0) null else destination;
        const msg = c.dbus_message_new_method_call(dest, path, iface, method) orelse {
            return dbus_error.AllocationFailed;
        };
        return .{ .msg = msg };
    }

    pub inline fn init_method_return(method_call: @This()) dbus_error!@This() {
        const msg = c.dbus_message_new_method_return(method_call.msg) orelse {
            return dbus_error.AllocationFailed;
        };
        return .{ .msg = msg };
    }

    pub inline fn deinit(self: @This()) void {
        c.dbus_message_unref(self.msg);
    }

    pub inline fn append(self: @This(), comptime fmt: []const u8, args: anytype) dbus_error!void {
        var iter = dbus_iter.init(self);
        defer iter.deinit();
        try iter.append(fmt, args);
    }

    pub inline fn send(self: @This(), conn: dbus_connection) dbus_error!void {
        const success = c.dbus_connection_send(conn.conn, self.msg, null);
        if (success == 0) {
            return dbus_error.SendFailed;
        }
    }

    pub inline fn send_with_reply_and_block(
        self: @This(),
        conn: dbus_connection,
        reply_handler: *const fn (msg: dbus_message, reply: dbus_message) void,
        timeout_ms: c_int, // -1 for default
    ) dbus_error!void {
        var err: DBusError = undefined;
        c.dbus_error_init(err.cast());

        const msg_reply_opt = c.dbus_connection_send_with_reply_and_block(conn.conn, self.msg, timeout_ms, err.cast());
        if (msg_reply_opt) |msg_reply_c| {
            const msg_reply: @This() = .{ .msg = msg_reply_c };
            defer msg_reply.deinit();
            reply_handler(self, msg_reply);
        } else {
            // todo handle error
            c.dbus_error_free(err.cast());
            return dbus_error.SendFailed;
        }
    }
};

pub const dbus_type = enum(u8) {
    // reserved
    INVALID = 0,
    // fixed, basic
    BYTE = 'y',
    BOOLEAN = 'b',
    INT16 = 'n',
    UINT16 = 'q',
    INT32 = 'i',
    UINT32 = 'u',
    INT64 = 'x',
    UINT64 = 't',
    DOUBLE = 'd',
    // string-like, basic
    STRING = 's',
    OBJECT_PATH = 'o',
    SIGNATURE = 'g',
    // container
    ARRAY = 'a',
    STRUCT = 'r',
    STRUCT_START = '(',
    STRUCT_END = ')',
    VARIANT = 'v',
    DICT_ENTRY = 'e',
    DICT_ENTRY_START = '{',
    DICT_ENTRY_END = '}',
    // fixed, basic
    UNIX_FD = 'h',
    RESERVED_1 = 'm',
    RESERVED_2 = '*',
    RESERVED_3 = '?',
    RESERVED_4A = '@',
    RESERVED_4B = '&',
    RESERVED_4C = '^',
    // custom type that allows overriding
    CUSTOM = 'f',
    _,
};

pub const dbus_iter = struct {
    iter: c.DBusMessageIter,

    pub fn init(msg: dbus_message) @This() {
        var root: c.DBusMessageIter = undefined;
        c.dbus_message_iter_init_append(msg.msg, &root);
        return .{ .iter = root };
    }

    pub fn deinit(self: @This()) void {
        _ = self;
    }

    pub fn init_open_container(parent: *dbus_iter, c_type: dbus_type, comptime fmt: ?[]const u8) dbus_error!@This() {
        var iter: c.DBusMessageIter = undefined;

        const t = if (fmt == null) null else fmt.?[0..];
        const success = c.dbus_message_iter_open_container(&parent.iter, @intFromEnum(c_type), t, &iter);
        if (success == 0) return dbus_error.AllocationFailed;
        return .{ .iter = iter };
    }

    pub fn deinit_container(self: *@This(), parent: *dbus_iter) void {
        _ = c.dbus_message_iter_close_container(&parent.iter, &self.iter);
    }
    pub inline fn is_valid_object_path(path: []const u8) bool {
        if (path.len == 0) return false;
        if (path[0] != '/') return false;
        if (path.len != 1 and path[path.len - 1] == '/') return false;
        for (path) |char| {
            switch (char) {
                'A'...'Z', 'a'...'z', '0'...'9', '_', '/' => {},
                else => return false,
            }
        }
        if (std.mem.indexOfPos(u8, path, 0, "//")) |_| return false;
        return true;
    }

    pub inline fn tokenize(comptime fmt: []const u8) []const u8 {
        if (fmt.len == 0) @compileError("cannot tokenize empty format");
        return switch (@as(dbus_type, @enumFromInt(fmt[0]))) {
            .BYTE,
            .BOOLEAN,
            .INT16,
            .UINT16,
            .INT32,
            .UINT32,
            .INT64,
            .UINT64,
            .DOUBLE,
            .STRING,
            .OBJECT_PATH,
            .SIGNATURE,
            .STRUCT,
            .DICT_ENTRY,
            .VARIANT,
            .CUSTOM,
            => fmt[0..1],
            .ARRAY => { // include next token which can be a container
                return fmt[0 .. 1 + tokenize(fmt[1..]).len];
            },
            .STRUCT_START, .DICT_ENTRY_START => |start| {
                const sentinel = if (start == .STRUCT_START) .STRUCT_END else .DICT_ENTRY_END;
                // todo support nested values
                inline for (1..fmt.len) |i| {
                    const token = comptime @as(dbus_type, @enumFromInt(fmt[i]));
                    if (token == sentinel) {
                        return fmt[0 .. i + 1];
                    }
                }
                const err_msg = "token " ++ @tagName(sentinel) ++ " missing";
                @compileError(err_msg);
            },
            .STRUCT_END => @compileError("found \')\' before \'(\'"),
            .DICT_ENTRY_END => @compileError("found \'}\' before \'{\'"),
            .INVALID, .RESERVED_1, .RESERVED_2, .RESERVED_3, .RESERVED_4A, .RESERVED_4B, .RESERVED_4C => {
                @compileError("illegal type");
            },
            else => @compileError("TODO"),
        };
    }

    pub inline fn append(self: *@This(), comptime fmt: []const u8, args: anytype) dbus_error!void {
        comptime var arg_idx = 0;
        comptime var offset = 0;
        inline while (offset < fmt.len) {
            if (args.len <= arg_idx) {
                @compileError("fmt provides more types than args");
            }
            const tok = tokenize(fmt[offset..]);
            switch (@as(dbus_type, @enumFromInt(tok[0]))) {
                .BYTE,
                .BOOLEAN,
                .INT16,
                .UINT16,
                .INT32,
                .UINT32,
                .INT64,
                .UINT64,
                .DOUBLE,
                .STRING,
                .OBJECT_PATH,
                => try self.append_basic(tok, args[arg_idx]),
                .SIGNATURE => @compileError("signature currently not supported"),
                .VARIANT => try self.append_variant(args[arg_idx]),
                .ARRAY => {
                    // can be basic or container type like struct/array/dict entry
                    const tok_type = tok[1..];
                    try self.append_array(tok_type, args[arg_idx]);
                },
                .STRUCT_START => try self.append_struct(tok[1 .. tok.len - 1], args[arg_idx]),
                .DICT_ENTRY_START => try self.append_dict_entry(tok[1 .. tok.len - 1], args[arg_idx]),
                .CUSTOM => try args[arg_idx].dbus_append(self),
                .INVALID, .RESERVED_1, .RESERVED_2, .RESERVED_3, .RESERVED_4A, .RESERVED_4B, .RESERVED_4C => {
                    @compileError("illegal type");
                },
                else => @compileError("unknown fmt type"),
            }
            arg_idx += 1;
            offset += tok.len;
        }

        if (arg_idx != args.len) {
            @compileLog(args.len, arg_idx);
            @compileError("fmt does not handle all passed args");
        }
    }

    pub inline fn append_variant(self: *@This(), args: anytype) dbus_error!void {
        if (args.len != 2) {
            @compileError("variant requires passing fmt and object in a tuple");
        }
        const fmt, const arg = .{ args[0], args[1] };
        var iter = try dbus_iter.init_open_container(self, .VARIANT, fmt[0..]);
        defer iter.deinit_container(self);
        try iter.append(fmt, .{arg});
    }

    pub inline fn append_array(self: *@This(), comptime fmt: []const u8, args: anytype) dbus_error!void {
        var iter = try dbus_iter.init_open_container(self, .ARRAY, fmt[0..]);
        defer iter.deinit_container(self);
        try append(&iter, fmt[0..] ** args.len, args);
    }

    pub inline fn append_struct(self: *@This(), comptime fmt: []const u8, args: anytype) dbus_error!void {
        var iter = try dbus_iter.init_open_container(self, .STRUCT, null);
        defer iter.deinit_container(self);
        try append(&iter, fmt[0..], args);
    }

    pub inline fn append_dict_entry(self: *@This(), comptime fmt: []const u8, args: anytype) dbus_error!void {
        var iter = try dbus_iter.init_open_container(self, .DICT_ENTRY, null);
        defer iter.deinit_container(self);

        if (args.len != 2) {
            @compileError("dict entry requires 2 elements");
        }
        switch (@as(dbus_type, @enumFromInt(fmt[0]))) {
            .BYTE, .BOOLEAN, .INT16, .UINT16, .INT32, .UINT32, .INT64, .UINT64, .DOUBLE => {},
            .STRING, .OBJECT_PATH, .SIGNATURE => {},
            else => @compileError("first field has to be a basic type"),
        }
        try append(&iter, fmt[0..], args);
    }

    pub inline fn append_basic(self: *dbus_iter, comptime fmt: []const u8, arg: anytype) dbus_error!void {
        if (fmt.len != 1) {
            @compileError("append_basic can only accept 1 arg");
        }
        const f = struct {
            inline fn append_basic(r: *c.DBusMessageIter, val_type: dbus_type, arg_append: anytype) dbus_error!void {
                const success = c.dbus_message_iter_append_basic(r, @intFromEnum(val_type), @ptrCast(arg_append));
                if (success == 0) {
                    return dbus_error.AllocationFailed;
                }
            }
        };

        const root = &self.iter;
        switch (@as(dbus_type, @enumFromInt(fmt[0]))) {
            .BYTE => try f.append_basic(root, .BYTE, &@as(u8, arg)),
            .BOOLEAN => try f.append_basic(root, .BOOLEAN, &@as(i32, @intFromBool(arg))),
            .INT16 => try f.append_basic(root, .INT16, &@as(i16, arg)),
            .UINT16 => try f.append_basic(root, .UINT16, &@as(u16, arg)),
            .INT32 => try f.append_basic(root, .INT32, &@as(i32, arg)),
            .UINT32 => try f.append_basic(root, .UINT32, &@as(u32, arg)),
            .INT64 => try f.append_basic(root, .INT64, &@as(i64, arg)),
            .UINT64 => try f.append_basic(root, .UINT64, &@as(u64, arg)),
            .DOUBLE => try f.append_basic(root, .DOUBLE, &@as(f64, arg)),
            .STRING => try f.append_basic(root, .STRING, &@as([]const u8, arg)),
            .OBJECT_PATH => if (is_valid_object_path(arg)) {
                try f.append_basic(root, .OBJECT_PATH, &@as([]const u8, arg));
            } else {
                return dbus_error.ParseFailed;
            },
            else => unreachable, // called from append, type is guaranteed to be one of above
        }
    }
};
