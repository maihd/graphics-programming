package sdl3_gpu_sample

import "core:fmt"
import sdl "vendor:sdl3"

log :: fmt.printfln
log_error :: fmt.eprintfln

main :: proc() {
	log("Graphics Programming with Odin and SDL3 GPU")

	if !sdl.Init({.VIDEO}) {
		log_error("Failed to initialized SDL3: %s", sdl.GetError())
		return
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("Odin SDL3 GPU", 800, 600, {})
	if window == nil {
		log_error("Failed to create window: %s", sdl.GetError())
		return
	}
	defer sdl.DestroyWindow(window)

	close: bool
	event: sdl.Event
	for !close {
		for sdl.PollEvent(&event) {
			if event.type == .QUIT {
				close = true
			}
		}
	}
}
