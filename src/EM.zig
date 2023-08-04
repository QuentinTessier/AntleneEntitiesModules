const std = @import("std");

pub const Module = @import("Module.zig");
pub const Query = @import("Query.zig");
const Entities = @import("Entities.zig");
const SparseSetUnmanaged = @import("SparseSet.zig").SparseSetUnmanaged;
const Tuple = @import("Tuple.zig");

pub const Entity = Entities.Handle;
pub const SparseSet = SparseSetUnmanaged(Entity);

// EMS stands for Entities Modules
// Pretty similar to an ECS, but instead of having components in array, we bind modules to entities
// Modules define the components or the data & the systems or the routines
// Module define routines can only operate on their own data by default.
// Modules wide queries are possible

pub const EntityModuleOptions = struct {
    default_maximum_entities: usize = 50_000,
    default_bucket_size: usize = 10_000,

    can_grow: bool = false,
    default_grow_strategy: union {
        default_zig_grow: void,
        fixed_size: usize,
    } = .{ .default_zig_grow = void{} },
};

fn Components(comptime C: anytype) type {
    const fields = std.meta.fields(@TypeOf(C));
    var types: []const type = &[0]type{};
    inline for (fields) |f| {
        const variable: @field(C, f.name) = undefined;
        types = types ++ .{std.ArrayListUnmanaged(@TypeOf(variable))};
    }
    return std.meta.Tuple(types);
}

fn State(comptime M: anytype) type {
    const fields = std.meta.fields(M);
    if (fields.len == 0) {
        return void;
    } else {
        return @Type(.{ .Struct = .{
            .layout = .Auto,
            .is_tuple = false,
            .fields = fields,
            .decls = &[_]std.builtin.Type.Declaration{},
        } });
    }
}

fn BuildNamespacedModule(comptime M: anytype) type {
    const ModuleComponentsTuple = Components(M.components);
    const module_fields = [_]std.builtin.Type.StructField{ .{
        .name = "entitySet",
        .type = SparseSet,
        .default_value = null,
        .is_comptime = false,
        .alignment = @alignOf(SparseSet),
    }, .{
        .name = "components",
        .type = ModuleComponentsTuple,
        .default_value = null,
        .is_comptime = false,
        .alignment = @alignOf(ModuleComponentsTuple),
    }, .{
        .name = "capacity",
        .type = usize,
        .default_value = null,
        .is_comptime = false,
        .alignment = @alignOf(usize),
    }, .{
        .name = "size",
        .type = usize,
        .default_value = null,
        .is_comptime = false,
        .alignment = @alignOf(usize),
    }, .{
        .name = "state",
        .type = State(M),
        .default_value = null,
        .is_comptime = false,
        .alignment = @alignOf(State(M)),
    } };
    return @Type(.{ .Struct = .{
        .layout = .Auto,
        .is_tuple = false,
        .fields = &module_fields,
        .decls = &[_]std.builtin.Type.Declaration{},
    } });
}

fn BuildNamespacedModules(comptime Modules: anytype) type {
    var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
    inline for (Modules) |m| {
        const module_tag = @tagName(m.tag);
        const NamespacedModule = BuildNamespacedModule(m);
        fields = fields ++ [1]std.builtin.Type.StructField{.{
            .name = module_tag,
            .type = NamespacedModule,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(NamespacedModule),
        }};
    }
    return @Type(.{ .Struct = .{
        .layout = .Auto,
        .is_tuple = false,
        .fields = fields,
        .decls = &[_]std.builtin.Type.Declaration{},
    } });
}

pub const Error = error{
    AlreadyAttached,
    NotAttached,
} || std.mem.Allocator.Error;

