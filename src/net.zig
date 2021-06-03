const std = @import("std");
const builtin = std.builtin;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

const Neurons = std.ArrayList(Neuron);
const Synapses = std.ArrayList(Synapse);

const print = @import("std").debug.print;

const seed = @import("./seed.zig");

pub const Delay = u3;
pub const Signal = i8;
pub const Ptr = u16; // pointer size in our world;

pub const Net = struct {
    alloc: *Allocator,
    neurons: Neurons,
    synapses: Synapses,

    pub fn init(a: *Allocator) !Net {
        const n = Net{
            .neurons = Neurons.init(a),
            .synapses = Synapses.init(a),
            .alloc = a,
        };
        return n;
    }

    fn print(net: *Net) void {
        for (net.neurons.items) |*n| {
            n.print();
        }
        for (net.synapses.items) |*s| {
            s.print();
        }
    }

    pub fn deinit(net: *Net) void {
        for (net.neurons.items) |*n, i| {
            n.deinit();
        }
        net.neurons.deinit();
        net.synapses.deinit();
    }

    pub fn append(self: *Net, t_min: u8, t_max: u8, r_max: u16) !Ptr {
        const pos = self.neurons.items.len;
        const n = Neuron.init(self.alloc, t_min, t_max, r_max);
        try self.neurons.append(n);
        return @intCast(Ptr, pos);
    }

    pub fn link(self: *Net, left: Ptr, right: Ptr, delay: Delay, signal: Signal) !Ptr {
        const pos = @intCast(Ptr, self.synapses.items.len);
        const s = Synapse.init(delay, signal, right);
        _ = try self.neurons.items[left].targets.append(pos);
        try self.synapses.append(s);
        return pos;
    }

    pub fn process_synapses(self: *Net) void {
        const neurons = self.neurons.items;
        for (self.synapses.items) |*s| {
            s.process(neurons);
        }
    }

    pub fn process_neurons(self: *Net) void {
        const synapses = self.synapses.items;
        for (self.neurons.items) |*n| {
            n.process(synapses);
        }
    }

    pub fn process(self: *Net) void {
        self.process_synapses();
        self.process_neurons();
    }
};

const Neuron = struct {
    const Targets = std.ArrayList(Ptr);

    t_min: u8,
    t_max: u8,
    potential: i16 = 0,
    recovery: u16 = 0,
    recovery_max: u16,
    threshold: u8,
    inbox: i16 = 0,
    fired: bool = false,
    targets: Targets,

    pub fn init(allocator: *Allocator, t_min: u8, t_max: u8, r_max: u16) Neuron {
        return Neuron{
            .threshold = t_min,
            .t_min = t_min,
            .t_max = t_max,
            .recovery_max = r_max,
            .targets = Targets.init(allocator),
        };
    }

    fn print(n: *Neuron) void {
        print("{} {} {} {} {} {} {} {}\n", .{ n.fired, n.t_min, n.threshold, n.t_max, n.potential, n.recovery, n.recovery_max, n.inbox });
    }

    fn deinit(self: *Neuron) void {
        self.targets.deinit();
    }

    fn enqueue(self: *Neuron, signal: i8) void {
        //print("\nbefore={}, signal={}\n", .{ self.inbox, signal });
        self.inbox += signal;
    }

    fn process(n: *Neuron, synapses: []Synapse) void {
        const signal = n.inbox;
        n.inbox = 0;
        if (signal > 0 and n.potential >= 0) {
            n.potential += signal;
        } else if (n.potential > 0) {
            n.potential -= 1;
        } else if (n.potential < 0) {
            n.potential += 1;
        }

        const DROP = -2;
        if (n.potential >= n.threshold) {
            n.potential = DROP;
            n.threshold = min(n.t_max, n.threshold + 1);
            n.recovery = 0;
            n.fired = true;

            for (n.targets.items) |value| {
                synapses[value].enqueue();
            }
        } else {
            n.fired = false;
        }

        if (n.threshold > n.t_min) {
            if (n.recovery >= n.recovery_max) {
                n.threshold -= 1;
                n.recovery = 0;
            } else {
                n.recovery += 1;
            }
        }
    }
};

fn min(a: u8, b: u8) u8 {
    if (a < b) {
        return a;
    }
    return b;
}

