const std = @import("std");

const indirect = @import("indirect").indirect;

pub fn name() !void {
    const result = indirect();
    std.debug.print("Result: {}\n", .{result});
    if (result != 42) {
        return error.UnexpectedResult;
    }
}

test "indirect dependency from C works" {
    std.testing.expectEqual(42, indirect());
}
