package gfx

import "base:runtime"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import sdl "vendor:sdl3"

sdl_ensure :: proc "contextless" (
	condition: bool,
	expr := #caller_expression(condition),
	location := #caller_location,
) {
	context = state.ctx

	if !condition {
		log.panicf("Expect true: %s. Error: %s", expr, sdl.GetError(), location = location)
	}
}

@(private)
TEMP_GUARD :: proc {
	TEMP_GUARD_MEM,
	TEMP_GUARD_VIRTUAL,
	TEMP_GUARD_DEFAULT,
}

TEMP_GUARD_DEFAULT :: runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD

@(private, deferred_out = mem.end_arena_temp_memory)
TEMP_GUARD_MEM :: #force_inline proc(arena: ^mem.Arena) -> mem.Arena_Temp_Memory {
	return mem.begin_arena_temp_memory(arena)
}

@(private, deferred_out = vmem.arena_temp_end)
TEMP_GUARD_VIRTUAL :: #force_inline proc(
	arena: ^vmem.Arena,
	location := #caller_location,
) -> (
	vmem.Arena_Temp,
	runtime.Source_Code_Location,
) {
	return vmem.arena_temp_begin(arena, location), location
}
