//! This is the kuba zip zig binding

const std = @import("std");
const c = @import("zip_c.zig");
const libc = @import("stdlib.h");

/// Default zip compression level.
pub const defaultCompressionLevel: i32 = 6;

/// Error codes zip functions can fail with.
pub const ZipError = error{
    NotInitialized,
    InvalidEntryName,
    EntryNotFound,
    InvalidZipMode,
    InvalidCompressionLevel,
    NoZip64Support,
    MemsetError,
    EntryWriteFailure,
    tdeflCompressorInitializationFailure,
    InvalidIndex,
    HeaderNotFound,
    tdeflFlushFailure,
    EntryHeaderCreateFailure,
    EntryHeaderWriteFailure,
    CentralDirWriteFailure,
    FileOpenFailure,
    InvalidEntryType,
    ExtractingDataUsingNoMemoryAllocation,
    FileNotFound,
    NoPermission,
    OutOfMemory,
    InvalidZipName,
    MakeDirError,
    SymlinkError,
    CloseArchiveError,
    CapacitySizeTooSmall,
    FSeekError,
    FReadError,
    FWriteError,
    ReaderInitializationFailure,
    WriterInitializationFailure,
    WriterFromReaderInitializationFailure,
    InvalidArgument,
    ReaderIteratorInitializationFailure,
    PathExistsButIsNotDirectory,
    PasswordFailure, //password required or wrong password provided
    UnknownError,
};

/// Looks up the error message string corresponding to an error number.
///
/// **Parameters:**
///
/// *errnum* - error number
///
/// **Returns:**
///
/// error message string corresponding to errnum or NULL if error is not found.
pub fn getErrorMessage(err: ZipError) [:0]const u8 {
    if (err == ZipError.UnknownError) {
        return "unknown error";
    }
    const code: c_int = @intCast(getCodeFromError(err));
    return convertCString(c.zip_strerror(code));
}

/// Opens zip archive stream into memory.
///
/// **Parameters:**
///
/// *stream* - zip archive file name.
///
/// *level* - compression level (0-9 are the standard zlib-style levels).
///
/// *mode* - file access mode.
/// - 'r': opens a file for reading/extracting (the file must exists).
/// - 'w': creates an empty file for writing.
/// - 'a': appends to an existing archive.
///
/// **Returns:**
///
/// the zip archive handler
pub fn openStream(stream: ?[]const u8, level: i32, mode: u8) ZipError!Zip {
    var err: c_int = 0;
    const streamptr = if (stream) |ptr| ptr.ptr else null;
    const handle = c.zip_stream_openwitherror(streamptr, if (stream) |s| s.len else 0, @intCast(level), mode, &err) orelse {
        return getErrorFromCode(@intCast(err));
    };

    const out: Zip = Zip{
        .handle = handle,
    };
    return out;
}

/// Opens zip archive stream into memory.
///
/// **Parameters:**
///
/// *stream* - zip archive file name.
///
/// *level* - compression level (0-9 are the standard zlib-style levels).
///
/// *mode* - file access mode.
/// - 'r': opens a file for reading/extracting (the file must exists).
/// - 'w': creates an empty file for writing.
/// - 'a': appends to an existing archive.
///
/// *password* - the password fosr encryption (write) or decryption (read). Pass NULL for no encryption.
///
/// **Returns:**
///
/// the zip archive handler
pub fn openStreamWithPassword(stream: []const u8, level: i32, mode: u8, password: ?[:0]const u8) ZipError!Zip {
    const pass_ptr = if (password) |slice| slice.ptr else null;
    const handle = c.zip_stream_open_with_password(stream.ptr, stream.len, @intCast(level), mode, pass_ptr) orelse {
        return ZipError.UnknownError;
    };

    const out: Zip = Zip{
        .handle = handle,
    };
    return out;
}

