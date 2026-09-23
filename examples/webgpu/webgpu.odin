package wgpu_example

import "base:runtime"

import "core:fmt"

import sdl "vendor:sdl3"
import "vendor:wgpu"
import "vendor:wgpu/sdl3glue"

// OS

OS :: struct {
	window: ^sdl.Window,
}

os_init :: proc() {
	if !sdl.Init({.VIDEO}) {
		fmt.panicf("sdl.Init error: ", sdl.GetError())
	}

	state.os.window = sdl.CreateWindow(
		"WGPU Native Triangle",
		960,
		540,
		{.RESIZABLE, .HIGH_PIXEL_DENSITY},
	)
	if state.os.window == nil {
		fmt.panicf("sdl.CreateWindow error: ", sdl.GetError())
	}
}

os_run :: proc() {
	now := sdl.GetPerformanceCounter()
	last: u64
	dt: f32
	main_loop: for {
		last = now
		now = sdl.GetPerformanceCounter()
		dt = f32((now - last) * 1000) / f32(sdl.GetPerformanceFrequency())

		for e: sdl.Event; sdl.PollEvent(&e); {
			#partial switch e.type {
			case .QUIT:
				break main_loop

			case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
				resize()
			}
		}

		frame(dt)
	}

	finish()

	sdl.DestroyWindow(state.os.window)
	sdl.Quit()
}

os_get_framebuffer_size :: proc() -> (_size: [2]i32) {
	sdl.GetWindowSizeInPixels(state.os.window, &_size.x, &_size.y)
	return
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return sdl3glue.GetSurface(instance, state.os.window)
}

// App

state: struct {
	ctx:             runtime.Context,
	os:              OS,
	instance:        wgpu.Instance,
	surface:         wgpu.Surface,
	adapter:         wgpu.Adapter,
	device:          wgpu.Device,
	config:          wgpu.SurfaceConfiguration,
	queue:           wgpu.Queue,
	module:          wgpu.ShaderModule,
	pipeline_layout: wgpu.PipelineLayout,
	pipeline:        wgpu.RenderPipeline,
}

main :: proc() {
	state.ctx = context

	os_init()

	state.instance = wgpu.CreateInstance(nil)
	if state.instance == nil {
		panic("WebGPU is not supported")
	}
	state.surface = os_get_surface(state.instance)

	wgpu.InstanceRequestAdapter(
		state.instance,
		&{compatibleSurface = state.surface},
		{callback = on_adapter},
	)

	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		context = state.ctx
		if status != .Success || adapter == nil {
			fmt.panicf("request adapter failure: [%v] %s", status, message)
		}
		state.adapter = adapter
		wgpu.AdapterRequestDevice(adapter, nil, {callback = on_device})
	}

	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		context = state.ctx
		if status != .Success || device == nil {
			fmt.panicf("request device failure: [%v] %s", status, message)
		}
		state.device = device

		size := os_get_framebuffer_size()

		state.config = {
			device      = state.device,
			usage       = {.RenderAttachment},
			format      = .BGRA8Unorm,
			width       = u32(size.x),
			height      = u32(size.y),
			presentMode = .Fifo,
			alphaMode   = .Opaque,
		}
		wgpu.SurfaceConfigure(state.surface, &state.config)

		state.queue = wgpu.DeviceGetQueue(state.device)

		shader :: `
        @vertex
        fn vs_main(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4<f32> {
            let x = f32(i32(in_vertex_index) - 1);
            let y = f32(i32(in_vertex_index & 1u) * 2 - 1);
            return vec4<f32>(x, y, 0.0, 1.0);
        }

        @fragment
        fn fs_main() -> @location(0) vec4<f32> {
            return vec4<f32>(1.0, 0.0, 0.0, 1.0);
        }
        `

		state.module = wgpu.DeviceCreateShaderModule(
			state.device,
			&{nextInChain = &wgpu.ShaderSourceWGSL{sType = .ShaderSourceWGSL, code = shader}},
		)

		state.pipeline_layout = wgpu.DeviceCreatePipelineLayout(state.device, &{})
		state.pipeline = wgpu.DeviceCreateRenderPipeline(
			state.device,
			&{
				layout = state.pipeline_layout,
				vertex = {module = state.module, entryPoint = "vs_main"},
				fragment = &{
					module = state.module,
					entryPoint = "fs_main",
					targetCount = 1,
					targets = &wgpu.ColorTargetState {
						format = .BGRA8Unorm,
						writeMask = wgpu.ColorWriteMaskFlags_All,
					},
				},
				primitive = {topology = .TriangleList},
				multisample = {count = 1, mask = 0xffffffff},
			},
		)

		os_run()
	}
}

resize :: proc "c" () {
	context = state.ctx

	size := os_get_framebuffer_size()
	state.config.width, state.config.height = u32(size.x), u32(size.y)
	wgpu.SurfaceConfigure(state.surface, &state.config)
}

frame :: proc "c" (dt: f32) {
	context = state.ctx

	surface_texture := wgpu.SurfaceGetCurrentTexture(state.surface)
	switch surface_texture.status {
	case .SuccessOptimal, .SuccessSuboptimal:
	// All good

	case .Timeout, .Outdated, .Lost:
		// Skip
		if surface_texture.texture != nil {
			wgpu.TextureRelease(surface_texture.texture)
		}
		resize()
		return

	case .Occluded:
		// Skip (windows is not presenting)
		return

	case .Error:
		fmt.panicf("[triangle] get_current_texture status=%v", surface_texture.texture)
	}
	defer wgpu.TextureRelease(surface_texture.texture)

	frame := wgpu.TextureCreateView(surface_texture.texture, nil)
	defer wgpu.TextureViewRelease(frame)

	command_encoder := wgpu.DeviceCreateCommandEncoder(state.device, nil)
	defer wgpu.CommandEncoderRelease(command_encoder)

	render_pass_encoder := wgpu.CommandEncoderBeginRenderPass(
		command_encoder,
		&{
			colorAttachmentCount = 1,
			colorAttachments = &wgpu.RenderPassColorAttachment {
				view = frame,
				loadOp = .Clear,
				storeOp = .Store,
				depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
				clearValue = {0, 1, 0, 1},
			},
		},
	)

	wgpu.RenderPassEncoderSetPipeline(render_pass_encoder, state.pipeline)
	wgpu.RenderPassEncoderDraw(
		render_pass_encoder,
		vertexCount = 3,
		instanceCount = 1,
		firstVertex = 0,
		firstInstance = 0,
	)

	wgpu.RenderPassEncoderEnd(render_pass_encoder)
	wgpu.RenderPassEncoderRelease(render_pass_encoder)

	command_buffer := wgpu.CommandEncoderFinish(command_encoder, nil)
	defer wgpu.CommandBufferRelease(command_buffer)

	wgpu.QueueSubmit(state.queue, {command_buffer})
	wgpu.SurfacePresent(state.surface)
}

finish :: proc() {
	wgpu.RenderPipelineRelease(state.pipeline)
	wgpu.PipelineLayoutRelease(state.pipeline_layout)
	wgpu.ShaderModuleRelease(state.module)
	wgpu.QueueRelease(state.queue)
	wgpu.DeviceRelease(state.device)
	wgpu.AdapterRelease(state.adapter)
	wgpu.SurfaceRelease(state.surface)
	wgpu.InstanceRelease(state.instance)
}
