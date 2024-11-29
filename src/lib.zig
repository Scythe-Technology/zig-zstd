const std = @import("std");
const c = @import("c");

pub const DEFAULT_COMPRESSION_LEVEL = 3;
pub const MIN_COMPRESSION_LEVEL = -131072;
pub const MAX_COMPRESSION_LEVEL = 22;

// Code based on https://github.com/alichraghi/zstd.zig/blob/ddd1fe82a5157bb65bc815a552bbfb01bb502acf/src/error.zig#L3
pub const Error = error{
    Generic,
    UnknownPrefix,
    UnsupportedVersion,
    UnsupportedFrameParameter,
    TooLargeFrameParameterWindow,
    CorruptionDetected,
    WrongChecksum,
    CorruptedDictionary,
    WrongDictionary,
    DictionaryCreationFailed,
    UnsupportedParameter,
    OutOfBoundsParameter,
    TooLargeTableLog,
    TooLargeMaxSymbolValue,
    TooSmallMaxSymbolValue,
    WrongStage,
    InitMissing,
    OutOfMemory,
    TooSmallWorkspace,
    TooSmallDestSize,
    WrongSrcSize,
    NullDestBuffer,
    NoForwardProgressDestFull,
    NoForwardProgressInputEmpty,
    TooLargeFrameIndex,
    SeekableIO,
    WrongDestBuffer,
    WrongSrcBuffer,
    SequenceProducerFailed,
    InvalidExternalSequences,
    MaxCode,
    UnknownError,
};

pub inline fn isError(code: usize) bool {
    return c.ZSTD_isError(code) != 0;
}

pub fn checkError(code: usize) Error!usize {
    if (isError(code))
        switch (c.ZSTD_getErrorCode(code)) {
            1 => return error.Generic,
            10 => return error.UnknownPrefix,
            12 => return error.UnsupportedVersion,
            14 => return error.UnsupportedFrameParameter,
            16 => return error.TooLargeFrameParameterWindow,
            20 => return error.CorruptionDetected,
            22 => return error.WrongChecksum,
            30 => return error.CorruptedDictionary,
            32 => return error.WrongDictionary,
            34 => return error.DictionaryCreationFailed,
            40 => return error.UnsupportedParameter,
            42 => return error.OutOfBoundsParameter,
            44 => return error.TooLargeTableLog,
            46 => return error.TooLargeMaxSymbolValue,
            48 => return error.TooSmallMaxSymbolValue,
            60 => return error.WrongStage,
            62 => return error.InitMissing,
            64 => return error.OutOfMemory,
            66 => return error.TooSmallWorkspace,
            70 => return error.TooSmallDestSize,
            72 => return error.WrongSrcSize,
            74 => return error.NullDestBuffer,
            80 => return error.NoForwardProgressDestFull,
            82 => return error.NoForwardProgressInputEmpty,
            // following error codes are __NOT STABLE__, they can be removed or changed in future versions
            100 => return error.TooLargeFrameIndex,
            102 => return error.SeekableIO,
            104 => return error.WrongDestBuffer,
            105 => return error.WrongSrcBuffer,
            106 => return error.SequenceProducerFailed,
            107 => return error.InvalidExternalSequences,
            120 => return error.MaxCode,
            else => return error.UnknownError,
        };
    return code;
}

pub fn decompress(dest: []u8, src: []const u8) Error![]const u8 {
    dest[0..try checkError(c.ZSTD_decompress(
        @ptrCast(dest.ptr),
        dest.len,
        @ptrCast(src.ptr),
        src.len,
    ))];
}

pub fn decompressAlloc(allocator: std.mem.Allocator, src: []const u8) Error![]const u8 {
    const size = c.ZSTD_getDecompressedSize(@ptrCast(src.ptr), src.len);
    const dest = try allocator.alloc(u8, @as(usize, @intCast(size)));
    errdefer allocator.free(dest);
    return dest[0..try checkError(c.ZSTD_decompress(
        @ptrCast(dest.ptr),
        dest.len,
        @ptrCast(src.ptr),
        src.len,
    ))];
}

pub fn compress(dest: []u8, src: []const u8, level: i32) Error![]const u8 {
    return dest[0..try checkError(c.ZSTD_compress(
        @ptrCast(dest.ptr),
        dest.len,
        @ptrCast(src.ptr),
        src.len,
        level,
    ))];
}

pub fn compressBound(len: usize) usize {
    return c.ZSTD_compressBound(len);
}

pub fn compressAlloc(allocator: std.mem.Allocator, src: []const u8, level: i32) ![]const u8 {
    const dest = try allocator.alloc(u8, compressBound(src.len));
    errdefer allocator.free(dest);
    const compressed_len = try checkError(c.ZSTD_compress(
        @ptrCast(dest.ptr),
        dest.len,
        @ptrCast(src.ptr),
        src.len,
        level,
    ));
    return try allocator.realloc(dest, compressed_len);
}

test "Compression/Decompression" {
    const allocator = std.testing.allocator;
    const src = "hello, world! hello, world! hello, world! hello, world! hello, world! hello, world!";

    const compressed = try compressAlloc(allocator, src, MAX_COMPRESSION_LEVEL);
    defer allocator.free(compressed);

    try std.testing.expectEqualSlices(u8, &[_]u8{
        40,  181, 47,  253, 32,  83,  181, 0,   0,   120, 104, 101,
        108, 108, 111, 44,  32,  119, 111, 114, 108, 100, 33,  32,
        104, 1,   0,   17,  232, 172, 3,
    }, compressed);

    const decompressed = try decompressAlloc(allocator, compressed);
    defer allocator.free(decompressed);

    try std.testing.expectEqualSlices(u8, src, decompressed);
}
