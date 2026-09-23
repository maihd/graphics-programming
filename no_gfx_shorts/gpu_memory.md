# GPU Memory Allocations
New hardware support CPU can be fast to read/write memory from pointer (like OS virtual memory):
- Unified Memory Architecture
- PCIe Resizable BAR

## C-like API
Inspired from CUDA memory allocating.
```C
uint32_t* numbers = gpu_malloc(1024 * sizeof(uint32_t));

for (int i = 0; i < 1024; i++)
{
    numbers[i] = random();
}

gpu_free(numbers);
```

## Odin-like API
```Odin
numbers := gpu.make([]u32, 1024)
for &number in numbers {
    number^ = random()
}
gpu.delete(numbers)
```

## Allocator & Arena
Code from no_gfx repo:
```Odin
// Arena should only use for tempory, thread-local allocations
arena := gpu.arena_create()
defer gpu.arena_destroy(&arena)

verts := gpu.arena_alloc(&arena, Vertex, 3) // []Vertex
indices := gpu.arena_alloc(&arena, u32, 3)  // []u32

// Local to GPU, only GPU can read this memory
verts_local := gpu.mem_alloc(Vertex, 3, .GPU)
defer gpu.mem_free(verts_local)

indices_local := gpu.mem_alloc(u32, 3. GPU)
defer gpu.mem_free(indices_local)
```