package gfx

import "base:runtime"
import "core:log"
import "core:mem"
import "core:strings"

import sdl "vendor:sdl3"

state: struct {
	ctx:                runtime.Context,
	logger:             log.Logger,
	tracking_allocator: mem.Tracking_Allocator,
	window:             ^sdl.Window,
	gpu_device:         ^sdl.GPUDevice,
}

Window_Options :: struct {
	title:  string,
	width:  i32,
	height: i32,
}

init :: proc(options: Window_Options) -> bool {
	TEMP_GUARD()

	// Logger

	state.logger = log.create_console_logger()
	context.logger = state.logger

	// Tracking memory

	mem.tracking_allocator_init(&state.tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&state.tracking_allocator)

	state.ctx = context

	// Initialize

	if !sdl.Init({.VIDEO}) {
		return false
	}

	title_cstr := strings.clone_to_cstring(options.title, context.temp_allocator)
	state.window = sdl.CreateWindow(title_cstr, options.width, options.height, {})
	sdl_ensure(state.window != nil)

	state.gpu_device = sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, ODIN_DEBUG, nil)
	sdl_ensure(state.gpu_device != nil)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(state.gpu_device, state.window))

	log_gpu_specs()
	return true
}

deinit :: proc() {
	sdl.ReleaseWindowFromGPUDevice(state.gpu_device, state.window)
	sdl.DestroyGPUDevice(state.gpu_device)
	sdl.DestroyWindow(state.window)
	sdl.Quit()

	// Memory Tracking
	if len(state.tracking_allocator.allocation_map) > 0 {
		log.errorf(
			"=== %v allocation are unfreed: ===",
			len(state.tracking_allocator.allocation_map),
		)
		for _, entry in state.tracking_allocator.allocation_map {
			log.errorf(" - %v bytes @ %v", entry.size, entry.location)
		}
	}

	if len(state.tracking_allocator.bad_free_array) > 0 {
		log.errorf("=== %v bad frees happened: ===")
		for entry in state.tracking_allocator.bad_free_array {
			log.errorf(" - %p @ %v", entry.memory, entry.location)
		}
	}

	// Logger
	log.destroy_console_logger(state.logger)

	state = {}
}

init_imgui :: proc() -> bool {
	return true
}

deinit_imgui :: proc() {

}

log_gpu_specs :: proc() -> (res: bool) {


	return
}
