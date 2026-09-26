package gfx

import "base:runtime"
import "core:c"
import "core:c/libc"
import "core:log"
import "core:mem"
import "core:strings"

import sdl "vendor:sdl3"

state: struct {
	ctx:                runtime.Context,
	logger:             log.Logger,
	pool:               Pool,
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

	pool_init(&state.pool)

	// Logger

	state.logger = log.create_console_logger(opt = {.Level, .Time})
	context.logger = state.logger

	log.infof("=== gfx.init() ===")
	log.infof("1. Setup logger")

	// Tracking memory

	log.infof("2. Setup tracking allocator")

	mem.tracking_allocator_init(&state.tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&state.tracking_allocator)

	state.ctx = context

	// Initialize

	log.infof("3. Initalize SDL3 runtime")

	when GFX_USE_CUSTOM_SDL3_ALLOCATOR {
		sdl.SetMemoryFunctions(sdl_malloc, sdl_calloc, sdl_realloc, sdl_free)
	}

	if !sdl.Init({.VIDEO, .EVENTS}) {
		return false
	}

	log.infof("4. Create window: %v", options)
	title_cstr := strings.clone_to_cstring(options.title, context.temp_allocator)
	state.window = sdl.CreateWindow(title_cstr, options.width, options.height, {})
	sdl_ensure(state.window != nil)

	log.infof("5. Create GPU device")

	state.gpu_device = sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, ODIN_DEBUG, nil)
	sdl_ensure(state.gpu_device != nil)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(state.gpu_device, state.window))

	log_gpu_specs()

	log.infof("=== gfx.init() finished ===")
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

	// Destroy pool
	pool_deinit(&state.pool)

	state = {}
}

init_imgui :: proc() -> bool {
	return true
}

deinit_imgui :: proc() {

}

log_gpu_specs :: proc(gpu_device: ^sdl.GPUDevice = state.gpu_device) -> (res: bool = true) {
	gpu_device_props := sdl.GetGPUDeviceProperties(gpu_device)
	gpu_device_name := sdl.GetStringProperty(gpu_device_props, sdl.PROP_GPU_DEVICE_NAME_STRING, "")
	gpu_device_driver := sdl.GetStringProperty(
		gpu_device_props,
		sdl.PROP_GPU_DEVICE_DRIVER_NAME_STRING,
		"<unspecified>",
	)
	gpu_device_driver_info := sdl.GetStringProperty(
		gpu_device_props,
		sdl.PROP_GPU_DEVICE_DRIVER_INFO_STRING,
		"<unspecified>",
	)
	gpu_device_driver_version := sdl.GetStringProperty(
		gpu_device_props,
		sdl.PROP_GPU_DEVICE_DRIVER_VERSION_STRING,
		"<unspecified>",
	)

	log.infof("GPU Device Specs:")
	log.infof(" - GPU Device: %s", gpu_device_name)
	log.infof(" - GPU Driver: %s", gpu_device_driver)
	log.infof(" - GPU Driver Info: %s", gpu_device_driver_info)
	log.infof(" - GPU Driver Version: %s", gpu_device_driver_version)
	log.infof(" - Graphics API Backend: %s", sdl.GetGPUDeviceDriver(gpu_device))
	log.infof(" - Graphics API ShaderFormat: %v", sdl.GetGPUShaderFormats(gpu_device))

	return
}

// SDL3 Memory Allocator

GFX_USE_CUSTOM_SDL3_ALLOCATOR :: #config(GFX_USE_CUSTOM_SDL3_ALLOCATOR, false)

when GFX_USE_CUSTOM_SDL3_ALLOCATOR {
	sdl_malloc :: proc "c" (size: uint) -> rawptr {
		// context = state.ctx
		context = runtime.default_context()

		// log.debugf("Calling sdl_malloc size: %v", size)

		pool_data := pool_alloc(&state.pool, int(size))
		if pool_data != nil {
			return pool_data
		}

		// data, err := mem.alloc(int(size), allocator = context.allocator)
		// if err != .None {
		// 	log.panicf("sdl_malloc failed. Error: %v", err)
		// }
		// return data

		return libc.malloc(size)
	}

	sdl_calloc :: proc "c" (nmemb, size: uint) -> rawptr {
		data := sdl_malloc(nmemb * size)
		mem.set(data, 0, int(size))
		return data
	}

	sdl_realloc :: proc "c" (ptr: rawptr, size: uint) -> rawptr {
		// context = state.ctx
		context = runtime.default_context()

		pool_data := pool_resize(&state.pool, ptr, int(size))
		if pool_data != nil {
			return pool_data
		}

		// data, err := mem.resize(ptr, 0, int(size), allocator = context.allocator)
		// if err != .None {
		// 	log.panicf("sdl_realloc failed. Error: %v", err)
		// }

		// mem.set(data, 0, int(size))
		// return data

		return libc.realloc(ptr, size)
	}

	sdl_free :: proc "c" (ptr: rawptr) {
		// context = state.ctx
		context = runtime.default_context()

		if pool_free(&state.pool, ptr) {
			return
		}

		// mem.free(ptr, allocator = context.allocator)
		libc.free(ptr)
	}
}