/// Extracts a zip archive stream into directory.
///
/// If on_extract is not NULL, the callback will be called after
/// successfully extracted each zip entry.
/// Returning an error from the callback will cause abort and return an
/// error.
///
/// **Parameters:**
///
/// *stream* - zip archive stream.
///
/// *dir* - output directory.
///
/// *on_extract* - on extract callback.
///
/// *arg* - anonymous struct which you can pass to the on_extract callback.
pub fn extractStream(stream: []const u8, dir: [:0]const u8, comptime on_extract: *const fn (filename: []const u8, arg: anytype) anyerror!void, arg: anytype) ZipError!void {
    const t = @TypeOf(arg);

    const Context = struct {
        user_arg: t,
        captured_err: ?anyerror = null,

        fn callback(cbfilename: [*c]const u8, cbarg: ?*anyopaque) callconv(.c) c_int {
            const ctx: *@This() = @ptrCast(@alignCast(cbarg orelse return 0));
            on_extract(convertCString(cbfilename), ctx.user_arg) catch |err| {
                ctx.captured_err = err;
                return 0;
            };
            return 1;
        }
    };

    var ctx = Context{
        .user_arg = arg,
    };

    const err = c.zip_stream_extract(stream.ptr, stream.len, dir.ptr, Context.callback, &ctx);

    if (ctx.captured_err != null) {
        return ZipError.UnknownError;
    }

    if (err < 0) {
        std.debug.print("Error code: {d}", .{err});
        return getErrorFromCode(@intCast(err));
    }
}

/// Extracts a zip archive file into directory.
///
/// If on_extract is not NULL, the callback will be called after
/// successfully extracted each zip entry.
/// Returning an error from the callback will cause abort and return an
/// error.
///
/// **Parameters:**
///
/// *path* - zip archive file.
///
/// *dir* - output directory.
///
/// *on_extract* - on extract callback.
///
/// *arg* - anonymous struct which you can pass to the on_extract callback.
pub fn extract(path: [:0]const u8, dir: [:0]const u8, comptime on_extract: *const fn (filename: []const u8, arg: anytype) anyerror!void, arg: anytype) ZipError!void {
    const t = @TypeOf(arg);

    const Context = struct {
        user_arg: t,
        captured_err: ?anyerror = null,

        fn callback(cbfilename: [*c]const u8, cbarg: ?*anyopaque) callconv(.c) c_int {
            const ctx: *@This() = @ptrCast(@alignCast(cbarg orelse return 0));
            on_extract(convertCString(cbfilename), ctx.user_arg) catch |err| {
                ctx.captured_err = err;
                return 0;
            };
            return 1;
        }
    };

    var ctx = Context{
        .user_arg = arg,
    };

    const err = c.zip_extract(path.ptr, dir.ptr, Context.callback, &ctx);

    if (ctx.captured_err != null) {
        return ZipError.UnknownError;
    }

    if (err < 0) {
        std.debug.print("Error code: {d}", .{err});
        return getErrorFromCode(@intCast(err));
    }
}

/// Creates a new archive and puts files into a single zip archive.
///
/// **Parameters:**
///
/// *path* - zip archive file.
///
/// *files* - input files.
pub fn create(path: [:0]const u8, files: [][:0]const u8) ZipError!void {
    var z = try Zip.open(path, defaultCompressionLevel, 'w');
    defer z.close();

    for (files) |value| {
        try z.writeEntry(value.ptr);
    }
}

/// Opens zip archive with compression level using the given mode.
///
/// **Parameters:**
///
/// *path* - zip archive file name.
///
/// *level* - compression level (0-9 are the standard zlib-style levels).
///
/// *mode* - file access mode.
/// - 'r': opens a file for reading/extracting (the file must exists).
/// - 'w': creates an empty file for writing.
/// - 'a': appends to an existing archive.
///
/// **Returns:**
///
/// the zip archive handler
pub fn open(path: [:0]const u8, level: i32, mode: u8) ZipError!Zip {
    var err: c_int = 0;
    const handle = c.zip_openwitherror(path.ptr, @intCast(level), mode, &err) orelse {
        return getErrorFromCode(@intCast(err));
    };

    const out: Zip = Zip{
        .handle = handle,
    };
    return out;
}

