const std = @import("std");

pub fn CombinedTuple(comptime T1: type, comptime T2: type) type {
    var list: []const type = &[0]type{};
    inline for (std.meta.fields(T1)) |t1| {
        list = list ++ [_]type{t1.type};
    }
    inline for (std.meta.fields(T2)) |t2| {
        list = list ++ [_]type{t2.type};
    }
    return std.meta.Tuple(list);
}

pub fn combine(T1: anytype, T2: anytype) CombinedTuple(@TypeOf(T1), @TypeOf(T2)) {
    var T: CombinedTuple(@TypeOf(T1), @TypeOf(T2)) = undefined;
    const length = std.meta.fields(@TypeOf(T1)).len;
    inline for (T1, 0..) |t1, index| {
        T[index] = t1;
    }
    inline for (T2, 0..) |t2, index| {
        T[index + length] = t2;
    }
    return T;
}
