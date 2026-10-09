## Zig wrapper for the amazing zip library for c written by kuba
## Almost all credit goes to them + the contributors of the original library since all the hard work was done there

### A portable (OSX/Linux/Windows/Android/iOS), simple zip library written in C (bindings in zig)

This is done by hacking awesome [miniz](https://github.com/richgel999/miniz) library and layering functions on top of the miniz v3.1.2 API.

### The Idea

<img src="zip.png" name="zip" />
... Some day, I (Kuba) was looking for zip library written in C for my project, but I could not find anything simple enough and lightweight.
Everything what I tried required 'crazy mental gymnastics' to integrate or had some limitations or was too heavy.
I hate frameworks, factories and adding new dependencies. If I must to install all those dependencies and link new library, I'm getting almost sick.
I wanted something powerful and small enough, so I could add just a few files and compile them into my project.
And finally I found miniz.
Miniz is a lossless, high performance data compression library in a single source file. I only needed simple interface to append buffers or files to the current zip-entry. Thanks to this feature I'm able to merge many files/buffers and compress them on-the-fly.

It was the reason, why I decided to write zip module on top of the miniz. It required a little bit hacking and wrapping some functions, but I kept simplicity. So, you can grab these 3 files and compile them into your project. I hope that interface is also extremely simple, so you will not have any problems to understand it.

### The Idea For Zig
I (Turtle) have been using kuba zip for ages in my c projects. Since I am now transitioning over to zig as my primary low level language, I decided to make bindings to make my life with archives easier. This features work on the naming and types of the functions to make them fit directly with zig code rather than requiring boilerplate every time you call a function.

### Documentation
For in-depth documentation, take a look at the [docs](https://turtledsr.github.io/kuba_zip_zig/)

### Examples
All examples pass the testing suite in the test/ directory.

* Create a new zip archive with default compression level.
```zig
var z = try zip.open("foo.zip", zip.defaultCompressionLevel, 'w');
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

    try z.fileWriteEntry("foo-2.1.txt");
    try z.fileWriteEntry("foo-2.2.txt");
    try z.fileWriteEntry("foo-2.3.txt");
}
```

* Append to the existing zip archive.
```zig
var z = try zip.open("foo.zip", zip.defaultCompressionLevel, 'a');
defer z.close();

try z.openEntry("foo-3.txt");
{
    defer z.closeEntry();

    const buf: [:0]const u8 = "Append Some data here...";
    try z.writeEntry(buf);
}
```

* Extract a zip archive into a folder.
```zig
const cb = struct {
    fn on_extract(filename: []const u8, arg: anytype) anyerror!void {
        _ = arg; //we dont need this optional arg

        std.debug.print("Extracted: {s}\n", .{filename});
    }
};

try zip.extract("foo.zip", "/tmp", cb.on_extract, &.{});
```

* Extract a zip entry into memory.
```zig
var z = try zip.open("foo.zip", zip.defaultCompressionLevel, 'r');
defer z.close();

var buffer: []u8 = undefined;
defer allocator.free(buffer);

try z.openEntry("foo-1.txt");
{
    defer z.closeEntry();

    buffer = try z.readEntry(allocator);
}
```

* Extract a zip entry into memory (no internal allocation).
```zig
var z = try zip.open("foo.zip", zip.defaultCompressionLevel, 'r');
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
```

* Extract a zip entry into memory using callback.
```zig
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

var z = try zip.open("foo.zip", zip.defaultCompressionLevel, 'r');
{
    defer z.close();

    try z.openEntry("foo-1.txt"); 
    {
        defer z.closeEntry();

        try z.extractEntry(Callback.on_extract, &cb);
    }
}
```

* Extract a zip entry into a file.
```zig
var z = try zip.open("foo.zip", zip.defaultCompressionLevel, 'r');
{
    defer z.close();

    try z.openEntry("foo-2.txt");
    {
        defer z.closeEntry();
        try z.fileReadEntry("foo-2.txt");
    }
}
```

* Create a new zip archive in memory (stream API).
```zig
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
```

* Extract a zip entry into memory (stream API).
```zig
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
```

* Extract a partial zip entry

Reads up to `size` bytes of the entry starting at `offset` into a caller-owned
buffer (no internal allocation). `size` is clamped to the bytes remaining after
`offset`, so it is safe to pass a size larger than what is left in the entry. The
call returns the number of bytes actually written, or a negative error code (for
example when `offset` is past the end of the entry).

```zig
var bufarr = std.mem.zeroes([16]u8);
var buffer: []u8 = bufarr[0..];

var z = try zip.open("foo.zip", zip.defaultCompressionLevel, 'r');
{
    defer z.close();

    try z.openEntry("foo-1.txt");
    {
        defer z.closeEntry();

        const offset: usize = 4;
        const read = try z.offsetBufferReadEntry(offset, &buffer);
    }
}
```

* List of all zip entries
```zig
var z = try zip.open("foo.zip", zip.defaultCompressionLevel, 'r');
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

            std.debug.print("Entry - {s}: {{isDir: {s}}}, {{isSymlink: {s}}}, {{size: {d}}}, {{crc32: {d}}}\n", .{
                name, 
                if(isDir) "true" else "false", 
                if(isSymLink) "true" else "false", 
                size, 
                crc32
            });
        }
    }
}
```

* Delete zip archive entries.
```zig
const entries: []const [:0]const u8 = &.{"unused.txt", "remove.ini", "delete.me"};
var z = try zip.open("delete.zip", zip.defaultCompressionLevel, 'd');
{
    defer z.close();
    const deleted = try z.deleteEntries(entries);
}
```

* Create a password-protected zip archive (Traditional PKWARE Encryption).
```zig
var z = try zip.openWithPassword("secret.zip", zip.defaultCompressionLevel, 'w', "password");
{
    defer z.close();

    try z.openEntry("secret-1.txt");
    {
        defer z.closeEntry();

        try z.writeEntry("Classified data...");
    }
}
```

* Extract a password-protected zip archive.
```zig
var buffer: []u8 = undefined;
defer allocator.free(buffer);

var z = try zip.openWithPassword("secret.zip", zip.defaultCompressionLevel, 'r', "password");
{
    defer z.close();

    try z.openEntry("secret-1.txt");
    {
        defer z.closeEntry();
        buffer = try z.readEntry(allocator);
    }
}
```

### No ZIP64

By default, opening an archive for writing with the literal mode character `'w'` will enable ZIP64 output.
Internally the library sets a write flag when the mode equals the literal `'w'`:

```c
mz_uint wflags = (mode == 'w') ? MZ_ZIP_FLAG_WRITE_ZIP64 : 0;
```

To ensure the produced ZIP archive is _NOT ZIP64_, use the alternate mode value that selects the same semantic mode but does not compare equal to the literal `'w'`.
The implementation accepts an alternate value in the switch labels (so the same behavior is selected), but only the literal `'w'` triggers the automatic ZIP64 flag.

Convention:
- Use `'w' - 64` (integer value 55) when calling `open`, `openStream`, etc., to select write mode without enabling ZIP64.
- The same pattern applies to other modes: use `'r' - 64`, `'a' - 64`, `'d' - 64` to pick the non-ZIP64 variants.

### Building

You can build yourself if you have zig 0.16.0 installed along with the Just command runner:
```bash
just build
```
Optionally, you can run the tests as well:
```bash
just test
```

### Usage

To add it directly to your zig project you can run:
```bash
zig fetch --save git+https://github.com/TurtleDSR/kuba_zip_zig/
```
In your build.zig, load the dependency and import it to your module with:
```zig
const zip = b.dependency("zip", .{});
root_module.addImport("zip", zip.module("zip));
```8