/// Opens zip archive with a password for encryption/decryption using
///
/// **Parameters:**
///
/// *path* - zip archive file name.
///
/// *level* - compression level (0-9 are the standard zlib-style levels).
///
/// *mode* - file access mode.
/// - 'r': opens a file for reading/extracting (the file must exists).
/// - 'w': creates an empty file for writing.
/// - 'a': appends to an existing archive.
///
/// *password* - the password fosr encryption (write) or decryption (read). Pass NULL for no encryption.
///
/// **Returns:**
///
/// the zip archive handler
pub fn openWithPassword(path: [:0]const u8, level: i32, mode: u8, password: ?[:0]const u8) ZipError!Zip {
    var err: c_int = 0;
    const pass_ptr = if (password) |slice| slice.ptr else null;
    const handle = c.zip_open_with_password_and_error(path.ptr, @intCast(level), mode, pass_ptr, &err) orelse {
        return getErrorFromCode(@intCast(err));
    };

    const out: Zip = Zip{
        .handle = handle,
    };
    return out;
}

/// **Represents a zip archive**
///
/// Created with Zip.open()
///
/// When finished, use Zip.close()
pub const Zip = struct {
    handle: *c.struct_zip_t,

    /// Closes the zip archive, releases resources - always finalize.
    pub fn close(self: *Zip) void {
        c.zip_close(self.handle);
    }

    /// Determines if the archive has a zip64 end of central directory headers.
    ///
    /// **Returns:**
    ///
    /// the status of the query.
    pub fn is64(self: *Zip) ZipError!bool {
        const err = c.zip_is64(self.handle);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        } else {
            return err == 1;
        }
    }

    /// Returns the offset in the stream where the zip header is located.
    ///
    /// **Returns:**
    ///
    /// zip header offset.
    pub fn offset(self: *Zip) ZipError!u64 {
        var off: usize = 0;
        const err = c.zip_offset(self.handle, &off);

        if (err == 0) { //success
            return off;
        } else { //error
            return getErrorFromCode(@intCast(err));
        }
    }

    /// Opens an entry by name in the zip archive.
    ///
    /// For zip archive opened in 'w' or 'a' mode the function will append
    /// a new entry. In readonly mode the function tries to locate the entry
    /// in global dictionary.
    ///
    /// **Parameters:**
    ///
    /// *entryname* - an entry name in local dictionary.
    pub fn openEntry(self: *Zip, entryname: [:0]const u8) ZipError!void {
        const err = c.zip_entry_open(self.handle, entryname);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }
    }

    /// Opens an entry by name in the zip archive.
    ///
    /// For zip archive opened in 'w' or 'a' mode the function will append
    /// a new entry. In readonly mode the function tries to locate the entry
    /// in global dictionary. (case sensitive)
    ///
    /// **Parameters:**
    ///
    /// *entryname* - an entry name in local dictionary.
    pub fn openEntryCaseSensitive(self: *Zip, entryname: [:0]const u8) ZipError!void {
        const err = c.zip_entry_opencasesensitive(self.handle, entryname);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }
    }

    /// Opens an entry by index in the zip archive.
    ///
    /// This function is only valid if zip archive was opened in 'r' (readonly)
    /// mode.
    ///
    /// **Parameters:**
    ///
    /// *index* - index in local dictionary.
    pub fn openEntryByIndex(self: *Zip, index: usize) ZipError!void {
        const err = c.zip_entry_openbyindex(self.handle, index);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }
    }

    /// Closes a zip entry, flushes buffer and releases resources.
    pub fn closeEntry(self: *Zip) void {
        _ = c.zip_entry_close(self.handle);
    }

    /// Returns a local name of the current zip entry.
    ///
    /// The main difference between user's entry name and local entry name
    /// is optional relative path.
    /// Following .ZIP File Format Specification - the path stored MUST not contain
    /// a drive or device letter, or a leading slash.
    /// All slashes MUST be forward slashes '/' as opposed to backwards slashes '\'
    /// for compatibility with Amiga and UNIX file systems etc.
    ///
    /// **Returns:**
    ///
    /// the current zip entry name.
    pub fn entryName(self: *Zip) ZipError![:0]const u8 {
        const err = c.zip_entry_name(self.handle);
        if (err == null) {
            return ZipError.UnknownError;
        } else {
            return convertCString(err);
        }
    }

    /// Returns an index of the current zip entry.
    ///
    /// **Returns:**
    ///
    /// the index.
    pub fn getEntryIndex(self: *Zip) ZipError!isize {
        const err = c.zip_entry_index(self.handle);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }

        return err;
    }

    /// Determines if the current zip entry is a directory entry.
    ///
    /// **Returns:**
    ///
    /// the status of the query.
    pub fn isEntryDirectory(self: *Zip) ZipError!bool {
        const err = c.zip_entry_isdir(self.handle);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        } else {
            return err == 1;
        }
    }

    /// Determines if the current zip entry is a symlink.
    ///
    /// **Returns:**
    ///
    /// the status of the query.
    pub fn isEntrySymlink(self: *Zip) ZipError!bool {
        const err = c.zip_entry_issymlink(self.handle);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        } else {
            return err == 1;
        }
    }

    /// Returns the uncompressed size of the current zip entry.
    /// Alias for zip_entry_uncomp_size (for backward compatibility).
    ///
    /// **Returns:**
    ///
    /// the uncompressed size in bytes.
    pub fn getEntrySize(self: *Zip) usize {
        return @intCast(c.zip_entry_size(self.handle));
    }

    /// Returns the uncompressed size of the current zip entry.
    ///
    /// **Returns:**
    ///
    /// the uncompressed size in bytes.
    pub fn getEntryUncompressedSize(self: *Zip) usize {
        return @intCast(c.zip_entry_uncomp_size(self.handle));
    }

    /// Returns the compressed size of the current zip entry.
    ///
    /// **Returns:**
    ///
    /// the compressed size in bytes.
    pub fn getEntryCompressedSize(self: *Zip) usize {
        return @intCast(c.zip_entry_comp_size(self.handle));
    }

    /// Returns CRC-32 checksum of the current zip entry.
    ///
    /// **Returns:**
    ///
    /// the CRC-32 checksum.
    pub fn getEntrycrc32(self: *Zip) u32 {
        return @intCast(c.zip_entry_crc32(self.handle));
    }

    /// Returns byte offset of the current zip entry
    /// in the archive's central directory.
    ///
    /// **Returns:**
    ///
    /// the offset in bytes.
    pub fn getEntryDirectoryOffset(self: *Zip) u64 {
        return @intCast(c.zip_entry_dir_offset(self.handle));
    }

    /// Returns the current zip entry's local header file offset in bytes.
    ///
    /// **Returns:**
    ///
    /// the entry's local header file offset in bytes.
    pub fn getEntryHeaderOffset(self: *Zip) u64 {
        return @intCast(c.zip_entry_header_offset(self.handle));
    }

    /// Compresses an input buffer for the current zip entry.
    ///
    /// **Parameters:**
    ///
    /// *buffer* - input buffer.
    pub fn writeEntry(self: *Zip, buffer: []const u8) ZipError!void {
        const err = c.zip_entry_write(self.handle, buffer.ptr, buffer.len);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }
    }

    /// Compresses a file for the current zip entry.
    ///
    /// **Parameters:**
    ///
    /// *filename* - input file.
    pub fn fileWriteEntry(self: *Zip, filename: [:0]const u8) ZipError!void {
        const err: i32 = c.zip_entry_fwrite(self.handle, filename.ptr);
        if (err < 0) {
            return getErrorFromCode(err);
        }
    }

    /// Extracts the current zip entry and returns a slice of bytes.
    ///
    /// The function allocates sufficient memory for a output buffer.
    ///
    /// **Returns:**
    ///
    /// the slice of bytes read from the entry.
    ///
    /// **Note:**
    ///
    /// Output must be freed.
    pub fn readEntry(self: *Zip, allocator: std.mem.Allocator) ZipError![]u8 {
        const entry_size = self.getEntrySize();

        const buffer: []u8 = allocator.alloc(u8, entry_size) catch return ZipError.OutOfMemory;
        errdefer allocator.free(buffer);

        const err = c.zip_entry_noallocread(self.handle, buffer.ptr, buffer.len);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }

        const read_size: usize = @intCast(err);
        return allocator.realloc(buffer, read_size) catch buffer[0..read_size];
    }

    /// Extracts the current zip entry and returns a slice of bytes.
    ///
    /// **Parameters:**
    ///
    /// *buffer* - preallocated output buffer slice.
    ///
    /// **Returns:**
    ///
    /// the number of bytes read into the provided buffer.
    ///
    /// **Note:**
    /// ensure supplied output buffer is large enough.
    /// getEntrySize function (returns uncompressed size for the current
    /// entry) can be handy to estimate how big buffer is needed.
    /// For large entries, please take a look at extractEntry function.
    pub fn bufferReadEntry(self: *Zip, buffer: *[]u8) ZipError!usize {
        const err = c.zip_entry_noallocread(self.handle, buffer.ptr, buffer.len);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }

        const read_size: usize = @intCast(err);
        return read_size;
    }

    /// Extracts the part of the current zip entry into a memory buffer using no
    /// memory allocation for the buffer.
    ///
    /// **Parameters:**
    ///
    /// *read_offset* - the offset of the entry (in bytes).
    ///
    /// *buffer* - preallocated output buffer slice.
    ///
    /// **Returns:**
    ///
    /// the number of bytes read into the provided buffer.
    ///
    /// **Note:**
    ///
    /// the iterator api uses an allocation to create its state
    ///
    /// each call will iterate from the start of the entry
    pub fn offsetBufferReadEntry(self: *Zip, read_offset: usize, buffer: *[]u8) ZipError!usize {
        const err = c.zip_entry_noallocreadwithoffset(self.handle, @intCast(read_offset), buffer.ptr, buffer.len);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }

        const read_size: usize = @intCast(err);
        return read_size;
    }

    /// Extracts the current zip entry into output file.
    ///
    /// **Parameters:**
    ///
    /// *filename* - output file.
    pub fn fileReadEntry(self: *Zip, filename: [:0]const u8) ZipError!void {
        const err = c.zip_entry_fread(self.handle, filename);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }
    }

    /// Extracts the current zip entry using a callback function (on_extract).
    ///
    /// **Parameters:**
    ///
    /// *on_extract* - comptime callback function.
    ///
    /// *arg* - anonymous struct which you can pass to the on_extract callback.
    pub fn extractEntry(self: *Zip, comptime on_extract: *const fn (entryoffset: u64, data: []const u8, arg: anytype) anyerror!void, arg: anytype) ZipError!void {
        const t = @TypeOf(arg);

        const Context = struct {
            user_arg: t,
            captured_err: ?anyerror = null,

            fn callback(cbarg: ?*anyopaque, cboffset: u64, cbdata: ?*const anyopaque, cbsize: usize) callconv(.c) usize {
                const ctx: *@This() = @ptrCast(@alignCast(cbarg orelse return 0));

                if (cbdata == null or cbsize == 0) return 0;

                const data_bytes: [*]const u8 = @ptrCast(cbdata.?);
                const chunk = data_bytes[0..cbsize];

                on_extract(cboffset, chunk, ctx.user_arg) catch |err| {
                    ctx.captured_err = err;
                    return 0;
                };

                return cbsize;
            }
        };

        var ctx = Context{
            .user_arg = arg,
        };

        const err = c.zip_entry_extract(self.handle, Context.callback, &ctx);

        if (ctx.captured_err != null) {
            return ZipError.UnknownError;
        }

        if (err < 0) {
            std.debug.print("Error code: {d}", .{err});
            return getErrorFromCode(@intCast(err));
        }
    }

    /// Returns the number of all entries (files and directories) in the zip
    /// archive.
    ///
    /// **Returns:**
    ///
    /// the number of entries.
    pub fn getEntryTotal(self: *Zip) ZipError!usize {
        const err = c.zip_entries_total(self.handle);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }

        return @intCast(err);
    }

    /// Deletes zip archive entries.
    ///
    /// **Parameters:**
    ///
    /// *entries* - slice of zip archive entries to be deleted.
    ///
    /// **Returns:**
    ///
    /// the number of deleted entries.
    pub fn deleteEntries(self: *Zip, entries: []const [:0]const u8) ZipError!usize {
        //uses a buffer chunk of 128 strings to find a balance between overhead and
        //time complexity while still avoiding heap allocations.

        const chunk_size = comptime 128;
        var entrybuffer: [chunk_size][*c]u8 = undefined;

        var deleted: usize = 0;
        var i: usize = 0;

        while (i < entries.len) {
            const batch_size = @min(entries.len - i, chunk_size);
            const batch = entries[i .. i + batch_size];

            for (batch, 0..) |entry, j| {
                entrybuffer[j] = @constCast(entry.ptr);
            }

            const err = c.zip_entries_delete(self.handle, &entrybuffer[0], batch_size);
            if (err < 0) {
                return getErrorFromCode(@intCast(err));
            }

            deleted += @intCast(err);
            i += batch_size;
        }

        return deleted;
    }

    /// Deletes zip archive entries.
    ///
    /// **Parameters:**
    ///
    /// *entries* - slice of zip archive entry indices to be deleted.
    ///
    /// **Returns:**
    ///
    /// the number of deleted entries.
    pub fn deleteEntriesByIndex(self: *Zip, entries: []const usize) ZipError!usize {
        const err = c.zip_entries_deletebyindex(self.handle, entries.ptr, entries.len);
        if (err < 0) {
            return getErrorFromCode(@intCast(err));
        }

        return @intCast(err);
    }

    /// Copy zip archive stream output buffer.
    ///
    /// **Parameters:**
    ///
    /// *buffer* - output buffer.
    /// 
    /// *allocator* - allocator.
    ///
    /// **Returns:**
    ///
    /// copy size.
    ///
    /// **Note:**
    ///
    /// Allocates buffer if it is passed as empty.
    pub fn copyStreamBuffer(self: *Zip, buffer: *[]?*u8, allocator: std.mem.Allocator) ZipError!usize {
        var buf_ptr: ?*anyopaque = if (buffer.len > 0) @ptrCast(buffer.ptr) else null;
        var buf_len = buffer.len;

        const err = c.zip_stream_copy(self.handle, &buf_ptr, &buf_len);
        if(err < 0) {
            return getErrorFromCode(@intCast(err));
        }

        defer if(buf_ptr) |p| free(p);

        if (buf_ptr) |p| {
            const typed_ptr: [*]?*u8 = @alignCast(@ptrCast(p));

            const new_slice = try allocator.alloc(?*u8, buf_len);
            @memcpy(new_slice, typed_ptr[0..buf_len]);

            buffer.* = new_slice;
        } else {
            buffer.* = try allocator.alloc(?*u8, 0);
        }

        return @intCast(err);
    }

    /// Closes the zip archive, releases resources.
    pub fn closeStream(self: *Zip) void {
        c.zip_stream_close(self.handle);
    }
};

