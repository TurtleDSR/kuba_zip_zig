const std = @import("std");
const allocator = std.testing.allocator;

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

    var buffer: []u8 = undefined;
    defer allocator.free(buffer);

    try z.openEntry("test.txt");
    {
        defer z.closeEntry();

        const len = z.getEntrySize();

        buffer = try allocator.alloc(u8, len);

        const data_len = try z.bufferReadEntry(&buffer);

        std.debug.print("\n\"open and read entry\" - Data: {s}", .{buffer[0..data_len]});
        try std.testing.expect(std.mem.eql(u8, buffer[0..data_len], "TEST"));
    }
}

test "extract entry with callback" {
    var z = try zip.open("test/.in/read.zip", zip.defaultCompressionLevel, 'r');
    defer z.close();

    try z.openEntry("test.txt");
    defer z.closeEntry();

    const cb = struct {
        fn callback(offset: u64, data: []const u8, arg: anytype) anyerror!void {
            try std.testing.expect(std.mem.eql(u8, arg.str, "test string"));
            try std.testing.expect(arg.int == 15);

            std.debug.print("\n\"extract entry with callback\" - Data: {s}", .{data[offset..data.len]});
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
    defer allocator.free(buffer);

    try z.openEntry("foo-1.txt");
    {
        defer z.closeEntry();

        buffer = try z.readEntry(allocator);
        try std.testing.expect(buffer.len > 0);
    }
    try std.testing.expect(std.mem.eql(u8, buffer, "Some data here..."));
}

test "Extract a zip entry into memory (no internal allocation)" {
    var z = try zip.open("test/.out/foo.zip", zip.defaultCompressionLevel, 'r');
    defer z.close();

    var buffer: []u8 = undefined;
    defer allocator.free(buffer);

    try z.openEntry("foo-1.txt");
    {
        defer z.closeEntry();

        buffer = try allocator.alloc(u8, z.getEntrySize());
        const read = try z.bufferReadEntry(&buffer);
        try std.testing.expect(read > 0);
    }
    try std.testing.expect(std.mem.eql(u8, buffer, "Some data here..."));
}

test "Extract a zip entry into memory using callback" {
    const Callback = struct {
        buffer: []u8,
        allocator: std.mem.Allocator,

        fn on_extract(offset: u64, data: []const u8, arg: anytype) anyerror!void {
            _ = offset; //unused
            var self: *@This() = @ptrCast(@alignCast(arg));

            self.allocator.free(self.buffer); //free buffer if defined
            self.buffer = try self.allocator.dupe(u8, data);
        }
    };

    var cb: Callback = .{
        .allocator = allocator,
        .buffer = &.{},
    };
    defer allocator.free(cb.buffer);

    var z = try zip.open("test/.out/foo.zip", zip.defaultCompressionLevel, 'r');
    {
        defer z.close();

        try z.openEntry("foo-1.txt"); 
        {
            defer z.closeEntry();

            try z.extractEntry(Callback.on_extract, &cb);
        }
    }
    try std.testing.expect(std.mem.eql(u8, cb.buffer, "Some data here..."));
}

test "Extract a zip entry into a file" {
    var z = try zip.open("test/.out/foo.zip", zip.defaultCompressionLevel, 'r');
    {
        defer z.close();

        try z.openEntry("foo-2.txt");
        {
            defer z.closeEntry();
            try z.fileReadEntry("test/.out/foo-2.txt");
        }
    }
}

test "Create a new zip archive in memory (stream API)" {
    var outbuffer: []?*u8 = &.{};
    defer allocator.free(outbuffer);

    const inbuffer: []const u8 = "Append some data here...";

    var z = try zip.openStream(null, zip.defaultCompressionLevel, 'w');
    {
        defer z.closeStream();

        try z.openEntry("foo-1.txt");
        {
            defer z.closeEntry();
            try z.writeEntry(inbuffer);
        }

        const read = try z.copyStreamBuffer(&outbuffer, allocator); //allocates buffer since it is empty
        try std.testing.expect(read > 0);
    }
}

test "Extract a zip entry into memory (stream API)" {
    const stream = @embedFile(".out/foo.zip");
    
    var buffer: []u8 = undefined;
    defer allocator.free(buffer);

    var z = try zip.openStream(stream, zip.defaultCompressionLevel, 'r');
    {
        defer z.closeStream();

        try z.openEntry("foo-1.txt");
        {
            defer z.closeEntry();
            buffer = try z.readEntry(allocator);
        }
    }

    try std.testing.expect(buffer.len > 0);
    try std.testing.expect(std.mem.eql(u8, buffer, "Some data here..."));
}

test "Extract a partial zip entry" {
    var bufarr = std.mem.zeroes([16]u8);
    var buffer: []u8 = bufarr[0..];

    var z = try zip.open("test/.out/foo.zip", zip.defaultCompressionLevel, 'r');
    {
        defer z.close();

        try z.openEntry("foo-1.txt");
        {
            defer z.closeEntry();

            const offset: usize = 4;
            const read = try z.offsetBufferReadEntry(offset, &buffer);
            try std.testing.expect(read > 0);
        }
    }
    std.debug.print("\n\"Extract a partial zip entry\" - Read Value: {s}", .{buffer});
}

test "List of all zip entries" {
    var z = try zip.open("test/.out/foo.zip", zip.defaultCompressionLevel, 'r');
    {
        defer z.close();

        const entryCount = try z.getEntryTotal();
        for(0..entryCount) |i| {
            try z.openEntryByIndex(i);
            {
                defer z.closeEntry();

                const name = try z.getEntryName();
                const isDir = try z.isEntryDirectory();
                const isSymLink = try z.isEntrySymlink();
                const size = z.getEntrySize();
                const crc32 = z.getEntrycrc32();

                std.debug.print("\n    Entry - {s}: {{isDir: {s}}}, {{isSymlink: {s}}}, {{size: {d}}}, {{crc32: {d}}}", .{
                    name, 
                    if(isDir) "true" else "false", 
                    if(isSymLink) "true" else "false", 
                    size, 
                    crc32
                });
            }
        }
    }
}

test "Add entries to be deleted" {
    var z = try zip.open("test/.in/delete.zip", zip.defaultCompressionLevel, 'w');
    {
        defer z.close();

        try z.openEntry("unused.txt");
        {
            defer z.closeEntry();

            try z.writeEntry("unused");
        }

        try z.openEntry("remove.ini");
        {
            defer z.closeEntry();

            try z.writeEntry("remove");
        }

        try z.openEntry("delete.me");
        {
            defer z.closeEntry();

            try z.writeEntry("delete");
        }
    }
}

test "Delete zip archive entries" {
    const entries: []const [:0]const u8 = &.{"unused.txt", "remove.ini", "delete.me"};
    var z = try zip.open("test/.in/delete.zip", zip.defaultCompressionLevel, 'd');
    {
        defer z.close();
        const deleted = try z.deleteEntries(entries);

        try std.testing.expect(deleted == 3);
    }
}

test "Create a password protected zip archive (Traditional PKWARE Encryption)" {
    var z = try zip.openWithPassword("test/.out/secret.zip", zip.defaultCompressionLevel, 'w', "password");
    {
        defer z.close();

        try z.openEntry("secret-1.txt");
        {
            defer z.closeEntry();

            try z.writeEntry("Classified data...");
        }
    }
}

test "Extract a password protected zip archive" {
    var buffer: []u8 = undefined;
    defer allocator.free(buffer);

    var z = try zip.openWithPassword("test/.out/secret.zip", zip.defaultCompressionLevel, 'r', "password");
    {
        defer z.close();

        try z.openEntry("secret-1.txt");
        {
            defer z.closeEntry();
            buffer = try z.readEntry(allocator);
        }
    }

    try std.testing.expect(std.mem.eql(u8, buffer, "Classified data..."));
}