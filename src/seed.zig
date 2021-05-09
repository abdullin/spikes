//! my custom random. Because I need xplat compatibility and 
//! I'm on a plane to look something up
//!
//!

const std = @import("std");
const assert = std.debug.assert;

pub const Seed = struct {
    a: u32 = 47,
    b: u32 = 105,

    pub fn init() Seed {
        return Seed{};
    }

    pub fn next(self: *Seed) u32 {
        self.a = ((self.a | 1) << 1) ^ self.b;
        self.b = self.a + 47;
        return self.a;
    }
};

test "random seeds" {
    const s = &Seed.init();
    const count = 100;

    var buckets = [_]u16{0} ** count;

    var i: u32 = 0;

    while (i < 100_000) : (i += 1) {
        const curr = s.next();
        buckets[curr % count] += 1;
    }

    assert(buckets[0] == 1021);
    assert(buckets[47] == 1033);
    assert(buckets[99] == 1023);
}
