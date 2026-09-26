package gfx

import "base:runtime"
import "core:c/libc"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import "core:sync"

// ALIGNMENT :: 16
// CACHELINE :: 64

POOL_SIZES := [?]int{16, 32, 64, 128, 256, 512}
POOL_BLOCKS_PER_CHUNK :: 256

Pool_Node :: struct {
	next: ^Pool_Node,
}

Pool_Header :: struct {
	size:    int,
	address: rawptr,
}

Pool_Class :: struct {
	block_size: int,
	free_list:  ^Pool_Node,
	chunks:     int,
}

Pool :: struct {
	// backing: mem.Allocator,
	backing: vmem.Arena,
	classes: [len(POOL_SIZES)]Pool_Class,
}

pool_init :: proc(p: ^Pool) {
	err := vmem.arena_init_growing(&p.backing)
	if err != nil {
		log.panicf("Failed to initialize p.backing. Error: %v", err)
	}
	// p.backing = runtime.default_allocator()

	for size, i in POOL_SIZES {
		p.classes[i].block_size = size
	}
}

pool_deinit :: proc(p: ^Pool) {
	vmem.arena_destroy(&p.backing)

}

pool_class :: proc(#any_int size: int) -> int {
	for bs, i in POOL_SIZES {
		if size <= bs {
			return i
		}
	}

	return -1
}

pool_alloc :: proc(p: ^Pool, size: int) -> rawptr {
	ci := pool_class(size + size_of(Pool_Header))
	if ci < 0 {
		return nil
	}

	class := &p.classes[ci]
	if class.free_list == nil {
		// chunk, err := vmem.arena_alloc(
		// 	&p.backing,
		// 	uint(class.block_size * POOL_BLOCKS_PER_CHUNK),
		// 	uint(POOL_SIZES[ci]),
		// )
		// chunk, err := mem.alloc(
		// 	int(class.block_size * POOL_BLOCKS_PER_CHUNK),
		// 	int(POOL_SIZES[ci]),
		// 	allocator = p.backing,
		// )
		// if err != nil {
		// 	return nil
		// }
		chunk := libc.malloc(uint(class.block_size * POOL_BLOCKS_PER_CHUNK))

		// base := raw_data(chunk)
		base := chunk
		for i in 0 ..< POOL_BLOCKS_PER_CHUNK {
			node := cast(^Pool_Node)(uintptr(base) + uintptr(i * class.block_size))
			node.next = class.free_list
			class.free_list = node
		}

		class.chunks += 1
	}

	node := class.free_list
	class.free_list = node.next

	header := cast(^Pool_Header)node
	header.size = size + size_of(Pool_Header)
	header.address = node

	// log.debugf(
	// 	"node = %p, header = %p, result = %p",
	// 	node,
	// 	header,
	// 	rawptr(uintptr(header) + size_of(Pool_Header)),
	// )

	return rawptr(uintptr(header) + size_of(Pool_Header))
}

pool_free :: proc(p: ^Pool, ptr: rawptr) -> bool {
	free: if ptr != nil {
		header := cast(^Pool_Header)(uintptr(ptr) - size_of(Pool_Header))
		if header.size <= 0 {
			break free
		}

		ci := pool_class(header.size)
		if ci >= 0 {
			node := cast(^Pool_Node)header.address
			node.next = p.classes[ci].free_list
			p.classes[ci].free_list = node
			return true
		}
	}

	return false
}

pool_resize :: proc(p: ^Pool, ptr: rawptr, new_size: int) -> rawptr {
	resize: if ptr != nil {
		header := cast(^Pool_Header)(uintptr(ptr) - size_of(Pool_Header))
		if header.size <= 0 {
			break resize
		}

		old_ci := pool_class(header.size)
		new_ci := pool_class(new_size + size_of(Pool_Header))

		if old_ci >= 0 && new_ci > old_ci {
			new_data := pool_alloc(p, new_size)
			mem.copy(new_data, ptr, header.size - size_of(Pool_Header))

			old_node := cast(^Pool_Node)header.address
			old_node.next = p.classes[old_ci].free_list
			p.classes[old_ci].free_list = old_node

			return new_data
		}
	}

	return pool_alloc(p, new_size)
}
