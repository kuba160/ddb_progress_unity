// SPDX-FileCopyrightText: 2025 Jakub Wasylków <kuba_160@protonmail.com>
// SPDX-License-Identifier: Zlib
const std = @import("std");
const zd = @import("dbus.zig");

const sig = .{
    .path = "/test/signal/Object",
    .iface = "test.signal.Type",
    .name = "Signal",
};

const met = .{
    .dest = "",
    .path = "/",
    .iface = "org.freedesktop.DBus.Peer",
    .method = "Ping",
};

test "session bus connection test" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
}

test "system bus connection test" {
    const conn = try zd.dbus_connection.init(.system);
    defer conn.deinit();
}

test "starter bus connection test" {
    const conn = try zd.dbus_connection.init(.starter);
    defer conn.deinit();
}

test "method call test" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_method_call(met.dest, met.path, met.iface, "InvalidMethod");
        try msg.append("s", .{
            "method_test",
        });
        try msg.send(conn);
    }
}

test "valid int msg signal" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("ybnqiuxt", .{
            255,
            true,
            -255,
            255,
            -255,
            255,
            -255,
            255,
        });
        try msg.send(conn);
    }
}

test "simple variant msg signal" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("v", .{
            .{ "y", 255 },
        });
        try msg.send(conn);
    }
}

test "simple type msg signal" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("u", .{
            23,
        });
        try msg.append("u", .{
            24,
        });
        try msg.send(conn);
    }
}

test "nested array msg signal" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("aau", .{
            .{
                .{ 1, 2, 3 },
                .{ 4, 5, 6 },
            },
        });
        try msg.send(conn);
    }
}

test "basic types msg signal" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("ybnqiuxtds", .{
            255,
            true,
            -255,
            255,
            -255,
            255,
            -255,
            255,
            1.0,
            "test",
        });
        try msg.send(conn);
    }
}

test "variant msg" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("v", .{
            .{ "u", 32 },
        });
        try msg.send(conn);
    }
}

test "double sequential array msg" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("asau", .{
            .{ "1", "2" },
            .{ 1, 2 },
        });
        try msg.send(conn);
    }
}

test "array in variant msg" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("v", .{
            .{ "as", .{ "one", "two" } },
        });
        try msg.send(conn);
    }
}

test "array of variants msg" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("av", .{
            .{
                .{ "as", .{ "one", "two" } },
                .{ "u", 32 },
            },
        });
        try msg.send(conn);
    }
}

test "struct msg" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("(sub)", .{
            .{
                "one",
                256,
                true,
            },
        });
        try msg.send(conn);
    }
}

test "dict msg" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("a{sv}", .{
            .{
                .{ "key", .{ "s", "value" } },
                .{ "has_key", .{ "b", true } },
            },
        });
        try msg.send(conn);
    }
}

test "object msg" {
    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("ao", .{
            .{
                "/",
                sig.path,
            },
        });
        try msg.send(conn);
    }
}

test "custom object msg" {
    const timestamp = struct {
        epoch: i64,
        pub fn current() @This() {
            return .{ .epoch = std.time.timestamp() };
        }
        pub fn dbus_append(self: @This(), iter: *zd.dbus_iter) zd.dbus_error!void {
            try iter.append("x", .{self.epoch});
        }
    };

    const conn = try zd.dbus_connection.init(.session);
    defer conn.deinit();
    {
        const msg = try zd.dbus_message.init_signal(sig.path, sig.iface, sig.name);
        try msg.append("f", .{
            timestamp.current(),
        });
        try msg.send(conn);
    }
}

// monitor: dbus-monitor --session path='/test/signal/Object'
