package gfx

import "base:runtime"

import sdl "vendor:sdl3"

state: struct {
	ctx:        runtime.Context,
	window:     ^sdl.Window,
	gpu_device: ^sdl.GPUDevice,
}

init :: proc() -> bool {
	return sdl.Init({.VIDEO})
}

deinit :: proc() {

}

init_imgui :: proc() -> bool {
	return true
}

deinit_imgui :: proc() {

}
