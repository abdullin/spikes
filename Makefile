.PHONY: stat

zig-out/bin/spikes:
	zig build -Drelease-fast=true


stat: zig-out/bin/spikes
	perf stat -B -e r412e,LLC-loads,LLC-stores,LLC-prefetches,cache-references,cache-misses,cycles,stalled-cycles-frontend,stalled-cycles-backend,instructions,branches,branch-misses,faults,migrations zig-out/bin/spikes
