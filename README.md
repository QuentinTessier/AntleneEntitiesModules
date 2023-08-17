# AntleneEntitiesModules
Kinda like an ECS but with a more compartmentalized approach

Quick Example:

```Zig
const EM = @import("EM.zig");

const PrintModule = struct {
    pub const tag = .printer;
    pub const components = .{
        .name = []const u8,
    };

    pub fn tick(module: *World.ModuleHandle(.printer), deltaTime: f32) void {
        const entities = module.getEntities();
        for (entities) |e| {
            std.log.info("{}:{s}", .{e, module.getComponent(e, .name)});
        }
    }
};

const Modules = EM.Module.EnsureMultiple(.{ PrintModule });

const World = EM.EntitiesModules(Modules, .{});

pub fn main() anyerror!void {

    var allocator = getAllocator(); // Any allocator

    var world = World.init(allocator);
    defer world.deinit();

    var printer_module = world.getModule(.printer);

    var e = try world.createEntity();

    try printer_module.attachEntity(e);
    try printer_module.setComponents(e, .{
        .name = "Bob",
    });

    world.execute(.tick, 1.0);
}

```