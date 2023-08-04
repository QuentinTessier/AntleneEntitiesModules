const std = @import("std");
const EM = @import("EM.zig");

const TestModule = EM.Module.Ensure(struct {
    stateVariable: f32,

    pub const tag = .test_module;
    pub const components = .{ .c1 = u32, .c2 = f32 };
});

const TestModule2 = EM.Module.Ensure(struct {
    pub const tag = .test_module2;
    pub const components = .{ .c3 = u32, .c4 = f32 };
});

const TestModule3 = EM.Module.Ensure(struct {
    pub const tag = .test_module3;
    pub const components = .{ .c5 = u32, .c6 = f32 };
});

const Modules = EM.Module.EnsureMultiple(.{ TestModule, TestModule2, TestModule3 });

const World = EM.EntitiesModules(Modules, .{});

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var em = try World.init(allocator);
    defer em.deinit();

    var m1 = em.getModule(.test_module);
    var m2 = em.getModule(.test_module2);
    var m3 = em.getModule(.test_module3);

    var m1State = m1.getState();
    m1State.stateVariable = @as(f32, 1.01);

    var i: usize = 0;
    while (i < 500) : (i += 1) {
        var e = try em.createEntity();

        try m1.attachEntity(e);
        try m1.setComponents(e, .{
            .c1 = @intCast(i),
            .c2 = 1.0,
        });

        if (i > 250) {
            try m2.attachEntity(e);
            try m2.setComponents(e, .{
                .c3 = @intCast(i),
                .c4 = 1.0,
            });
        }

        if (i > 490) {
            try m3.attachEntity(e);
            try m3.setComponents(e, .{
                .c5 = @as(u8, 1),
                .c6 = 1.0,
            });
        }
    }

    var s = try em.getMultiModuleEntitySet(&.{ .test_module, .test_module2, .test_module3 });
    defer s.deinit();

    var ite = s.iterator();
    while (ite.next()) |data| {
        std.debug.print("{} : {}\n", .{ data.entity, data.modules });
    }
}

test "Simple World with 1 module" {
    const allocator = std.testing.allocator;
    const m1 = struct {
        pub const tag = .m1;
        pub const components = .{ .c1 = u32 };
    };

    const W = EM.EntitiesModules(EM.Module.EnsureMultiple(.{m1}), .{});

    var em = try W.init(allocator);
    defer em.deinit();

    var m = em.getModule(.m1);

    try m.attachEntity(0);
    try m.setComponent(0, .c1, 1);
    try m.attachEntity(1);
    try m.setComponent(1, .c1, 2);
    try m.attachEntity(2);
    try m.setComponent(2, .c1, 3);

    const slice = m.getSlice(.c1);

    try std.testing.expect(std.mem.eql(u32, &[3]u32{ 1, 2, 3 }, slice));
}
