// SPDX-FileCopyrightText: 2025 Jakub Wasylków <kuba_160@protonmail.com>
// SPDX-License-Identifier: CC0-1.0
const std = @import("std");

pub fn build(b: *std.Build) void {
    const preferred_link_mode = b.option(std.builtin.LinkMode, "preferred_link_mode", "Preferred link mode (default: dynamic)") orelse .dynamic;
    const link_libc = b.option(bool, "link_libc", "link libc") orelse true;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const module = b.createModule(.{
        .root_source_file = b.path("progress_unity.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = if (link_libc) true else false,
        .strip = if (optimize == .Debug) false else true,
    });

    module.linkSystemLibrary("dbus-1", .{
        .needed = true,
        .use_pkg_config = .yes,
        .preferred_link_mode = preferred_link_mode,
    });

    var plug = b.addLibrary(.{
        .name = "progress_unity",
        .linkage = .dynamic,
        .root_module = module,
    });
    plug.out_filename = b.fmt("{s}{s}", .{ plug.name, target.result.dynamicLibSuffix() });

    // wtf is this nesting...
    b.getInstallStep().dependOn(
        &b.addInstallArtifact(
            plug,
            .{
                .dest_dir = .{
                    .override = .{
                        .custom = "./lib/deadbeef/",
                    },
                },
            },
        ).step,
    );

    // testing
    const test_step = b.step("test", "Run unit tests");

    const test_module = b.createModule(.{
        .root_source_file = b.path("tb_dbus.zig"),
        .target = target,
        .link_libc = true,
    });
    test_module.linkSystemLibrary("dbus-1", .{
        .needed = true,
        .use_pkg_config = .yes,
        .preferred_link_mode = preferred_link_mode,
    });

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
