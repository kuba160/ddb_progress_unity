// SPDX-FileCopyrightText: 2025 Jakub Wasylków <kuba_160@protonmail.com>
//
// SPDX-License-Identifier: Zlib
const std = @import("std");
const c = @cImport({
    @cInclude("deadbeef/deadbeef.h");
});
const dbus = @import("dbus.zig");

const E_BUS_NAME = "/org/DeaDBeeF/deadbeef";
const E_INTERFACE = "com.canonical.Unity.LauncherEntry";
const E_NAME = "Update";
const E_APP = "deadbeef.desktop";

var deadbeef: *c.DB_functions_t = undefined;
var conn: dbus.dbus_connection = undefined;
var tid: isize = undefined;
var shutdown = false;

fn update_status(progress: f64, queue_size: c_int) void {
    const m = dbus.signal{
        .path = E_BUS_NAME,
        .iface = E_INTERFACE,
        .name = E_NAME,
    };

    const progress_visible = if (progress != 0.0) true else false;
    const count_visible = if (queue_size > 0) true else false;

    dbus.send_signal(conn, m, .{
        E_APP,
        .{
            .@"progress-visible" = progress_visible,
            .progress = progress,
            .count = @as(i64, queue_size),
            .@"count-visible" = count_visible,
        },
    }) catch {
        deadbeef.log.?("progress_unity: dbus message send failed: %s\n", dbus.error_get_msg());
    };
}

pub fn thread_loop(userdata: ?*anyopaque) callconv(.c) void {
    _ = userdata;
    const vars = struct {
        progress: f64 = 0.0,
        queue_size: c_int = 0,
    };
    var prev = vars{};
    while (true) {
        if (shutdown) {
            break;
        }
        const curr = vars{
            .progress = deadbeef.playback_get_pos.?() / 100.0,
            .queue_size = deadbeef.playqueue_get_count.?(),
        };
        if (!std.meta.eql(prev, curr)) {
            update_status(curr.progress, curr.queue_size);
            prev = curr;
        }
        std.Thread.sleep(1_000_000_000);
    }
}

fn plug_start() callconv(.c) c_int {
    conn = dbus.bus_get(.session) catch {
        deadbeef.log.?("progress_unity: dbus connection failed: %s\n", dbus.error_get_msg());
        return 1;
    };
    tid = deadbeef.thread_start.?(thread_loop, null);
    return 0;
}

fn plug_stop() callconv(.c) c_int {
    shutdown = true;
    dbus.bus_unref(conn);
    //_ = deadbeef.thread_join.?(tid);
    return 0;
}

fn plug_message(id: u32, ctx: usize, p1: u32, p2: u32) callconv(.c) c_int {
    _ = .{ ctx, p2 };

    switch (id) {
        c.DB_EV_SEEK => {
            const get_position_max = struct {
                inline fn f() f64 {
                    const it = deadbeef.streamer_get_playing_track.?() orelse return 0.0;
                    const len: f64 = deadbeef.pl_get_item_duration.?(it);
                    deadbeef.pl_item_unref.?(it);
                    return len;
                }
            };
            const curr = .{
                .progress = (@as(f64, @floatFromInt(p1)) / 1000.0) / get_position_max.f(),
                .queue_size = deadbeef.playqueue_get_count.?(),
            };
            update_status(curr.progress, curr.queue_size);
        },
        c.DB_EV_NEXT,
        c.DB_EV_PREV,
        c.DB_EV_PLAY_CURRENT,
        c.DB_EV_PLAY_NUM,
        c.DB_EV_STOP,
        c.DB_EV_PAUSE,
        c.DB_EV_PLAY_RANDOM,
        => {
            const curr = .{
                .progress = 0.0,
                .queue_size = deadbeef.playqueue_get_count.?(),
            };
            update_status(curr.progress, curr.queue_size);
        },
        c.DB_EV_TRACKINFOCHANGED, c.DB_EV_PLAYLISTCHANGED => {
            if (p1 == c.DDB_PLAYLIST_CHANGE_PLAYQUEUE) {
                const curr = .{
                    .progress = deadbeef.playback_get_pos.?() / 100.0,
                    .queue_size = deadbeef.playqueue_get_count.?(),
                };
                update_status(curr.progress, curr.queue_size);
            }
        },
        else => {},
    }
    return 0;
}

var plugin: c.DB_misc_t = c.DB_misc_t{
    .plugin = c.DB_plugin_t{
        .api_vmajor = 1,
        .api_vminor = 10,
        .version_major = 0,
        .version_minor = 1,
        .type = c.DB_PLUGIN_MISC,
        .id = "progress_unity",
        .name = "Progressbar in taskbar (Unity.LauncherEntry)",
        .descr = "Shows current progress in taskbar using com.canonical.Unity.LauncherEntry DBus interface",
        .copyright = "Copyright (C) 2025 Jakub Wasylków\n\n" ++ @embedFile("./LICENSES/Zlib.txt"),
        .website = "https://github.com/kuba160/ddb_progress_unity",
        .start = plug_start,
        .stop = plug_stop,
        .message = plug_message,
    },
};

export fn progress_unity_load(f: *c.DB_functions_t) callconv(.c) *c.DB_plugin_t {
    deadbeef = f;
    return @ptrCast(&plugin);
}
