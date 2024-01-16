const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const version = .{ .major = 0, .minor = 1, .patch = 0 };

    // Dependencies
    const xev_dep = b.dependency("xev", .{});
    const xev_mod = xev_dep.module("xev");

    // Server executable
    const exe_server_step = b.step("server", "Run Wazzup minimal command-line chat server");

    const exe_server = b.addExecutable(.{
        .name = "wazzup_server",
        .root_source_file = std.Build.LazyPath.relative("src/main_server.zig"),
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    exe_server.root_module.addImport("xev", xev_mod);
    b.installArtifact(exe_server);

    const exe_server_run = b.addRunArtifact(exe_server);
    exe_server_step.dependOn(&exe_server_run.step);
    b.default_step.dependOn(exe_server_step);

    // Client executable
    const exe_client_step = b.step("client", "Run Wazzup minimal command-line chat client");

    const exe_client = b.addExecutable(.{
        .name = "wazzup_client",
        .root_source_file = std.Build.LazyPath.relative("src/main_client.zig"),
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    exe_client.root_module.addImport("xev", xev_mod);
    b.installArtifact(exe_client);

    const exe_client_run = b.addRunArtifact(exe_client);
    exe_client_step.dependOn(&exe_client_run.step);

    // Lints
    const lints_step = b.step("lint", "Run lints");

    const lints = b.addFmt(.{
        .paths = &.{ "src", "build.zig" },
        .check = true,
    });

    lints_step.dependOn(&lints.step);
    b.default_step.dependOn(lints_step);
}