const Synapse = struct {
    queue: u8 = 0,
    bit: bool,
    mask: u8,
    signal: i8,
    target: Ptr, //u16

    pub fn init(size: Delay, signal: i8, n: Ptr) Synapse {
        const mask: u8 = ~@as(u8, 0) << size;
        return Synapse{
            .mask = mask,
            .signal = signal,
            .target = n,
            .bit = false,
        };
    }

    pub fn enqueue(s: *Synapse) void {
        s.bit = true;
    }

    fn print(s: *Synapse) void {
        print("{} {} {} {}\n", .{ s.queue, s.signal, s.pointer, s.size });
    }

    fn process(s: *Synapse, neurons: []Neuron) void {
        if (s.bit == true) {
            s.queue |= 1;
            s.bit = false;
        }
        if (s.queue == 0) {
            return;
        }

        s.queue = s.queue << 1;

        if (s.queue & s.mask != 0) {
            s.queue &= ~s.mask;
            neurons[s.target].enqueue(s.signal);
        }
    }
};

test "bits" {
    const n = 3;
    const val = (~@as(u8, 0) << n);
    print("Value: {}\n", .{val});
}

test "sizes" {
    const n_size = @sizeOf(Neuron);

    print("Neuron: {} ({}), Synapse: {} ({})\n", .{
        @sizeOf(Neuron),  @bitSizeOf(Neuron),
        @sizeOf(Synapse), @bitSizeOf(Synapse),
    });
}

test "neuron" {
    var net = try Net.init(std.testing.allocator);
    defer net.deinit();

    var rand = seed.Seed.init();
    const n1 = try net.append(2, 10, 5);
    const n = &net.neurons.items[n1];

    var i: u16 = 0;
    var fired: u16 = 0;

    while (i < 1000) : (i += 1) {
        if (rand.next() % 10 < 5) {
            n.enqueue(1);
        }
        n.process(net.synapses.items);

        if (n.fired) {
            fired += 1;
        }
    }
    try expect(fired == 102);
    print("neuron fired={}\n", .{fired});
}

test "neuron+synapse" {
    var net = try Net.init(std.testing.allocator);
    defer net.deinit();

    var rand = seed.Seed.init();
    const n1 = try net.append(2, 10, 4);
    const n2 = try net.append(2, 10, 4);
    const s1 = try net.link(n1, n2, 2, 2);
    const in = &net.neurons.items[n1];
    const out = &net.neurons.items[n2];

    var i: u16 = 0;
    var fired: u16 = 0;

    while (i < 1000) : (i += 1) {
        if (rand.next() % 10 < 5) {
            in.enqueue(1);
        }
        net.process();

        if (out.fired) {
            fired += 1;
        }
        //n.print();
    }

    print("neuron fired={}\n", .{fired});
    try expect(fired == 111);
}

test "verify network against golden sample (fragile!)" {
    const a = std.testing.allocator;
    const neuron_count = 50;
    const synapse_count = 200;
    const epoch_count = 1000;

    var net = try Net.init(a);
    defer net.deinit();

    var rand = seed.Seed.init();
    var l: u16 = 0;

    while (l < neuron_count) : (l += 1) {
        _ = try net.append(@intCast(u8, l % 3 + 1), @intCast(u8, l % 4 + 5), l % 2 + 1);
    }

    l = 0;
    while (l < synapse_count) : (l += 1) {
        const source = @intCast(Ptr, l % neuron_count);
        const target = @intCast(Ptr, rand.next() % neuron_count);
        const signal = @intCast(Signal, l % 4) - 1;
        const delay = @intCast(Delay, l % 4 + 1);
        const s = try net.link(source, target, delay, signal);
        //net.synapses.items[s].print();
    }

    l = 0;
    var fired: u32 = 0;

    while (l < epoch_count) : (l += 1) {
        for (net.synapses.items[0..10]) |*s| {
            s.enqueue();
        }

        net.process_synapses();
        net.process_neurons();

        for (net.neurons.items) |*n| {
            if (n.fired) {
                fired += 1;
            }
        }

        // print("{} fired={}\n", .{ l, fired });
    }
    try expect(fired == 3044);
    //print("{} fired={}\n", .{ epoch_count, fired });

    //net.print();
}
