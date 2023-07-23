const std = @import("std");

pub fn SparseSetUnmanaged(comptime IntType: type) type {
    if (@typeInfo(IntType) != .Int) {
        @compileError("SparseSet store ints");
    }

    return struct {
        pub const Iterator = struct {
            items: []const IntType,

            pub fn next(self: *Iterator) ?IntType {
                if (self.items.len == 0) return null;

                var val = self.items[0];
                self.items = self.items[1..];
                return val;
            }
        };

        const Self = @This();

        sparse: []IntType = undefined,
        dense: []IntType = undefined,

        offset: usize = 0,
        capacity: usize = 0,
        maxValue: IntType = 0,

        pub fn init(allocator: std.mem.Allocator, capacity: usize, maxValue: IntType) !Self {
            var sparse = try allocator.alloc(IntType, maxValue + 1);
            var dense = try allocator.alloc(IntType, capacity);
            return Self{
                .sparse = sparse,
                .dense = dense,
                .capacity = capacity,
                .maxValue = maxValue,
            };
        }

        pub fn grow(self: *Self, allocator: std.mem.Allocator, new_capacity: usize) !void {
            self.sparse = try allocator.realloc(self.sparse, new_capacity);
            self.dense = try allocator.realloc(self.dense, new_capacity);
            self.capacity = new_capacity;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.sparse);
            allocator.free(self.dense);
        }

        pub fn clear(self: *Self) void {
            self.offset = 0;
        }

        pub fn search(self: *const Self, x: IntType) ?IntType {
            if (x > self.maxValue) return null;

            if (self.sparse[x] < self.offset and self.dense[self.sparse[x]] == x)
                return self.sparse[x];
            return null;
        }

        pub fn insert(self: *Self, x: IntType) ?IntType {
            if (x > self.maxValue or self.offset >= self.capacity or self.search(x) != null) return null;

            self.dense[self.offset] = x;
            self.sparse[x] = @intCast(self.offset);
            self.offset += 1;
            return self.sparse[x];
        }

        pub fn remove(self: *Self, x: IntType) ?IntType {
            if (self.search(x) == null) return null;

            const index = self.sparse[x];
            const temp: IntType = self.dense[self.offset - 1];
            self.dense[self.sparse[x]] = temp;
            self.sparse[temp] = self.sparse[x];
            self.offset -= 1;
            return index;
        }

        pub fn dump(self: *const Self) void {
            const slice = self.dense[0..self.offset];
            for (slice) |value| {
                std.debug.print("{} => {}\n", .{ value, self.search(value).? });
            }
        }

        pub fn getIntersection(allocator: std.mem.Allocator, sets: []const *Self) !Self {
            const cap = blk: {
                var capacity: usize = sets[0].capacity;
                for (sets[1..]) |set| {
                    capacity = @min(capacity, set.capacity);
                }
                break :blk capacity;
            };
            const max = blk: {
                var maxValue: IntType = sets[0].maxValue;
                for (sets[1..]) |set| {
                    maxValue = @max(maxValue, set.maxValue);
                }
                break :blk maxValue;
            };
            var res = try Self.init(allocator, cap, max);

            for (sets[0].dense[0..sets[0].offset]) |value| {
                for (sets[1..]) |set| {
                    if (set.search(value) != null) {
                        _ = res.insert(value);
                    }
                }
            }
            return res;
        }

        pub fn implaceIntersection(self: *Self, allocator: std.mem.Allocator, others: []const *Self) !void {
            self.clear();
            var expected_capacity: usize = std.math.maxInt(usize);
            var exepected_maxValue: IntType = self.maxValue;
            for (others) |set| {
                expected_capacity = @min(expected_capacity, set.capacity);
                exepected_maxValue = @max(exepected_maxValue, set.maxValue);
            }
            if (self.capacity < expected_capacity) {
                self.dense = try allocator.realloc(self.dense, expected_capacity);
                self.sparse = try allocator.realloc(self.sparse, exepected_maxValue + 1);
            }

            for (others) |set| {
                for (set.dense[0..set.offset]) |item| {
                    if (self.search(item) != null)
                        _ = self.insert(item);
                }
            }
        }

        pub fn getUnion(self: *const Self, allocator: std.mem.Allocator, other: *const Self) !Self {
            const cap = self.offset + other.offset;
            const max = @max(self.maxValue, other.maxValue);
            var res = try Self.init(allocator, cap, max);
            for (self.dense[0..self.offset]) |v| {
                res.insert(v);
            }
            for (other.dense[0..other.offset]) |v| {
                res.insert(v);
            }
            return res;
        }

        pub fn iterator(self: *Self) Iterator {
            return .{ .items = self.dense[0..self.offset] };
        }
    };
}
