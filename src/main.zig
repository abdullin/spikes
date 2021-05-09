const std = @import("std");

const Synapse = struct {
    queue: u32,
    signal: u8,
    pointer: u8,
    size: u8,
    target: *Neuron,
};

const info = std.log.info;
const ArrayList = std.ArrayList;
const NeuronList = ArrayList(Neuron);

const Cleft = struct {
    target: *Neuron,
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = &gpa.allocator;

    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            info("leak detected!", .{});
        }
    }

    var neurons = NeuronList.init(alloc);

    try neurons.append();

    defer neurons.deinit();

    info("All your codebase are belong to us.", .{});
}
