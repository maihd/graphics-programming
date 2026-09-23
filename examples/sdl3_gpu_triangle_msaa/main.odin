package sdl3_gpu_triangle_msaa

import "core:fmt"

import sdl "vendor:sdl3"

VERT_SHADER :: #load(#directory + "RawTriangle.vert.dxil")
FRAG_SHADER :: #load(#directory + "SolidColor.frag.dxil")

create_shader :: proc(
	gpu_device: ^sdl.GPUDevice,
	src: []u8,
) -> (
	_shader: ^sdl.GPUShader,
	_ok: bool,
) #optional_ok {
	_shader = sdl.CreateGPUShader(
		gpu_device,
		{
			code = raw_data(src),
			code_size = len(src),
			entrypoint = "main",
			format = {.DXIL},
			stage = .VERTEX,
		},
	)
	_ok = _shader != nil

	return
}

main :: proc() {
	fmt.printfln("SDL GPU Triangle MSAA")

	if !sdl.Init({.VIDEO}) {
		fmt.panicf("Failed to intialized SDL: %s", sdl.GetError())
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("SDL3 GPU Triangle MSAA", 640, 480, {})
	defer sdl.DestroyWindow(window)

	gpu_device := sdl.CreateGPUDevice({.DXIL}, false, nil)
	defer sdl.DestroyGPUDevice(gpu_device)

	if !sdl.ClaimWindowForGPUDevice(gpu_device, window) {
		fmt.panicf("Failed to claim window for gpu device: %s", sdl.GetError())
	}

	vert_shader := create_shader(gpu_device, VERT_SHADER)
	frag_shader := create_shader(gpu_device, FRAG_SHADER)

	rt_format := sdl.GetGPUSwapchainTextureFormat(gpu_device, window)
	pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &sdl.GPUColorTargetDescription{format = rt_format},
		},
		primitive_type = .TRIANGLELIST,
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
	}

	pipelines: [4]^sdl.GPUGraphicsPipeline
	mssa_render_textures: [4]^sdl.GPUTexture

	sample_counts := 0
	for i in 0 ..< len(pipelines) {
		sample_count := sdl.GPUSampleCount(i)
		if !sdl.GPUTextureSupportsSampleCount(gpu_device, rt_format, sample_count) {
			continue
		}

		pipeline_create_info.multisample_state.sample_count = sample_count
		pipelines[sample_counts] = sdl.CreateGPUGraphicsPipeline(gpu_device, pipeline_create_info)
		if pipelines[sample_counts] == nil {
			fmt.panicf("Failed to create pipeline: %s", sdl.GetError())
		}

		texture_create_info := sdl.GPUTextureCreateInfo {
			type                 = .D2,
			width                = 640,
			height               = 480,
			layer_count_or_depth = 1,
			num_levels           = 1,
			format               = rt_format,
			usage                = {.COLOR_TARGET},
			sample_count         = sample_count,
		}
		if sample_count == ._1 {
			texture_create_info.usage += {.SAMPLER}
		}

		mssa_render_textures[sample_counts] = sdl.CreateGPUTexture(gpu_device, texture_create_info)
		if mssa_render_textures[sample_counts] == nil {
			fmt.panicf("Failed to create msaa render texture: %s", sdl.GetError())
		}

		sample_counts += 1
	}

	resolve_texture := sdl.CreateGPUTexture(
		gpu_device,
		{
			type = .D2,
			width = 640,
			height = 480,
			layer_count_or_depth = 1,
			num_levels = 1,
			format = rt_format,
			usage = {.COLOR_TARGET, .SAMPLER},
		},
	)

	sdl.ReleaseGPUShader(gpu_device, vert_shader)
	sdl.ReleaseGPUShader(gpu_device, frag_shader)

	current_sample_count := 0

	main_loop: for {
		for e: sdl.Event; sdl.PollEvent(&e); {
			if e.type == .QUIT {
				break main_loop
			}

			if e.type == .KEY_DOWN {
				changed := false
				#partial switch e.key.scancode {
				case .LEFT:
					current_sample_count -= 1
					if current_sample_count < 0 {
						current_sample_count = sample_counts - 1
					}
					changed = true

				case .RIGHT:
					current_sample_count = (current_sample_count + 1) % sample_counts
					changed = true
				}

				if changed {
					fmt.printfln("Current sample count: %d", (1 << uint(current_sample_count)))
				}
			}
		}

		command_buffer := sdl.AcquireGPUCommandBuffer(gpu_device)

		swapchain: ^sdl.GPUTexture
		w, h: u32
		_ = sdl.WaitAndAcquireGPUSwapchainTexture(command_buffer, window, &swapchain, &w, &h)
		if swapchain == nil {
			continue
		}

		color_target_info := sdl.GPUColorTargetInfo {
			texture     = mssa_render_textures[current_sample_count],
			load_op     = .CLEAR,
			store_op    = .STORE,
			clear_color = {0, 0, 0, 1},
		}

		if (current_sample_count == 0) {
			color_target_info.store_op = .STORE
		} else {
			color_target_info.store_op = .RESOLVE
			color_target_info.resolve_texture = resolve_texture
		}

		render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)

		sdl.BindGPUGraphicsPipeline(render_pass, pipelines[current_sample_count])
		sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)

		sdl.EndGPURenderPass(render_pass)

		blit_src_texture :=
			color_target_info.resolve_texture != nil ? color_target_info.resolve_texture : color_target_info.texture
		sdl.BlitGPUTexture(
			command_buffer,
			{
				source = {texture = blit_src_texture, x = 160, w = 320, h = 240},
				destination = {texture = swapchain, w = w, h = h},
				load_op = .DONT_CARE,
				filter = .LINEAR,
			},
		)

		_ = sdl.SubmitGPUCommandBuffer(command_buffer)
	}
}
