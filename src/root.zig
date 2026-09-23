//! This is the kuba zip zig binding

const std = @import("std");
const c = @import("zip_c.zig");

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

/// Returns the error message associated with a given error.
///
/// **err:** Error to derive message from.
pub fn errorString(err: ZipError) [:0]const u8 {
    const errnum: i32 = getCodeFromError(err) orelse {
        return "Unknown Error";
    };
    return convertCString(c.zip_strerror(errnum));
}

/// Represents a zip archive
///
/// *Created with Zip.open()*
///
/// *When finished, use Zip.close()*
pub const Zip = struct {
    pub const defaultCompressionLevel: i32 = 6;
    handle: *c.struct_zip_t,

    /// opens a zip archive from a given path
    ///
    /// **level:** compression level (0 - 9 are the standard levels)
    ///
    /// **mode:**
    /// - 'r': read.
    /// - 'w': write.
    /// - 'a': append.
    pub fn open(path: [:0]const u8, level: i32, mode: u8) ZipError!Zip {
        var err: i32 = 0;
        const handle = c.zip_openwitherror(path.ptr, level, mode, &err) orelse {
            return getErrorFromCode(err);
        };

        const out: Zip = Zip{
            .handle = handle,
        };
        return out;
    }

    /// opens a zip archive from a given path using a password
    ///
    /// **level:** compression level (0 - 9 are the standard levels)
    ///
    /// **mode:**
    /// - 'r': read.
    /// - 'w': write.
    /// - 'a': append.
    ///
    /// **password** archive password (if null no password is used)
    pub fn openWithPassword(path: [:0]const u8, level: i32, mode: u8, password: ?[:0]const u8) ZipError!Zip {
        var err: i32 = 0;
        const pass_ptr = if (password) |slice| slice.ptr else null;
        const handle = c.zip_open_with_password_and_error(path.ptr, level, mode, pass_ptr, &err) orelse {
            return getErrorFromCode(err);
        };

        const out: Zip = Zip{
            .handle = handle,
        };
        return out;
    }

    /// closes the zip archive.
    pub fn close(self: *Zip) void {
        c.zip_close(self.handle);
    }
};

//helper
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

fn getCodeFromError(err: ZipError) ?i32 {
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
        ZipError.ExtractingDataUsingNoMemoryAllocation, ZipError.FileNotFound => c.ZIP_ENOFILE,
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
        else => null,
    };
}

fn convertCString(str: [*c]const u8) [:0]const u8 {
    const slice: [:0]const u8 = std.mem.span(str);
    return slice;
}
