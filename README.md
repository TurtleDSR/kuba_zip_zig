## Zig wrapper for the amazing zip library for c written by kuba
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

I (Turtle) have been using kuba zip for ages in my c projects. Since I am now transitioning over to zig as my primary low level language, I decided to make bindings to make my life with archives easier. This features work on the naming and types of the functions to make them fit directly with zig code rather than requiring boilerplate every time you call a function.

### Examples

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

```c
unsigned char *buf;
size_t bufsize;

struct zip_t *zip = zip_open("foo.zip", 0, 'r');
{
    zip_entry_open(zip, "foo-1.txt");
    {
        bufsize = zip_entry_size(zip);
        buf = calloc(sizeof(unsigned char), bufsize);

        zip_entry_noallocread(zip, (void *)buf, bufsize);
    }
    zip_entry_close(zip);
}
zip_close(zip);

free(buf);
```

* Extract a zip entry into memory using callback.

```c
struct buffer_t {
    char *data;
    size_t size;
};

static size_t on_extract(void *arg, unsigned long long offset, const void *data, size_t size) {
    struct buffer_t *buf = (struct buffer_t *)arg;
    buf->data = realloc(buf->data, buf->size + size + 1);
    assert(NULL != buf->data);

    memcpy(&(buf->data[buf->size]), data, size);
    buf->size += size;
    buf->data[buf->size] = 0;

    return size;
}

struct buffer_t buf = {0};
struct zip_t *zip = zip_open("foo.zip", 0, 'r');
{
    zip_entry_open(zip, "foo-1.txt");
    {
        zip_entry_extract(zip, on_extract, &buf);
    }
    zip_entry_close(zip);
}
zip_close(zip);

free(buf.data);
```

* Extract a zip entry into a file.

```c
struct zip_t *zip = zip_open("foo.zip", 0, 'r');
{
    zip_entry_open(zip, "foo-2.txt");
    {
        zip_entry_fread(zip, "foo-2.txt");
    }
    zip_entry_close(zip);
}
zip_close(zip);
```

* Create a new zip archive in memory (stream API).

```c
char *outbuf = NULL;
size_t outbufsize = 0;

const char *inbuf = "Append some data here...\0";
struct zip_t *zip = zip_stream_open(NULL, 0, ZIP_DEFAULT_COMPRESSION_LEVEL, 'w');
{
    zip_entry_open(zip, "foo-1.txt");
    {
        zip_entry_write(zip, inbuf, strlen(inbuf));
    }
    zip_entry_close(zip);

    /* copy compressed stream into outbuf */
    zip_stream_copy(zip, (void **)&outbuf, &outbufsize);
}
zip_stream_close(zip);

free(outbuf);
```

* Extract a zip entry into memory (stream API).

```c
char *buf = NULL;
size_t bufsize = 0;

struct zip_t *zip = zip_stream_open(zipstream, zipstreamsize, 0, 'r');
{
    zip_entry_open(zip, "foo-1.txt");
    {
        zip_entry_read(zip, (void **)&buf, &bufsize);
    }
    zip_entry_close(zip);
}
zip_stream_close(zip);

free(buf);
```

* Extract a partial zip entry

Reads up to `size` bytes of the entry starting at `offset` into a caller-owned
buffer (no internal allocation). `size` is clamped to the bytes remaining after
`offset`, so it is safe to pass a size larger than what is left in the entry. The
call returns the number of bytes actually written, or a negative error code (for
example when `offset` is past the end of the entry).

```c
unsigned char buf[16];
size_t bufsize = sizeof(buf);

struct zip_t *zip = zip_open("foo.zip", 0, 'r');
{
    zip_entry_open(zip, "foo-1.txt");
    {
        size_t offset = 4;
        ssize_t nread = zip_entry_noallocreadwithoffset(zip, offset, bufsize, (void *)buf);
        if (nread < 0) {
            // offset out of range or read error
        }
    }

    zip_entry_close(zip);
}
zip_close(zip);
```

* List of all zip entries

