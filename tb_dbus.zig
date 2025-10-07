// SPDX-FileCopyrightText: 2025 Jakub Wasylków <kuba_160@protonmail.com>
// SPDX-License-Identifier: Zlib
const std = @import("std");
const dbus = @import("dbus.zig");

const signal = dbus.signal{
    .path = "/test/signal/Object",
    .iface = "test.signal.Type",
    .name = "Signal",
};

test "session bus connection test" {
    const conn = try dbus.bus_get(dbus.bus_type.session);
    defer dbus.bus_unref(conn);
}

test "system bus connection test" {
    const conn = try dbus.bus_get(dbus.bus_type.system);
    defer dbus.bus_unref(conn);
}

test "starter bus connection test" {
    const conn = try dbus.bus_get(dbus.bus_type.starter);
    defer dbus.bus_unref(conn);
}

test "simple signal test" {
    const conn = try dbus.bus_get(.starter);
    defer dbus.bus_unref(conn);

    try dbus.send_signal(conn, signal, .{
        @as(u32, 1337),
    });
}

test "type signal test" {
    const conn = try dbus.bus_get(.starter);
    defer dbus.bus_unref(conn);

    try dbus.send_signal(conn, signal, .{
        @as(u8, 255),
        @as(u16, 1337),
        @as(u32, 1337),
        @as(u64, 1337),
        @as(i16, -1337),
        @as(i32, -1337),
        @as(i64, -1337),
        @as(f64, 1.337),
        @as(bool, false),
        @as(bool, true),
    });
}

test "array signal test" {
    const conn = try dbus.bus_get(.starter);
    defer dbus.bus_unref(conn);

    try dbus.send_signal(conn, signal, .{
        [_]u8{ 1, 2, 3, 4 },
        [_]u16{ 1, 2, 3, 4 },
        [_]u32{ 1, 2, 3, 4 },
        [_]u64{ 1, 2, 3, 4 },
        [_]i16{ 1, 2, 3, 4 },
        [_]i32{ 1, 2, 3, 4 },
        [_]i64{ 1, 2, 3, 4 },
        [_]f64{ 0.1, 0.2, 0.3, 0.4 },
        [_]bool{ false, true },
    });
}

test "sv map test" {
    const conn = try dbus.bus_get(.starter);
    defer dbus.bus_unref(conn);

    try dbus.send_signal(conn, signal, .{.{
        .n0 = @as(u8, 255),
        .n1 = @as(u16, 1337),
        .n2 = @as(u32, 1337),
        .n3 = @as(u64, 1337),
        .n4 = @as(i16, -1337),
        .n5 = @as(i32, -1337),
        .n6 = @as(i64, -1337),
        .n7 = @as(f64, 1.337),
        .n8 = @as(bool, false),
        .n9 = @as(bool, true),
    }});
}
