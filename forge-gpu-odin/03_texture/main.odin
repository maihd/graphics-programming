package forge_gpu_03_texture

import "core:fmt"
import "core:image/png"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

import shadercross "../gfx/sdl3_shadercross"
import sdl "vendor:sdl3"

main :: proc() {
	// Logger
	logger := log.create_console_logger()
	defer log.destroy_console_logger(logger)

	context.logger = logger

	// Tracking memory

	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	defer {
		if len(tracking_allocator.allocation_map) > 0 {
			log.errorf("=== %v allocations no freed: ===", len(tracking_allocator.allocation_map))
			for _, entry in tracking_allocator.allocation_map {
				log.errorf(" - %v bytes (%p) @ %v", entry.size, entry.memory, entry.location)
			}
		}

		if len(tracking_allocator.bad_free_array) > 0 {
			log.errorf("=== %v incorrect frees: ===", len(tracking_allocator.bad_free_array))
			for entry in tracking_allocator.bad_free_array {
				log.errorf(" - %p @ %v", entry.memory, entry.location)
			}
		}

		mem.tracking_allocator_destroy(&tracking_allocator)
	}

	// SDL3 initialization

	if !sdl.Init({.VIDEO}) {
		sdl_panic("Failed to initialization SDL3")
	}
	defer sdl.Quit()

	log.infof("Initialized SDL3 succeed!")

	window := sdl.CreateWindow("SDL3 GPU Texture", 800, 600, {.HIGH_PIXEL_DENSITY})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)

	gpu_device := sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, true, nil)
	sdl_ensure(gpu_device != nil)
	defer sdl.DestroyGPUDevice(gpu_device)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(gpu_device, window))
	defer sdl.ReleaseWindowFromGPUDevice(gpu_device, window)

	log_gpu_specs(gpu_device)

	// Shaders & Pipeline

	log.infof("Create shaders & pipeline")

	vert_shader := load_shader(gpu_device, "sprite.vert.hlsl", .VERTEX, "main")
	frag_shader := load_shader(gpu_device, "sprite.frag.hlsl", .FRAGMENT, "main")

	pipeline := sdl.CreateGPUGraphicsPipeline(
		gpu_device,
		{
			target_info = {
				num_color_targets = 1,
				color_target_descriptions = &sdl.GPUColorTargetDescription {
					format = sdl.GetGPUSwapchainTextureFormat(gpu_device, window),
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
	sdl_ensure(pipeline != nil)

	sdl.ReleaseGPUShader(gpu_device, vert_shader)
	sdl.ReleaseGPUShader(gpu_device, frag_shader)

	// Vertex Buffer

	log.infof("Create vertex buffer")

	Vertex :: struct {
		pos: [2]f32,
		uv:  [2]f32,
	}

	vertices := [?]Vertex {
		{pos = {-0.5, -0.5}, uv = {0, 1}},
		{pos = {+0.5, +0.5}, uv = {1, 0}},
		{pos = {-0.5, +0.5}, uv = {0, 0}},
		{pos = {-0.5, -0.5}, uv = {0, 1}},
		{pos = {+0.5, -0.5}, uv = {1, 1}},
		{pos = {+0.5, +0.5}, uv = {1, 0}},
	}

	vertex_buffer := sdl.CreateGPUBuffer(gpu_device, {usage = {.VERTEX}, size = size_of(vertices)})
	sdl_ensure(vertex_buffer != nil)
	defer sdl.ReleaseGPUBuffer(gpu_device, vertex_buffer)

	upload_vertices: {
		transfer_buffer := sdl.CreateGPUTransferBuffer(
			gpu_device,
			{usage = .UPLOAD, size = size_of(vertices)},
		)
		sdl_ensure(transfer_buffer != nil)
		defer sdl.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)

		transfer_data := sdl.MapGPUTransferBuffer(gpu_device, transfer_buffer, false)
		sdl.memcpy(transfer_data, raw_data(&vertices), size_of(vertices))
		sdl.UnmapGPUTransferBuffer(gpu_device, transfer_buffer)

		cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)
		sdl_ensure(cmdbuf != nil)

		copy_pass := sdl.BeginGPUCopyPass(cmdbuf)
		sdl.UploadToGPUBuffer(
			copy_pass,
			{transfer_buffer = transfer_buffer, offset = 0},
			{buffer = vertex_buffer, offset = 0, size = size_of(vertices)},
			false,
		)
		sdl.EndGPUCopyPass(copy_pass)

		sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdbuf))
	}

	// Texture & Sampler

	log.infof("Create texture & sampler")

	teximg, err := png.load_from_file(
		#directory + "../assets/sprites/sdl.png",
		{.alpha_add_if_missing},
	)
	if err != nil {
		log.panicf("Failed to load image from %s. Error: %v", #directory + "sdl.png", err)
	}
	ensure(teximg.width > 0)
	ensure(teximg.height > 0)
	ensure(teximg.channels == 4)

	tex_w, tex_h, tex_n := teximg.width, teximg.height, teximg.channels
	tex_pixels := raw_data(teximg.pixels.buf[teximg.pixels.off:])

	texture := sdl.CreateGPUTexture(
		gpu_device,
		{
			type = .D2,
			format = .R8G8B8A8_UNORM,
			width = u32(tex_w),
			height = u32(tex_h),
			usage = {.SAMPLER},
			num_levels = 1,
			layer_count_or_depth = 1,
		},
	)

	sampler := sdl.CreateGPUSampler(
		gpu_device,
		{
			min_filter = .LINEAR,
			mag_filter = .LINEAR,
			mipmap_mode = .LINEAR,
			address_mode_u = .CLAMP_TO_EDGE,
			address_mode_v = .CLAMP_TO_EDGE,
			address_mode_w = .CLAMP_TO_EDGE,
		},
	)

	upload_texture_pixels: {
		tex_size := tex_w * tex_h * tex_n

		transfer_buffer := sdl.CreateGPUTransferBuffer(
			gpu_device,
			{usage = .UPLOAD, size = u32(tex_size)},
		)
		sdl_ensure(transfer_buffer != nil)
		defer sdl.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)

		transfer_pixels := sdl.MapGPUTransferBuffer(gpu_device, transfer_buffer, false)
		sdl_ensure(transfer_pixels != nil)

		sdl.memcpy(transfer_pixels, tex_pixels, uint(tex_size))
		sdl.UnmapGPUTransferBuffer(gpu_device, transfer_buffer)

		cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)

		copy_pass := sdl.BeginGPUCopyPass(cmdbuf)
		sdl.UploadToGPUTexture(
			copy_pass,
			{transfer_buffer = transfer_buffer, offset = 0},
			{texture = texture, w = u32(tex_w), h = u32(tex_h), d = 1},
			false,
		)
		sdl.EndGPUCopyPass(copy_pass)

		sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdbuf))
	}

	// Main loop

	log.infof("Start main loop")

	main_loop: for {
		for e: sdl.Event; sdl.PollEvent(&e); {
			if e.type == .QUIT {
				break main_loop
			}
		}

		cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)
		sdl_ensure(cmdbuf != nil)

		swapchain: ^sdl.GPUTexture
		sdl_ensure(sdl.WaitAndAcquireGPUSwapchainTexture(cmdbuf, window, &swapchain, nil, nil))
		if swapchain != nil {
			render_pass := sdl.BeginGPURenderPass(
				cmdbuf,
				&sdl.GPUColorTargetInfo {
					texture = swapchain,
					load_op = .CLEAR,
					store_op = .STORE,
					clear_color = {0.3, 0.3, 0.3, 1},
				},
				1,
				nil,
			)

			sdl.BindGPUFragmentSamplers(
				render_pass,
				0,
				&sdl.GPUTextureSamplerBinding{sampler = sampler, texture = texture},
				1,
			)
			sdl.BindGPUVertexBuffers(
				render_pass,
				0,
				&sdl.GPUBufferBinding{buffer = vertex_buffer, offset = 0},
				1,
			)
			sdl.BindGPUGraphicsPipeline(render_pass, pipeline)
			sdl.DrawGPUPrimitives(render_pass, len(vertices), 1, 0, 0)

			sdl.EndGPURenderPass(render_pass)
		}

		sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdbuf))
	}
}

