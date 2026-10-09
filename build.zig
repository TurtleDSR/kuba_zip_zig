const std = @import("std");
//module builder

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zip_mod = b.addModule("zip", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    zip_mod.link_libc = true;
    zip_mod.addLibraryPath(b.path("lib/"));
    zip_mod.linkSystemLibrary("zip_c", .{ .preferred_link_mode = .static });

    return;
}
