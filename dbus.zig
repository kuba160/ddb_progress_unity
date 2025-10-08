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
};

pub const bus_type = enum(c_uint) {
    session = c.DBUS_BUS_SESSION,
    system = c.DBUS_BUS_SYSTEM,
    starter = c.DBUS_BUS_STARTER,
};

pub const dbus_connection = *c.DBusConnection;

var err_obj: DBusError = undefined;

pub const dbus_error = error{
    ConnectionFailed,
    AllocationFailed,
    SendFailed,
};

pub fn bus_get(t: bus_type) dbus_error!dbus_connection {
    c.dbus_error_init(@ptrCast(&err_obj));
    const connection: *c.DBusConnection = c.dbus_bus_get(@intFromEnum(t), @ptrCast(&err_obj)) orelse undefined;
    if (c.dbus_error_is_set(@ptrCast(&err_obj)) != 0) {
        return dbus_error.ConnectionFailed;
    }
    error_free();
    return connection;
}

pub fn bus_unref(connection: dbus_connection) void {
    c.dbus_connection_unref(connection);
}

pub fn error_free() void {
    c.dbus_error_free(@ptrCast(&err_obj));
}

pub fn error_get_name() [*c]const u8 {
    return err_obj.name;
}

pub fn error_get_msg() [*c]const u8 {
    return err_obj.message;
}

pub const method_call = struct {
    destination: ?[*:0]const u8,
    path: [*:0]const u8,
    iface: [*:0]const u8,
    method: [*:0]const u8,
};

pub const signal = struct {
    path: [*:0]const u8,
    iface: [*:0]const u8,
    name: [*:0]const u8,
};

pub inline fn send_signal(conn: dbus_connection, m: signal, args: anytype) dbus_error!void {
    const msg = c.dbus_message_new_signal(m.path, m.iface, m.name) orelse return dbus_error.AllocationFailed;
    defer c.dbus_message_unref(msg);

    var root_raw: c.DBusMessageIter = undefined;
    const root = &root_raw;
    c.dbus_message_iter_init_append(msg, root);

    try msg_send_iter(root, args);

    const success = c.dbus_connection_send(conn, msg, null);
    if (success == 0) {
        return dbus_error.SendFailed;
    }
}
pub inline fn msg_send(conn: dbus_connection, m: method_call, args: anytype) dbus_error!void {
    const msg = c.dbus_message_new_method_call(m.destination, m.path, m.iface, m.method) orelse return dbus_error.AllocationFailed;
    defer c.dbus_message_unref(msg);

    var root: c.DBusMessageIter = undefined;
    c.dbus_message_iter_init_append(msg, &root);
    try msg_send_iter(&root, args);

    const success = c.dbus_connection_send(conn, msg, null);
    if (success == 0) {
        return dbus_error.SendFailed;
    }
}

inline fn msg_send_basic(root: *c.DBusMessageIter, val_type: c_int, arg: anytype) dbus_error!void {
    const success = c.dbus_message_iter_append_basic(root, val_type, @ptrCast(arg));
    if (success == 0) {
        return dbus_error.AllocationFailed;
    }
}

inline fn int_to_dbus_type(sign: std.builtin.Signedness, bits: comptime_int) c_int {
    switch (sign) {
        .unsigned => {
            switch (bits) {
                8 => return c.DBUS_TYPE_BYTE,
                16 => return c.DBUS_TYPE_UINT16,
                32 => return c.DBUS_TYPE_UINT32,
                64 => return c.DBUS_TYPE_UINT64,
                else => @compileError("undefined"),
            }
        },
        .signed => {
            switch (bits) {
                16 => return c.DBUS_TYPE_INT16,
                32 => return c.DBUS_TYPE_INT32,
                64 => return c.DBUS_TYPE_INT64,
                else => @compileError("undefined"),
            }
        },
    }
    return 0;
}
inline fn int_to_dbus_type_string(sign: std.builtin.Signedness, bits: comptime_int) [*]const u8 {
    switch (sign) {
        .unsigned => {
            switch (bits) {
                8 => return c.DBUS_TYPE_BYTE_AS_STRING,
                16 => return c.DBUS_TYPE_UINT16_AS_STRING,
                32 => return c.DBUS_TYPE_UINT32_AS_STRING,
                64 => return c.DBUS_TYPE_UINT64_AS_STRING,
                else => @compileError("undefined"),
            }
        },
        .signed => {
            switch (bits) {
                16 => return c.DBUS_TYPE_INT16_AS_STRING,
                32 => return c.DBUS_TYPE_INT32_AS_STRING,
                64 => return c.DBUS_TYPE_INT64_AS_STRING,
                else => @compileError("undefined"),
            }
        },
    }
    return 0;
}

