const std = @import("std");
const zip = @import("zip");

test "error message" {
    const err = zip.getErrorMessage(zip.ZipError.FileNotFound);
    std.debug.print("\"error message\" - Error: {s}", .{err});
    try std.testing.expect(std.mem.eql(u8, err, "file not found"));
}

test "open missing zip error message" {
    _ = zip.Zip.open("test/static/nonexistent.zip", zip.defaultCompressionLevel, 'r') catch |err| {
        std.debug.print("\n\"open missing zip error message\" - Error: {s}", .{zip.getErrorMessage(err)});
        return;
    };

    return std.testing.expect(false);
}

test "open and write entry" {
    var z = try zip.Zip.open("test/static/write.zip", zip.defaultCompressionLevel, 'w');

    try z.openEntry("test.txt");
    try z.writeEntry("TEST");
    try z.closeEntry();

    z.close();
}

test "open and delete entry" {
    var z = try zip.Zip.open("test/static/write.zip", zip.defaultCompressionLevel, 'a');

    try std.testing.expect(try z.getEntryTotal() > 0); //make sure entries exist

    const entries: [1][:0]const u8 = .{
        "test.txt",
    };

    const deleted = try z.deleteEntries(&entries);
    try std.testing.expect(deleted > 0); //make sure we deleted entries

    z.close();
}

test "open and read entry" {
    var z = try zip.Zip.open("test/static/read.zip", zip.defaultCompressionLevel, 'r');
    try z.openEntry("test.txt");

    const len = z.getEntrySize();

    var buf = try std.testing.allocator.alloc(u8, len);
    defer std.testing.allocator.free(buf);

    const data_len = try z.bufferReadEntry(&buf);

    std.debug.print("\n\"open and read entry\" - Data: {s}", .{buf[0..data_len]});
    z.close();

    try std.testing.expect(std.mem.eql(u8, buf[0..data_len], "TEST"));
}

test "extract entry with callback" {
    var z = try zip.Zip.open("test/static/read.zip", zip.defaultCompressionLevel, 'r');
    try z.openEntry("test.txt");

    const cb = struct {
        fn callback(arg: anytype, offset: u64, data: []const u8) anyerror!usize {
            try std.testing.expect(std.mem.eql(u8, arg.str, "test string"));
            try std.testing.expect(arg.int == 15);

            std.debug.print("\n\"extract entry with callback\" - Data: {s}", .{data[offset..data.len]});
            return data.len;
        }
    };

    try z.extractEntry(.{.str = "test string", .int = 15}, cb.callback);
}
