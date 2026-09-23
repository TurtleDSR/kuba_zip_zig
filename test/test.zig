const std = @import("std");
const zip = @import("zip");

test "error message" {
    const err = zip.errorString(zip.ZipError.FileNotFound);
    std.debug.print("Error: {s}...", .{err});
    try std.testing.expect(std.mem.eql(u8, err, "file not found"));
}
