const std = @import("std");
const nets = @import("net.zig");
const seed = @import("seed.zig");
const time = std.time;
const info = std.log.info;

const Timer = time.Timer;

const fixed = false;

const Allocator = std.mem.Allocator;

pub fn main() anyerror!void {
    //var buffer: [2000000]u8 = undefined;
    //const alloc = &std.heap.FixedBufferAllocator.init(&buffer).allocator;

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = &general_purpose_allocator.allocator;

    const a = alloc;
    const neuron_count = 5_000;
    const synapse_count = 30_000;
    const epoch_count = 100_000;

    var net = try nets.Net.init(a);
    defer net.deinit();

    var rand = seed.Seed.init();
    var l: u16 = 0;

    while (l < neuron_count) : (l += 1) {
        _ = try net.append(@intCast(u8, l % 3 + 1), @intCast(u8, l % 4 + 5), l % 2 + 1);
    }

    l = 0;
    while (l < synapse_count) : (l += 1) {
        const source = @intCast(nets.Ptr, l % neuron_count);
        const target = @intCast(nets.Ptr, rand.next() % neuron_count);
        const signal = @intCast(nets.Signal, l % 4) - 1;
        const delay = @intCast(nets.Delay, l % 4 + 1);
        const s = try net.link(source, target, delay, signal);
        //net.synapses.items[s].print();
    }

    l = 0;
    var fired: u32 = 0;

    const stdout = std.io.getStdOut().writer();
    const timer = try Timer.start();

    var e: u32 = 0;

    while (e < epoch_count) : (e += 1) {
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
    }

    const elapsed = timer.read() / 1000_000;

    try stdout.print("neurons: {}, synapses: {}, epochs: {}, spikes: {}\nrun in {}ms\n", .{
        neuron_count, synapse_count, epoch_count,

        fired,        elapsed,
    });
}
