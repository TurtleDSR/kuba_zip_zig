const std = @import("std");
pub fn build(b: *std.Build) void {
    //settings
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //translate step
    const c_translate = b.addTranslateC(.{
        .root_source_file = b.path("zip_c/zip.h"),
        .target = target,
        .optimize = optimize,
    });

    c_translate.addIncludePath(b.path("zip_c/"));

    const translate_usf = b.addUpdateSourceFiles();
    _ = translate_usf.addCopyFileToSource(c_translate.getOutput(), "src/zip_c.zig");

    const translate_step = b.step("translate", "Translate C library code");
    translate_step.dependOn(&translate_usf.step);

    const zip_native = b.addModule("zip_c",.{
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });
    zip_native.addCSourceFiles(.{
        .files = &.{"zip_c/zip.c"},
    });
    zip_native.addIncludePath(b.path("zip_c/"));
    const zip_native_lib = b.addLibrary(.{
        .name = "zip_c",
        .linkage = .static,
        .root_module = zip_native,
    });
    
    //c build step
    const build_c_step = b.step("build-c", "Build c library code into library files");
    const zip_native_artifact = b.addInstallArtifact(zip_native_lib, .{});
    build_c_step.dependOn(&zip_native_artifact.step);

    //test step
    const zip_mod = b.addModule("zip", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zip_mod.linkLibrary(zip_native_lib);

    const zip_test_mod = b.addModule("zip_test", .{
        .root_source_file = b.path("test/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    zip_test_mod.addImport("zip", zip_mod);
    const zip_tests = b.addTest(.{
        .root_module = zip_test_mod,
    });
    const zip_test_install = b.addInstallArtifact(zip_tests, .{});
    const zip_test_artifact = b.addRunArtifact(zip_tests);
    zip_test_artifact.step.dependOn(&zip_test_install.step);

    const test_step = b.step("test", "Run module tests");
    test_step.dependOn(&zip_test_artifact.step);

    //docs step
    const docs_step = b.step("docs", "Generate docs.");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = zip_tests.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    docs_step.dependOn(&install_docs.step);
}