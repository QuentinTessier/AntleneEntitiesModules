const std = @import("std");

pub const Handle = u32;

pub const Error = error{
    FailedToCreateEntity,
};

pub fn Manager(comptime MaxEntities: usize) type {
    return struct {
        const Self = @This();
        availableEntities: std.ArrayListUnmanaged(Handle) = .{},

        pub fn init(allocator: std.mem.Allocator) !Self {
            var entities = try std.ArrayListUnmanaged(Handle).initCapacity(allocator, MaxEntities);
            var i: usize = 0;
            while (i < MaxEntities) : (i += 1) {
                entities.appendAssumeCapacity(@intCast(i));
            }
            return Self{
                .availableEntities = entities,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.availableEntities.deinit(allocator);
        }

        pub fn createEntity(self: *Self) Error!Handle {
            if (self.availableEntities.items.len == 0) {
                return error.FailedToCreateEntity;
            }
            return self.availableEntities.orderedRemove(0);
        }

        pub fn destroyEntity(self: *Self, entity: Handle) void {
            self.availableEntities.appendAssumeCapacity(entity);
        }
    };
}
