const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const version = .{ .major = 0, .minor = 1, .patch = 0 };

    // Client executable
    const exe_client_step = b.step("exe-client", "Run Wazzup minimal chat client");

    const exe_client = b.addExecutable(.{
        .name = "wazzup-client",
        .root_source_file = std.Build.FileSource.relative("src/main_client.zig"),
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    b.installArtifact(exe_client);

    const exe_client_run = b.addRunArtifact(exe_client);

    exe_client_step.dependOn(&exe_client_run.step);

    // Server executable
    const exe_server_step = b.step("exe-server", "Run Wazzup minimal chat server");

    const exe_server = b.addExecutable(.{
        .name = "wazzup-server",
        .root_source_file = std.Build.FileSource.relative("src/main_server.zig"),
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    b.installArtifact(exe_server);

    const exe_server_run = b.addRunArtifact(exe_server);

    exe_server_step.dependOn(&exe_server_run.step);
    b.default_step.dependOn(exe_server_step);

    // Lints
    const lints_step = b.step("lint", "Run lints");

    const lints = b.addFmt(.{
        .paths = &.{ "src", "build.zig" },
        .check = true,
    });

    lints_step.dependOn(&lints.step);
    b.default_step.dependOn(lints_step);
}
