// SPDX-FileCopyrightText: 2025 Jakub Wasylków <kuba_160@protonmail.com>
// SPDX-License-Identifier: CC0-1.0
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const module = b.createModule(.{
        .root_source_file = b.path("progress_unity.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });
    module.linkSystemLibrary("dbus-1", .{ .needed = true, .use_pkg_config = .yes });

    var plug = b.addLibrary(.{
        .name = "progress_unity",
        .linkage = .dynamic,
        .root_module = module,
    });
    plug.out_filename = "progress_unity.so";

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

    test_module.linkSystemLibrary("dbus-1", .{});

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
