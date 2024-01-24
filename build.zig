const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("AntleneEntitiesModules", .{
        .root_source_file = .{ .path = "src/main.zig" },
    });

    const test_step = b.step("test", "Run lib test");
    test_step.dependOn(&testStep(b, target, optimize).step);
}

pub fn testStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Run {
    const tests = b.addTest(.{
        .name = "AntleneEntitiesModules-Tests",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(tests);
    return b.addRunArtifact(tests);
}
