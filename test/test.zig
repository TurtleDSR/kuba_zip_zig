const std = @import("std");
const zip = @import("zip");

test "error message" {
    const err = zip.getErrorMessage(zip.ZipError.FileNotFound);
    std.debug.print("\"error message\" - Error: {s}", .{err});
    try std.testing.expect(std.mem.eql(u8, err, "file not found"));
}

test "open missing zip error message" {
    _ = zip.open("test/.in/nonexistent.zip", zip.defaultCompressionLevel, 'r') catch |err| {
        std.debug.print("\n\"open missing zip error message\" - Error: {s}", .{zip.getErrorMessage(err)});
        return;
    };

    return std.testing.expect(false);
}

test "open and write entry" {
    var z = try zip.open("test/.out/write.zip", zip.defaultCompressionLevel, 'w');
    defer z.close();

    try z.openEntry("test.txt");
    {
        try z.writeEntry("TEST");
        z.closeEntry();
    }
}

test "open and delete entry" {
    var z = try zip.open("test/.out/write.zip", zip.defaultCompressionLevel, 'a');
    defer z.close();

    try std.testing.expect(try z.getEntryTotal() > 0); //make sure entries exist

    const entries: [1][:0]const u8 = .{
        "test.txt",
    };

    const deleted = try z.deleteEntries(&entries);
    try std.testing.expect(deleted > 0); //make sure we deleted entries
}

test "open and read entry" {
    var z = try zip.open("test/.in/read.zip", zip.defaultCompressionLevel, 'r');
    defer z.close();

    try z.openEntry("test.txt");
    defer z.closeEntry();

    const len = z.getEntrySize();

    var buf = try std.testing.allocator.alloc(u8, len);
    defer std.testing.allocator.free(buf);

    const data_len = try z.bufferReadEntry(&buf);

    std.debug.print("\n\"open and read entry\" - Data: {s}", .{buf[0..data_len]});

    try std.testing.expect(std.mem.eql(u8, buf[0..data_len], "TEST"));
}

test "extract entry with callback" {
    var z = try zip.open("test/.in/read.zip", zip.defaultCompressionLevel, 'r');
    defer z.close();

    try z.openEntry("test.txt");
    defer z.closeEntry();

    const cb = struct {
        fn callback(offset: u64, data: []const u8, arg: anytype) anyerror!usize {
            try std.testing.expect(std.mem.eql(u8, arg.str, "test string"));
            try std.testing.expect(arg.int == 15);

            std.debug.print("\n\"extract entry with callback\" - Data: {s}", .{data[offset..data.len]});
            return data.len;
        }
    };

    try z.extractEntry(cb.callback, .{ .str = "test string", .int = 15 });
}

//Example code blocks from README
test "Create a new zip archive with default compression level" {
    var z = try zip.open("test/.out/foo.zip", zip.defaultCompressionLevel, 'w');
    defer z.close();

    try z.openEntry("foo-1.txt");
    {
        defer z.closeEntry();

        const buf: [:0]const u8 = "Some data here...";
        try z.writeEntry(buf);
    }

    try z.openEntry("foo-2.txt");
    {
        defer z.closeEntry();

        try z.fileWriteEntry("test/.in/foo-2.1.txt");
        try z.fileWriteEntry("test/.in/foo-2.2.txt");
        try z.fileWriteEntry("test/.in/foo-2.3.txt");
    }
}

test "Append to the exisiting archive" {
    var z = try zip.open("test/.out/foo.zip", zip.defaultCompressionLevel, 'a');
    defer z.close();

    try z.openEntry("foo-3.txt");
    {
        defer z.closeEntry();

        const buf: [:0]const u8 = "Append Some data here...";
        try z.writeEntry(buf);
    }
}

test "Extract a zip archive into a folder" {
    const cb = struct {
        fn on_extract(filename: []const u8, arg: anytype) anyerror!void {
            _ = arg; //we dont need this optional arg

            std.debug.print("\n    Extracted: {s}", .{filename});
        }
    };

    try zip.extract("test/.out/foo.zip", "test/.out/tmp", cb.on_extract, &.{});
}

test "Extract a zip entry into memory" {
    var z = try zip.open("test/.out/foo.zip", zip.defaultCompressionLevel, 'r');
    defer z.close();

    var buffer: []u8 = undefined;
    defer std.testing.allocator.free(buffer);

    try z.openEntry("foo-1.txt");
    {
        defer z.closeEntry();

        buffer = try z.readEntry(std.testing.allocator);
        try std.testing.expect(buffer.len > 0);
    }
}