pub fn EntitiesModules(comptime Modules: anytype, comptime Options: EntityModuleOptions) type {
    return struct {
        const Self = @This();

        const NamespacedModule = BuildNamespacedModules(Modules);

        fn initNamespacedModules(allocator: std.mem.Allocator) !NamespacedModule {
            var modules: NamespacedModule = undefined;
            inline for (std.meta.fields(@TypeOf(Modules))) |f| {
                const module = @field(Modules, f.name);
                const module_tag = @tagName(@field(module, "tag"));
                var NModule = &@field(modules, module_tag);
                const capacity: usize = if (@hasDecl(module, "capacity")) @as(usize, @field(module, "capacity")) else Options.default_bucket_size;
                NModule.entitySet = try SparseSet.init(allocator, capacity, Options.default_maximum_entities);
                inline for (std.meta.fields(@TypeOf(module.components)), 0..) |_, index| {
                    NModule.components[index] = try @TypeOf(NModule.components[index]).initCapacity(allocator, capacity);
                }
                NModule.capacity = capacity;
                NModule.size = 0;
            }
            return modules;
        }

        allocator: std.mem.Allocator,
        entityManager: Entities.Manager(Options.default_maximum_entities),
        modules: NamespacedModule,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .entityManager = try Entities.Manager(Options.default_maximum_entities).init(allocator),
                .modules = try Self.initNamespacedModules(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.entityManager.deinit(self.allocator);
            inline for (std.meta.fields(@TypeOf(Modules))) |f| {
                const mod = @field(Modules, f.name);
                const module_tag = @tagName(@field(mod, "tag"));
                var NModule = @field(self.modules, module_tag);
                NModule.entitySet.deinit(self.allocator);
                inline for (std.meta.fields(@TypeOf(mod.components)), 0..) |_, index| {
                    NModule.components[index].deinit(self.allocator);
                }
            }
        }

        pub fn createEntity(self: *Self) !Entity {
            return self.entityManager.createEntity();
        }

        pub fn destroyEntity(self: *Self, entity: Entity) void {
            return self.entityManager.destroyEntity(entity);
        }

        pub fn getModule(self: *Self, comptime module_tag: anytype) ModuleHandle(module_tag) {
            return .{
                .world = self,
                .internal_handle = &@field(self.modules, @tagName(module_tag)),
            };
        }

        pub fn execute(self: *Self, comptime system_tag: anytype, args: anytype) void {
            inline for (Modules) |m| {
                var module = self.getModule(m.tag);
                module.execute(system_tag, args);
            }
        }

        pub fn ModuleHandle(comptime module_tag: anytype) type {
            return struct {
                const SelfModule = Module.GetOneFromMultiple(Modules, module_tag);
                const ComponentStructure = Module.GetComponentStructure(SelfModule);

                world: *Self,
                internal_handle: *std.meta.FieldType(NamespacedModule, module_tag),

                pub fn getState(self: *ModuleHandle(module_tag)) *State(SelfModule) {
                    return &self.internal_handle.state;
                }

                pub fn attachEntity(self: *ModuleHandle(module_tag), entity: Entity) Error!void {
                    if (self.internal_handle.entitySet.search(entity) != null) {
                        std.log.warn("Trying to attach entity {} but it is already attach to module {s}", .{ entity, @tagName(SelfModule.tag) });
                        return error.AlreadyAttached;
                    }
                    if (self.internal_handle.size >= self.internal_handle.capacity - 1) {
                        try self.grow();
                    }
                    _ = self.internal_handle.entitySet.insert(entity) orelse unreachable;
                    inline for (&self.internal_handle.components) |*c| {
                        c.appendAssumeCapacity(undefined);
                    }
                    self.internal_handle.size += 1;
                }

                pub fn detachEntity(self: *ModuleHandle(module_tag), entity: Entity) Error!void {
                    if (self.internal_handle.entitySet.remove(entity)) |index| {
                        inline for (&self.internal_handle.components) |*c| {
                            _ = c.swapRemove(index);
                        }
                        self.internal_handle.size -= 1;
                    } else {
                        std.log.warn("Trying to detach entity {} but it isn't attached to module {s}", .{ entity, @tagName(SelfModule.tag) });
                        return error.NotAttached;
                    }
                }

                pub fn setComponents(self: *ModuleHandle(module_tag), entity: Entity, data: ComponentStructure) !void {
                    if (self.internal_handle.entitySet.search(entity)) |index| {
                        inline for (std.meta.fields(@TypeOf(data)), 0..) |f, i| {
                            self.internal_handle.components[i].items[index] = @field(data, f.name);
                        }
                    } else {
                        return error.NotAttached;
                    }
                }

                pub fn setComponent(self: *ModuleHandle(module_tag), entity: Entity, comptime component_tag: anytype, data: Module.GetComponentType(SelfModule, component_tag)) !void {
                    if (self.internal_handle.entitySet.search(entity)) |index| {
                        const i = Module.GetComponentIndex(SelfModule, component_tag);
                        self.internal_handle.components[i].items[index] = data;
                    } else {
                        return error.NotAttached;
                    }
                }

                pub fn getComponents(self: *ModuleHandle(module_tag), entity: Entity) ?ComponentStructure {
                    if (self.internal_handle.entitySet.search(entity)) |index| {
                        var data: ComponentStructure = undefined;
                        inline for (std.meta.fields(@TypeOf(data)), 0..) |f, i| {
                            @field(data, f.name) = self.internal_handle.components[i].items[index];
                        }
                        return data;
                    } else {
                        return null;
                    }
                }

                pub fn getComponent(self: *ModuleHandle(module_tag), entity: Entity, comptime component_tag: anytype) ?Module.GetComponentType(SelfModule, component_tag) {
                    if (self.internal_handle.entitySet.search(entity)) |index| {
                        var data: Module.GetComponentType(SelfModule, component_tag) = undefined;
                        const i = Module.GetComponentIndex(SelfModule, component_tag);
                        data = self.internal_handle.components[i].items[index];
                        return data;
                    } else {
                        return null;
                    }
                }

                pub fn getPointer(self: *ModuleHandle(module_tag), entity: Entity, comptime component_tag: anytype) ?*Module.GetComponentType(SelfModule, component_tag) {
                    if (self.internal_handle.entitySet.search(entity)) |index| {
                        const i = Module.GetComponentIndex(SelfModule, component_tag);
                        return &self.internal_handle.components[i].items[index];
                    } else {
                        return null;
                    }
                }

                pub fn getSlice(self: *ModuleHandle(module_tag), comptime component_tag: anytype) []Module.GetComponentType(SelfModule, component_tag) {
                    const index = Module.GetComponentIndex(SelfModule, component_tag);
                    return self.internal_handle.components[index].items[0..self.internal_handle.entitySet.offset];
                }

                fn grow(self: *ModuleHandle(module_tag)) Error!void {
                    if (Options.can_grow) {
                        switch (Options.default_grow_strategy) {
                            .default_zig_grow => {
                                inline for (std.meta.fields(@TypeOf(self.internal_handle.components)), 0..) |_, i| {
                                    _ = try self.internal_handle.components[i].addOne(self.world.allocator);
                                }
                                self.internal_handle.capacity = self.internal_handle.components[0].capacity;
                            },
                            .fixed_size => |capacity_increment| {
                                const new_capacity = self.internal_handle.capacity + capacity_increment;
                                inline for (std.meta.fields(@TypeOf(self.internal_handle.components)), 0..) |_, i| {
                                    try self.internal_handle.components[i].ensureTotalCapacity(self.world.allocator, new_capacity);
                                }
                                self.internal_handle.capacity = new_capacity;
                            },
                        }
                    } else {
                        return error.OutOfMemory;
                    }
                }

                pub fn execute(self: *ModuleHandle(module_tag), comptime system_tag: anytype, args: anytype) void {
                    const args_tuple = Tuple.combine(.{self}, args);
                    if (@hasDecl(SelfModule, @tagName(system_tag))) {
                        const handle = @field(SelfModule, @tagName(system_tag));
                        @call(.auto, handle, args_tuple);
                    } else {
                        @panic("Module of type " ++ @typeName(@TypeOf(SelfModule)) ++ " doesn't define a system with name " ++ @tagName(system_tag));
                    }
                }
            };
        }

        pub fn getMultiModuleEntitySet(self: *Self, comptime tags: []const @TypeOf(.enum_literal)) !MultiModuleEntitySet(tags) {
            var sets: [32]*SparseSet = undefined;
            var count: usize = 0;
            inline for (tags, 0..) |tag, index| {
                var module = self.getModule(tag);
                sets[index] = &module.internal_handle.entitySet;
                count += 1;
            }
            var newSet = try SparseSet.initIntersection(self.allocator, sets[0..count]);
            return MultiModuleEntitySet(tags){
                .world = self,
                .entitySet = newSet,
            };
        }

        pub fn MultiModuleEntitySet(comptime tags: []const @TypeOf(.enum_literal)) type {
            return struct {
                const MultiModuleData = blk: {
                    var types: []const type = &[0]type{};
                    inline for (tags) |tag| {
                        const LocalModule = Module.GetOneFromMultiple(Modules, tag);
                        const LocalModuleComponentStruct = Module.GetComponentStructure(LocalModule);
                        types = types ++ [_]type{LocalModuleComponentStruct};
                    }

                    break :blk struct {
                        entity: Entity,
                        modules: Module.CombineStructure(tags, types),
                    };
                };

                pub const Iterator = struct {
                    world: *Self,
                    internal_iterator: SparseSet.Iterator,

                    pub fn next(self: *Iterator) ?MultiModuleData {
                        if (self.internal_iterator.next()) |entity| {
                            var data: MultiModuleData = undefined;
                            data.entity = entity;
                            inline for (tags) |tag| {
                                var module = self.world.getModule(tag);
                                @field(data.modules, @tagName(tag)) = module.getComponents(entity).?;
                            }
                            return data;
                        } else {
                            return null;
                        }
                    }

                    pub inline fn nextEntity(self: *Iterator) ?Entity {
                        return self.internal_iterator.next();
                    }
                };

                world: *Self,
                entitySet: SparseSet,

                pub fn deinit(self: *MultiModuleEntitySet(tags)) void {
                    self.entitySet.deinit(self.world.allocator);
                }

                pub fn iterator(self: *MultiModuleEntitySet(tags)) Iterator {
                    return Iterator{
                        .world = self.world,
                        .internal_iterator = self.entitySet.iterator(),
                    };
                }
            };
        }
    };
}