inline fn type_to_dbus_type_string(i: type) [*]const u8 {
    switch (@typeInfo(i)) {
        .pointer => return c.DBUS_TYPE_STRING_AS_STRING,
        .bool => return c.DBUS_TYPE_BOOLEAN_AS_STRING,
        .int => |t| return int_to_dbus_type_string(t.signedness, t.bits),
        .float => |t| {
            if (t.bits == 64) {
                return c.DBUS_TYPE_DOUBLE_AS_STRING;
            } else {
                @compileError("only f64 supported");
            }
        },
        .array => return c.DBUS_TYPE_ARRAY_AS_STRING,
        .@"struct" => {
            @compileError("nesting currently not supported");
        },
        .comptime_int => @compileError("int value needs casting"),
        .comptime_float => @compileError("float value needs casting to f64"),
        else => @compileLog("type_to_dbus_type_string: unsupported"),
    }
    @compileError("type_to_dbus_type_string error");
}

inline fn msg_send_iter(root: *c.DBusMessageIter, args: anytype) dbus_error!void {
    switch (@typeInfo(@TypeOf(args))) {
        .@"struct" => |struct_type| {
            if (struct_type.is_tuple) {
                inline for (args) |it| {
                    switch (@typeInfo(@TypeOf(it))) {
                        .pointer => try msg_send_basic(root, c.DBUS_TYPE_STRING, &it),
                        .bool => try msg_send_basic(root, c.DBUS_TYPE_BOOLEAN, &@as(i32, @intFromBool(it))),
                        .int => |t| try msg_send_basic(root, int_to_dbus_type(t.signedness, t.bits), &it),
                        .float => |t| {
                            if (t.bits == 64) {
                                try msg_send_basic(root, c.DBUS_TYPE_DOUBLE, &it);
                            } else {
                                @compileError("only f64 supported");
                            }
                        },
                        .array => |t| {
                            var arr: c.DBusMessageIter = undefined;
                            const success = c.dbus_message_iter_open_container(
                                root,
                                c.DBUS_TYPE_ARRAY,
                                type_to_dbus_type_string(t.child),
                                &arr,
                            );
                            if (success == 0)
                                return dbus_error.AllocationFailed;
                            defer _ = c.dbus_message_iter_close_container(root, &arr);

                            for (it) |children| {
                                try msg_send_iter2(&arr, .{children});
                            }
                        },
                        .@"struct" => |t| {
                            if (t.is_tuple) {
                                @compileError("tuple type not supported");
                            } else {
                                var arr: c.DBusMessageIter = undefined;
                                var success = c.dbus_message_iter_open_container(
                                    root,
                                    c.DBUS_TYPE_ARRAY,
                                    "{sv}",
                                    &arr,
                                );
                                if (success == 0)
                                    return dbus_error.AllocationFailed;
                                defer _ = c.dbus_message_iter_close_container(root, &arr);
                                inline for (t.fields) |f| {
                                    var entry: c.DBusMessageIter = undefined;
                                    success = c.dbus_message_iter_open_container(&arr, c.DBUS_TYPE_DICT_ENTRY, null, &entry);
                                    if (success == 0)
                                        return dbus_error.AllocationFailed;
                                    defer _ = c.dbus_message_iter_close_container(&arr, &entry);
                                    //@compileLog(f.name);
                                    try msg_send_iter2(&entry, .{f.name});

                                    var variant: c.DBusMessageIter = undefined;
                                    success = c.dbus_message_iter_open_container(&entry, c.DBUS_TYPE_VARIANT, type_to_dbus_type_string(f.type), &variant);
                                    if (success == 0)
                                        return dbus_error.AllocationFailed;
                                    defer _ = c.dbus_message_iter_close_container(&entry, &variant);
                                    try msg_send_iter2(&variant, .{@field(it, f.name)});
                                }
                            }
                        },
                        .comptime_int => @compileError("int value needs casting"),
                        .comptime_float => @compileError("float value needs casting to f64"),
                        else => @compileError("type unsupported"),
                    }
                }
            }
        },
        else => @compileError("args is not a struct tuple"),
    }
}

