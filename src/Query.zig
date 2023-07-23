const std = @import("std");

pub fn Ensure(comptime Query: anytype) type {
    if (!@hasDecl(Query, "filters")) {
        @panic("Query " ++ @typeName(@TypeOf(Query)) ++ " must contain a declaration of 'filters' like this 'pub const filters = struct { Filter(.{...})};'");
    }
    return Query;
}

pub fn Filter(comptime F: anytype) @TypeOf(F) {
    const FType = @TypeOf(F);
    if (!@hasField(FType, "module")) {
        @panic("Filter " ++ @typeName(@TypeOf(F)) ++ " must contain a declaration of 'module' like this 'pub const module = .target_module;'");
    }
    if (@hasField(FType, "targets")) {
        inline for (F.targets) |target| {
            if (!@hasField(@TypeOf(target), "tag")) {
                @panic("Filter " ++ @typeName(FType) ++ " invalid filter definition: .{ .tag = .tag }");
            }
        }
    } else {
        @panic("Filter " ++ @typeName(FType) ++ " must contain a declaration of 'targets': pub fn filters = .{ ... }");
    }
    return F;
}