```c
struct zip_t *zip = zip_open("foo.zip", 0, 'r');
int i, n = zip_entries_total(zip);
for (i = 0; i < n; ++i) {
    zip_entry_openbyindex(zip, i);
    {
        const char *name = zip_entry_name(zip);
        int isdir = zip_entry_isdir(zip);
        int issymlink = zip_entry_issymlink(zip);
        unsigned long long size = zip_entry_size(zip);
        unsigned int crc32 = zip_entry_crc32(zip);
    }
    zip_entry_close(zip);
}
zip_close(zip);
```

* Compress folder (recursively)

```c
void zip_walk(struct zip_t *zip, const char *path) {
    DIR *dir;
    struct dirent *entry;
    char fullpath[MAX_PATH];
    struct stat s;

    memset(fullpath, 0, MAX_PATH);
    dir = opendir(path);
    assert(dir);

    while ((entry = readdir(dir))) {
      // skip "." and ".."
      if (!strcmp(entry->d_name, ".\0") || !strcmp(entry->d_name, "..\0"))
        continue;

      snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);
      stat(fullpath, &s);
      if (S_ISDIR(s.st_mode))
        zip_walk(zip, fullpath);
      else {
        zip_entry_open(zip, fullpath);
        zip_entry_fwrite(zip, fullpath);
        zip_entry_close(zip);
      }
    }

    closedir(dir);
}
```

* Delete zip archive entries.

```c
char *entries[] = {"unused.txt", "remove.ini", "delete.me"};
// size_t indices[] = {0, 1, 2};

struct zip_t *zip = zip_open("foo.zip", 0, 'd');
{
    zip_entries_delete(zip, entries, 3);

    // you can also delete by index, instead of by name
    // zip_entries_deletebyindex(zip, indices, 3);
}
zip_close(zip);
```

* Create a password-protected zip archive (Traditional PKWARE Encryption).

```c
struct zip_t *zip = zip_open_with_password("secret.zip", ZIP_DEFAULT_COMPRESSION_LEVEL, 'w', "password");
{
    zip_entry_open(zip, "secret-1.txt");
    {
        const char *buf = "Classified data...\0";
        zip_entry_write(zip, buf, strlen(buf));
    }
    zip_entry_close(zip);
}
zip_close(zip);
```

* Extract a password-protected zip archive.

```c
void *buf = NULL;
size_t bufsize;

struct zip_t *zip = zip_open_with_password("secret.zip", 0, 'r', "password");
{
    zip_entry_open(zip, "secret-1.txt");
    {
        zip_entry_read(zip, &buf, &bufsize);
    }
    zip_entry_close(zip);
}
zip_close(zip);

free(buf);
```

* Password-protected archive in memory (stream API).

```c
char *outbuf = NULL;
size_t outbufsize = 0;

struct zip_t *zip = zip_stream_open_with_password(NULL, 0, ZIP_DEFAULT_COMPRESSION_LEVEL, 'w', "password");
{
    zip_entry_open(zip, "secret-1.txt");
    {
        const char *buf = "Classified data...\0";
        zip_entry_write(zip, buf, strlen(buf));
    }
    zip_entry_close(zip);

    zip_stream_copy(zip, (void **)&outbuf, &outbufsize);
}
zip_stream_close(zip);

/* read it back */
void *readbuf = NULL;
size_t readsize = 0;

zip = zip_stream_open_with_password(outbuf, outbufsize, 0, 'r', "password");
{
    zip_entry_open(zip, "secret-1.txt");
    {
        zip_entry_read(zip, &readbuf, &readsize);
    }
    zip_entry_close(zip);
}
zip_stream_close(zip);

free(readbuf);
free(outbuf);
```

* Delete entries from a password-protected archive.

```c
char *entries[] = {"obsolete.txt", "remove-me.dat"};

struct zip_t *zip = zip_open_with_password("secret.zip", 0, 'd', "password");
{
    zip_entries_delete(zip, entries, 2);
}
zip_close(zip);
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