//                                //
//                                //
//                                //
//        HELPER FUNCTIONS        //
//                                //
//                                //
//                                //

fn getErrorFromCode(code: i32) ZipError {
    return switch (code) {
        c.ZIP_ENOINIT => ZipError.NotInitialized,
        c.ZIP_EINVENTNAME => ZipError.InvalidEntryName,
        c.ZIP_ENOENT => ZipError.EntryNotFound,
        c.ZIP_EINVMODE => ZipError.InvalidZipMode,
        c.ZIP_EINVLVL => ZipError.InvalidCompressionLevel,
        c.ZIP_ENOSUP64 => ZipError.NoZip64Support,
        c.ZIP_EMEMSET => ZipError.MemsetError,
        c.ZIP_EWRTENT => ZipError.EntryWriteFailure,
        c.ZIP_ETDEFLINIT => ZipError.tdeflCompressorInitializationFailure,
        c.ZIP_EINVIDX => ZipError.InvalidIndex,
        c.ZIP_ENOHDR => ZipError.HeaderNotFound,
        c.ZIP_ETDEFLBUF => ZipError.tdeflFlushFailure,
        c.ZIP_ECRTHDR => ZipError.EntryHeaderCreateFailure,
        c.ZIP_EWRTHDR => ZipError.EntryHeaderWriteFailure,
        c.ZIP_EWRTDIR => ZipError.CentralDirWriteFailure,
        c.ZIP_EOPNFILE => ZipError.FileOpenFailure,
        c.ZIP_EINVENTTYPE => ZipError.InvalidEntryType,
        c.ZIP_EMEMNOALLOC => ZipError.ExtractingDataUsingNoMemoryAllocation,
        c.ZIP_ENOFILE => ZipError.FileNotFound,
        c.ZIP_ENOPERM => ZipError.NoPermission,
        c.ZIP_EOOMEM => ZipError.OutOfMemory,
        c.ZIP_EINVZIPNAME => ZipError.InvalidZipName,
        c.ZIP_EMKDIR => ZipError.MakeDirError,
        c.ZIP_ESYMLINK => ZipError.SymlinkError,
        c.ZIP_ECLSZIP => ZipError.CloseArchiveError,
        c.ZIP_ECAPSIZE => ZipError.CapacitySizeTooSmall,
        c.ZIP_EFSEEK => ZipError.FSeekError,
        c.ZIP_EFREAD => ZipError.FReadError,
        c.ZIP_EFWRITE => ZipError.FWriteError,
        c.ZIP_ERINIT => ZipError.ReaderInitializationFailure,
        c.ZIP_EWINIT => ZipError.WriterInitializationFailure,
        c.ZIP_EWRINIT => ZipError.WriterFromReaderInitializationFailure,
        c.ZIP_EINVAL => ZipError.InvalidArgument,
        c.ZIP_ENORITER => ZipError.ReaderIteratorInitializationFailure,
        c.ZIP_ECHKDIR => ZipError.PathExistsButIsNotDirectory,
        c.ZIP_EPASSWD => ZipError.PasswordFailure,
        else => ZipError.UnknownError,
    };
}

