const std = @import("std");
//module builder

pub fn build(b: *std.Build) void {
    b.build_root.handle.access(b.graph.io, "dev.build.zig", .{}) catch {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});

        const zip_mod = b.addModule("zip", .{
            .root_source_file = b.path("root.zig"),
            .optimize = optimize,
            .target = target,
        });
        zip_mod.link_libc = true;
        zip_mod.addLibraryPath(b.path("../lib/"));
        zip_mod.linkSystemLibrary("zip_c", .{.preferred_link_mode = .static});

        return;
    };

    const dev_build = @import("dev.build.zig");
    dev_build.build(b);
}