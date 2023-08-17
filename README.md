# AntleneEntitiesModules
Kinda like an ECS but with a more compartmentalized approach

Syntax:

Module:

```Zig

const Module = struct {
    [Mandatory Fields]
    pub const tag = .name;
    pub const components = .{
        .component1 = type,
        .component2 = type,
        ...
    };
    [Optional Fields]
    pub const capacity: usize = 10_000;

    [Methods]
    pub fn methodName(anyargs) void {}
};

```