inline fn msg_send_iter2(root: *c.DBusMessageIter, args: anytype) dbus_error!void {
    switch (@typeInfo(@TypeOf(args))) {
        .@"struct" => |struct_type| {
            if (struct_type.is_tuple) {
                inline for (args) |it| {
                    switch (@typeInfo(@TypeOf(it))) {
                        .pointer => try msg_send_basic(root, c.DBUS_TYPE_STRING, &it),
                        .bool => try msg_send_basic(root, c.DBUS_TYPE_BOOLEAN, &@as(i32, @intFromBool(it))),
                        .int => |t| try msg_send_basic(root, int_to_dbus_type(t.signedness, t.bits), &it),
                        .float => |t| {
                            if (t.bits == 64) {
                                try msg_send_basic(root, c.DBUS_TYPE_DOUBLE, &it);
                            } else {
                                @compileError("only f64 supported");
                            }
                        },
                        .array => |t| {
                            var arr: c.DBusMessageIter = undefined;
                            const success = c.dbus_message_iter_open_container(
                                root,
                                c.DBUS_TYPE_ARRAY,
                                type_to_dbus_type_string(t.child),
                                &arr,
                            );
                            if (success == 0)
                                return dbus_error.AllocationFailed;
                            defer _ = c.dbus_message_iter_close_container(root, &arr);

                            for (it) |children| {
                                try msg_send_iter(&arr, .{children});
                            }
                        },
                        .@"struct" => |t| {
                            if (t.is_tuple) {
                                @compileError("tuple type not supported");
                            } else {
                                var arr: c.DBusMessageIter = undefined;
                                var success = c.dbus_message_iter_open_container(
                                    root,
                                    c.DBUS_TYPE_ARRAY,
                                    "{sv}",
                                    &arr,
                                );
                                if (success == 0)
                                    return dbus_error.AllocationFailed;
                                defer _ = c.dbus_message_iter_close_container(root, &arr);
                                inline for (t.fields) |f| {
                                    var entry: c.DBusMessageIter = undefined;
                                    success = c.dbus_message_iter_open_container(&arr, c.DBUS_TYPE_DICT_ENTRY, null, &entry);
                                    if (success == 0)
                                        return dbus_error.AllocationFailed;
                                    defer _ = c.dbus_message_iter_close_container(&arr, &entry);
                                    //@compileLog(f.name);
                                    try msg_send_iter(&entry, .{f.name});

                                    var variant: c.DBusMessageIter = undefined;
                                    success = c.dbus_message_iter_open_container(&entry, c.DBUS_TYPE_VARIANT, type_to_dbus_type_string(f.type), &variant);
                                    if (success == 0)
                                        return dbus_error.AllocationFailed;
                                    defer _ = c.dbus_message_iter_close_container(&entry, &variant);
                                    try msg_send_iter(&variant, .{@field(it, f.name)});
                                }
                            }
                        },
                        .comptime_int => @compileError("int value needs casting"),
                        .comptime_float => @compileError("float value needs casting to f64"),
                        else => @compileError("type unsupported"),
                    }
                }
            }
        },
        else => @compileError("args is not a struct tuple"),
    }
}
