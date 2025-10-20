package sdl3_gpu_sample

import shadercross "../sdl_shadercross"
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

	gpu_device := sdl.CreateGPUDevice({.SPIRV, .MSL}, true, nil)
	if gpu_device == nil || !sdl.ClaimWindowForGPUDevice(gpu_device, window) {
		log_error("Failed to create GPU Device: %s", sdl.GetError())
		return
	}

	close: bool
	event: sdl.Event
	for !close {
		// Handle events
		for sdl.PollEvent(&event) {
			if event.type == .QUIT {
				close = true
			}
		}

		// Setup command buffer
		command_buffer := sdl.AcquireGPUCommandBuffer(gpu_device)

		swapchain_texture: ^sdl.GPUTexture
		width, height: u32
		if !sdl.WaitAndAcquireGPUSwapchainTexture(
			command_buffer,
			window,
			&swapchain_texture,
			&width,
			&height,
		) {
			// Command buffer must be always submitted
			_ = sdl.SubmitGPUCommandBuffer(command_buffer)

			// Skip this frame
			continue
		}

		// Unlike OpenGL, we must setup screen buffer by own self
		// In modern graphics programming, they are called Swapchain and Swapchain Texture
		// Swapchain does not know how to present the colors, we need setup its
		// Now you see, Screen Buffer is texture have some specified configs to present colors to the screen

		// The color config for the screen, SDL3 GPU called SDL_GPUColorTarget
		color_target_info := sdl.GPUColorTargetInfo {
			clear_color = {1.0, 0.5, 0.25, 1.0}, // SDL_FColor
			load_op     = .LOAD,
			store_op    = .STORE,
			texture     = swapchain_texture,
		}

		// GPU API need to support multi pass for performance
		// We have SDL_GPURenderPass for rendering
		render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)
		if render_pass == nil { 	// We cant make sure command_buffer is always ready for a pass
			// Command buffer must be always submitted
			_ = sdl.SubmitGPUCommandBuffer(command_buffer)

			// Skip this frame
			continue
		}

		// Complete setup the render pass
		sdl.EndGPURenderPass(render_pass)

		// Complete command, submit its to GPU
		_ = sdl.SubmitGPUCommandBuffer(command_buffer)
	}
}