sdl_panic :: proc(message: string) {
	log.panicf("%s. Error: %s", message, sdl.GetError())
}

sdl_ensure :: proc(ok: bool, message := "", location := #caller_location) {
	if !ok {
		if message != "" {
			log.panicf("%s. Error: %s", message, sdl.GetError(), location = location)
		} else {
			log.panicf("Error: %s", sdl.GetError(), location = location)
		}
	}
}

log_gpu_specs :: proc(gpu_device: ^sdl.GPUDevice) {

}

load_shader :: proc(
	gpu_device: ^sdl.GPUDevice,
	filename: string,
	stage: shadercross.ShaderStage,
	entry_point: string,
) -> ^sdl.GPUShader {
	full_path := strings.join({#directory, "..", "assets", "shaders", filename}, "/")
	defer delete(full_path)

	file_data, err := os.read_entire_file(full_path, allocator = context.allocator)
	if err != nil {
		log.panicf("Failed to load shader from file: %v", err)
	}
	defer delete(file_data)

	source_cstr := strings.clone_to_cstring(string(file_data))
	defer delete(source_cstr)

	entry_point_cstr := strings.clone_to_cstring(entry_point)
	defer delete(entry_point_cstr)

	spirv_size: uint
	spirv := shadercross.CompileSPIRVFromHLSL(
		{entrypoint = entry_point_cstr, shader_stage = stage, source = source_cstr},
		&spirv_size,
	)
	sdl_ensure(spirv != nil)
	defer sdl.free(spirv)

	metadata := shadercross.ReflectGraphicsSPIRV(spirv, spirv_size, 0)
	sdl_ensure(metadata != nil)
	defer sdl.free(metadata)

	shader := shadercross.CompileGraphicsShaderFromSPIRV(
		gpu_device,
		{
			bytecode = spirv,
			bytecode_size = spirv_size,
			entrypoint = entry_point_cstr,
			shader_stage = stage,
		},
		metadata.resource_info,
		0,
	)
	sdl_ensure(shader != nil)

	return shader
}
