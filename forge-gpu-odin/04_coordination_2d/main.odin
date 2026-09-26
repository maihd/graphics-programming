package forge_gpu_04_coordination_2d

import "../gfx"
import "core:math"

import "core:log"
import "core:mem"

import glm "core:math/linalg/glsl"
import sdl "vendor:sdl3"

main :: proc() {
	ensure(gfx.init({title = "SDL3 GPU Coordination 2D", width = 800, height = 600}))
	defer gfx.deinit()

	// Required for logger & tracking memory to work
	context = gfx.state.ctx

	// Shader & Pipeline

	log.infof("1. Create shaders & pipeline")

	vert_shader := gfx.load_shader(
		gfx.state.gpu_device,
		filename = "sprite_2d.vert.hlsl",
		entry_point = "main",
		stage = .VERTEX,
	)
	frag_shader := gfx.load_shader(
		gfx.state.gpu_device,
		filename = "sprite_2d.frag.hlsl",
		entry_point = "main",
		stage = .FRAGMENT,
	)

	pipeline := sdl.CreateGPUGraphicsPipeline(
		gfx.state.gpu_device,
		{
			target_info = {
				num_color_targets = 1,
				color_target_descriptions = &sdl.GPUColorTargetDescription {
					format = sdl.GetGPUSwapchainTextureFormat(
						gfx.state.gpu_device,
						gfx.state.window,
					),
					blend_state = {
						enable_blend = true,
						alpha_blend_op = .ADD,
						color_blend_op = .ADD,
						src_alpha_blendfactor = .SRC_ALPHA,
						dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
						src_color_blendfactor = .SRC_ALPHA,
						dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
					},
				},
			},
			primitive_type = .TRIANGLELIST,
			vertex_shader = vert_shader,
			fragment_shader = frag_shader,
			rasterizer_state = {
				fill_mode = .FILL,
				cull_mode = .NONE,
				front_face = .COUNTER_CLOCKWISE,
			},
			vertex_input_state = {
				num_vertex_buffers = 1,
				vertex_buffer_descriptions = &sdl.GPUVertexBufferDescription {
					slot = 0,
					pitch = size_of(Vertex),
					input_rate = .VERTEX,
				},
				num_vertex_attributes = 2,
				vertex_attributes = raw_data(
					[]sdl.GPUVertexAttribute {
						{
							location = 0,
							buffer_slot = 0,
							format = .FLOAT2,
							offset = u32(offset_of(Vertex, pos)),
						},
						{
							location = 1,
							buffer_slot = 0,
							format = .FLOAT2,
							offset = u32(offset_of(Vertex, uv)),
						},
					},
				),
			},
		},
	)
	gfx.sdl_ensure(pipeline != nil)
	defer sdl.ReleaseGPUGraphicsPipeline(gfx.state.gpu_device, pipeline)

	sdl.ReleaseGPUShader(gfx.state.gpu_device, vert_shader)
	sdl.ReleaseGPUShader(gfx.state.gpu_device, frag_shader)

	// Vertex buffer

	log.infof("2. Create vertex buffer")

	Vertex :: struct {
		pos: [2]f32,
		uv:  [2]f32,
	}

	vertices := [?]Vertex {
		{pos = {-0.0, -0.0}, uv = {0, 1}},
		{pos = {+1.0, +1.0}, uv = {1, 0}},
		{pos = {-0.0, +1.0}, uv = {0, 0}},
		{pos = {-0.0, -0.0}, uv = {0, 1}},
		{pos = {+1.0, -0.0}, uv = {1, 1}},
		{pos = {+1.0, +1.0}, uv = {1, 0}},
	}

	vertex_buffer := sdl.CreateGPUBuffer(
		gfx.state.gpu_device,
		{usage = {.VERTEX}, size = size_of(vertices)},
	)

	upload_vertex_data: {
		transfer_buffer := sdl.CreateGPUTransferBuffer(
			gfx.state.gpu_device,
			{usage = .UPLOAD, size = size_of(vertices)},
		)
		gfx.sdl_ensure(transfer_buffer != nil)
		defer sdl.ReleaseGPUTransferBuffer(gfx.state.gpu_device, transfer_buffer)

		transfer_data := sdl.MapGPUTransferBuffer(gfx.state.gpu_device, transfer_buffer, false)
		mem.copy(transfer_data, raw_data(&vertices), size_of(vertices))
		sdl.UnmapGPUTransferBuffer(gfx.state.gpu_device, transfer_buffer)

		cmdbuf := sdl.AcquireGPUCommandBuffer(gfx.state.gpu_device)

		copy_pass := sdl.BeginGPUCopyPass(cmdbuf)
		sdl.UploadToGPUBuffer(
			copy_pass,
			{transfer_buffer = transfer_buffer, offset = 0},
			{buffer = vertex_buffer, offset = 0, size = size_of(vertices)},
			false,
		)
		sdl.EndGPUCopyPass(copy_pass)

		gfx.sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdbuf))
	}

	// Texture

	log.infof("3. Create texture")

	texture, tex_w, tex_h := gfx.load_texture(gfx.state.gpu_device, "sprites/sdl.png")
	defer sdl.ReleaseGPUTexture(gfx.state.gpu_device, texture)

	sampler := sdl.CreateGPUSampler(
		gfx.state.gpu_device,
		{
			min_filter = .LINEAR,
			mag_filter = .LINEAR,
			mipmap_mode = .LINEAR,
			address_mode_u = .CLAMP_TO_EDGE,
			address_mode_v = .CLAMP_TO_EDGE,
			address_mode_w = .CLAMP_TO_EDGE,
		},
	)
	gfx.sdl_ensure(sampler != nil)
	defer sdl.ReleaseGPUSampler(gfx.state.gpu_device, sampler)

	// Coordination math & Uniform

	Uniform :: struct {
		mvp: glm.mat4,
	}

	screen_width, screen_height: i32
	gfx.sdl_ensure(sdl.GetWindowSize(gfx.state.window, &screen_width, &screen_height))

	projection := glm.mat4Ortho3d(0, f32(screen_width), 0, f32(screen_height), 0.1, 100)
	model :=
		glm.mat4Translate({f32(screen_width) * 0.5, f32(screen_height) * 0.5, 0}) *
		glm.mat4Translate({-f32(tex_w) * 0.5, -f32(tex_h) * 0.5, 0}) *
		glm.mat4Scale({f32(tex_w), f32(tex_h), 1})
	uniform := Uniform{projection * model}

	scale := f32(1)

	log.infof("4. Main loop")
	log.infof(" - UP to scale up")
	log.infof(" - DOWN to scale down")

	main_loop: for {
		for e: sdl.Event; sdl.PollEvent(&e); {
			if e.type == .QUIT {
				break main_loop
			}

			if e.type == .KEY_DOWN {
				#partial switch e.key.scancode {
				case .UP:
					scale = math.min(scale + 0.1, 2)
					model =
						glm.mat4Translate({f32(screen_width) * 0.5, f32(screen_height) * 0.5, 0}) *
						glm.mat4Translate(
							{-f32(tex_w) * scale * 0.5, -f32(tex_h) * scale * 0.5, 0},
						) *
						glm.mat4Scale({f32(tex_w), f32(tex_h), 1}) *
						glm.mat4Scale(scale)

					uniform = Uniform{projection * model}

				case .DOWN:
					scale = math.max(scale - 0.1, 0.25)
					model =
						glm.mat4Translate({f32(screen_width) * 0.5, f32(screen_height) * 0.5, 0}) *
						glm.mat4Translate(
							{-f32(tex_w) * scale * 0.5, -f32(tex_h) * scale * 0.5, 0},
						) *
						glm.mat4Scale({f32(tex_w), f32(tex_h), 1}) *
						glm.mat4Scale(scale)

					uniform = Uniform{projection * model}
				}
			}
		}

		cmdbuf := sdl.AcquireGPUCommandBuffer(gfx.state.gpu_device)

		swapchain_texture: ^sdl.GPUTexture
		gfx.sdl_ensure(
			sdl.WaitAndAcquireGPUSwapchainTexture(
				cmdbuf,
				gfx.state.window,
				&swapchain_texture,
				nil,
				nil,
			),
		)

		if swapchain_texture != nil {
			render_pass := sdl.BeginGPURenderPass(
				cmdbuf,
				&sdl.GPUColorTargetInfo {
					texture = swapchain_texture,
					load_op = .CLEAR,
					store_op = .STORE,
					clear_color = {0.9, 0.9, 0.9, 1},
				},
				1,
				nil,
			)

			sdl.PushGPUVertexUniformData(cmdbuf, 0, &uniform, size_of(uniform))

			sdl.BindGPUVertexBuffers(
				render_pass,
				0,
				&sdl.GPUBufferBinding{buffer = vertex_buffer, offset = 0},
				1,
			)
			sdl.BindGPUFragmentSamplers(
				render_pass,
				0,
				&sdl.GPUTextureSamplerBinding{texture = texture, sampler = sampler},
				1,
			)
			sdl.BindGPUGraphicsPipeline(render_pass, pipeline)
			sdl.DrawGPUPrimitives(render_pass, 6, 1, 0, 0)

			sdl.EndGPURenderPass(render_pass)
		}

		gfx.sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdbuf))
	}
}
