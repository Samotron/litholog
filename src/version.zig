const std = @import("std");

pub const VERSION = std.SemanticVersion{
    .major = 0,
    .minor = 0,
    .patch = 4,
};

pub const VERSION_STRING = "0.0.4";

// Export for C bindings
export fn litholog_version_major() u32 {
    return VERSION.major;
}

export fn litholog_version_minor() u32 {
    return VERSION.minor;
}

export fn litholog_version_patch() u32 {
    return VERSION.patch;
}

export fn litholog_version_string() [*:0]const u8 {
    return VERSION_STRING;
}