fn getCodeFromError(err: ZipError) i32 {
    return switch (err) {
        ZipError.NotInitialized => c.ZIP_ENOINIT,
        ZipError.InvalidEntryName => c.ZIP_EINVENTNAME,
        ZipError.EntryNotFound => c.ZIP_ENOENT,
        ZipError.InvalidZipMode => c.ZIP_EINVMODE,
        ZipError.InvalidCompressionLevel => c.ZIP_EINVLVL,
        ZipError.NoZip64Support => c.ZIP_ENOSUP64,
        ZipError.MemsetError => c.ZIP_EMEMSET,
        ZipError.EntryWriteFailure => c.ZIP_EWRTENT,
        ZipError.tdeflCompressorInitializationFailure => c.ZIP_ETDEFLINIT,
        ZipError.InvalidIndex => c.ZIP_EINVIDX,
        ZipError.HeaderNotFound => c.ZIP_ENOHDR,
        ZipError.tdeflFlushFailure => c.ZIP_ETDEFLBUF,
        ZipError.EntryHeaderCreateFailure => c.ZIP_ECRTHDR,
        ZipError.EntryHeaderWriteFailure => c.ZIP_EWRTHDR,
        ZipError.CentralDirWriteFailure => c.ZIP_EWRTDIR,
        ZipError.FileOpenFailure => c.ZIP_EOPNFILE,
        ZipError.InvalidEntryType => c.ZIP_EINVENTTYPE,
        ZipError.ExtractingDataUsingNoMemoryAllocation => c.ZIP_EMEMNOALLOC,
        ZipError.FileNotFound => c.ZIP_ENOFILE,
        ZipError.NoPermission => c.ZIP_ENOPERM,
        ZipError.OutOfMemory => c.ZIP_EOOMEM,
        ZipError.InvalidZipName => c.ZIP_EINVZIPNAME,
        ZipError.MakeDirError => c.ZIP_EMKDIR,
        ZipError.SymlinkError => c.ZIP_ESYMLINK,
        ZipError.CloseArchiveError => c.ZIP_ECLSZIP,
        ZipError.CapacitySizeTooSmall => c.ZIP_ECAPSIZE,
        ZipError.FSeekError => c.ZIP_EFSEEK,
        ZipError.FReadError => c.ZIP_EFREAD,
        ZipError.FWriteError => c.ZIP_EFWRITE,
        ZipError.ReaderInitializationFailure => c.ZIP_ERINIT,
        ZipError.WriterInitializationFailure => c.ZIP_EWINIT,
        ZipError.WriterFromReaderInitializationFailure => c.ZIP_EWRINIT,
        ZipError.InvalidArgument => c.ZIP_EINVAL,
        ZipError.ReaderIteratorInitializationFailure => c.ZIP_ENORITER,
        ZipError.PathExistsButIsNotDirectory => c.ZIP_ECHKDIR,
        ZipError.PasswordFailure => c.ZIP_EPASSWD,
        ZipError.UnknownError => -37,
    };
}

fn convertCString(str: [*c]const u8) [:0]const u8 {
    const slice: [:0]const u8 = std.mem.span(str);
    return slice;
}

extern fn free(ptr: ?*anyopaque) void; //libc free for avoiding 
