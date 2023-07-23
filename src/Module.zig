const std = @import("std");

pub fn Ensure(comptime M: anytype) type {
    if (@hasDecl(M, "tag")) {
        _ = @tagName(M.tag);
    } else {
        @panic("Module " ++ @typeName(@TypeOf(M)) ++ " must contain a declaration of 'tag' like this 'pub const tag = .some_tag;'");
    }

    if (@hasDecl(M, "components")) {
        _ = @tagName(M.tag);
    } else {
        @panic("Module " ++ @typeName(@TypeOf(M)) ++ " must contain a declaration of 'tag' like this 'pub const components = .{ .comp1 = f32, .comp2 = SomeType };'");
    }
    return M;
}

pub fn EnsureMultiple(comptime Modules: anytype) @TypeOf(Modules) {
    inline for (Modules) |m| _ = Ensure(m);
    return Modules;
}

pub fn GetTypeOfOneFromMultiple(comptime Modules: anytype, comptime tag: anytype) type {
    inline for (Modules) |m| {
        if (m.tag == tag) {
            return @TypeOf(m);
        }
    }
    @panic("Couldn't fond Module with tag " ++ @tagName(tag) ++ " in " ++ @typeName(@TypeOf(Modules)));
}

pub fn GetOneFromMultiple(comptime Modules: anytype, comptime tag: anytype) GetTypeOfOneFromMultiple(Modules, tag) {
    inline for (Modules) |m| {
        if (m.tag == tag) {
            return m;
        }
    }
    @panic("Couldn't fond Module with tag " ++ @tagName(tag) ++ " in " ++ @typeName(@TypeOf(Modules)));
}

pub fn GetComponentType(comptime M: anytype, comptime tag: anytype) type {
    inline for (std.meta.fields(@TypeOf(M.components))) |c| {
        if (std.mem.eql(u8, c.name, @tagName(tag))) {
            const v: @field(M.components, c.name) = undefined;
            return @TypeOf(v);
        }
    }
    @panic("Couldn't find component with tag " ++ @tagName(tag) ++ " in module " ++ @typeName(@TypeOf(M)));
}

pub fn GetComponentStructure(comptime M: anytype) type {
    var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
    inline for (std.meta.fields(@TypeOf(M.components))) |c| {
        const v: @field(M.components, c.name) = undefined;
        fields = fields ++ [_]std.builtin.Type.StructField{.{
            .name = c.name,
            .type = @TypeOf(v),
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(@TypeOf(v)),
        }};
    }
    return @Type(.{ .Struct = .{
        .layout = .Auto,
        .is_tuple = false,
        .fields = fields,
        .decls = &[_]std.builtin.Type.Declaration{},
    } });
}

pub fn CombineStructure(comptime tag: []const @TypeOf(.enum_literal), comptime T: []const type) type {
    if (tag.len != T.len) @panic("The 2 given array must be of the same size");
    var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
    inline for (tag, 0..) |t, index| {
        fields = fields ++ [_]std.builtin.Type.StructField{.{
            .name = @tagName(t),
            .type = T[index],
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(T[index]),
        }};
    }
    return @Type(.{ .Struct = .{
        .layout = .Auto,
        .is_tuple = false,
        .fields = fields,
        .decls = &[_]std.builtin.Type.Declaration{},
    } });
}

pub fn GetComponentIndex(comptime M: anytype, comptime tag: anytype) comptime_int {
    const index = std.meta.fieldIndex(@TypeOf(M.components), @tagName(tag)) orelse @panic("Module of type " ++ @typeName(M) ++ " does not contain component " ++ @tagName(tag));
    return index;
}
