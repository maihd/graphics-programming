package forge_gpu_02_vertex_buffer

import "core:fmt"
import "core:math/linalg/glsl"
import "core:mem"
import "core:os"
import "core:strings"

import shadercross "../gfx/sdl3_shadercross"
import sdl "vendor:sdl3"

main :: proc() {

	// Initialize SDL

	if !sdl.Init({.VIDEO}) {
		fmt.eprintfln("Failed to initialize SDL: %s", sdl.GetError())
		return
	}
	defer sdl.Quit()

	gpu_device := sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, true, nil)
	sdl_ensure(gpu_device != nil)
	defer sdl.DestroyGPUDevice(gpu_device)

	window := sdl.CreateWindow("SDL3 GPU Vertex Buffer", 800, 600, {})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(gpu_device, window))
	defer sdl.ReleaseWindowFromGPUDevice(gpu_device, window)

	// GPU device specs

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

	fmt.printfln("GPU Device Specs:")
	fmt.printfln(" - GPU Device: %s", gpu_device_name)
	fmt.printfln(" - GPU Driver: %s", gpu_device_driver)
	fmt.printfln(" - GPU Driver Info: %s", gpu_device_driver_info)
	fmt.printfln(" - GPU Driver Version: %s", gpu_device_driver_version)
	fmt.printfln(" - Graphics API Backend: %s", sdl.GetGPUDeviceDriver(gpu_device))
	fmt.printfln(" - Graphics API ShaderFormat: %v", sdl.GetGPUShaderFormats(gpu_device))

	// Vertex buffer

	Vertex :: struct {
		pos:   [2]f32,
		color: [3]f32,
	}

	vertices := []Vertex {
		{pos = {+0.0, +0.5}, color = {1, 0, 0}},
		{pos = {-0.5, -0.5}, color = {0, 1, 0}},
		{pos = {+0.5, -0.5}, color = {0, 0, 1}},
	}

	vertex_buffer := sdl.CreateGPUBuffer(
		gpu_device,
		{size = u32(size_of(Vertex) * len(vertices)), usage = {.VERTEX}},
	)
	sdl_ensure(vertex_buffer != nil)

	upload_buffer: {
		transfer_buffer := sdl.CreateGPUTransferBuffer(
			gpu_device,
			{usage = .UPLOAD, size = u32(size_of(Vertex) * len(vertices))},
		)
		sdl_ensure(transfer_buffer != nil)

		vertices_gpu_ptr := cast([^]Vertex)sdl.MapGPUTransferBuffer(
			gpu_device,
			transfer_buffer,
			false,
		)
		mem.copy(vertices_gpu_ptr, raw_data(vertices), size_of(Vertex) * len(vertices))

		sdl.UnmapGPUTransferBuffer(gpu_device, transfer_buffer)

		cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)
		sdl_ensure(cmdbuf != nil)

		copy_pass := sdl.BeginGPUCopyPass(cmdbuf)
		sdl_ensure(copy_pass != nil)

		sdl.UploadToGPUBuffer(
			copy_pass,
			{offset = 0, transfer_buffer = transfer_buffer},
			{offset = 0, buffer = vertex_buffer, size = u32(len(vertices) * size_of(Vertex))},
			false,
		)
		sdl.EndGPUCopyPass(copy_pass)

		sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdbuf))

		sdl.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)
	}

	// Shaders & Pipeline

	vert_shader := load_shader(gpu_device, "triangle.vert.hlsl", .VERTEX, "main")
	frag_shader := load_shader(gpu_device, "triangle.frag.hlsl", .FRAGMENT, "main")

	pipeline := sdl.CreateGPUGraphicsPipeline(
		gpu_device,
		{
			target_info = {
				num_color_targets = 1,
				color_target_descriptions = &sdl.GPUColorTargetDescription {
					format = sdl.GetGPUSwapchainTextureFormat(gpu_device, window),
				},
			},
			primitive_type = .TRIANGLELIST,
			fragment_shader = frag_shader,
			vertex_shader = vert_shader,
			rasterizer_state = {fill_mode = .FILL},
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
							format = .FLOAT3,
							offset = u32(offset_of(Vertex, color)),
						},
					},
				),
			},
		},
	)
	sdl_ensure(pipeline != nil)

	// Main loop

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
					load_op = .LOAD,
					store_op = .DONT_CARE,
					clear_color = {0, 0, 0, 1},
				},
				1,
				nil,
			)
			sdl_ensure(render_pass != nil)

			sdl.BindGPUGraphicsPipeline(render_pass, pipeline)
			sdl.BindGPUVertexBuffers(
				render_pass,
				0,
				&sdl.GPUBufferBinding{buffer = vertex_buffer, offset = 0},
				1,
			)
			sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)

			sdl.EndGPURenderPass(render_pass)
		}

		sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdbuf))
	}
}

sdl_ensure :: proc(ok: bool, location := #caller_location) {
	if !ok {
		fmt.panicf("Error: %s", sdl.GetError(), loc = location)
	}
}

load_shader :: proc(
	gpu_device: ^sdl.GPUDevice,
	filename: string,
	stage: shadercross.ShaderStage,
	entry_point: string,
) -> ^sdl.GPUShader {
	full_path := strings.join({#directory, filename}, "/")
	defer delete(full_path)

	file_data, err := os.read_entire_file(full_path, context.allocator)
	if err != nil {
		fmt.panicf("Failed to open file: %s", full_path)
	}

	src_cstr := strings.clone_to_cstring(string(file_data))
	defer delete(src_cstr)

	entry_point_cstr := strings.clone_to_cstring(string(entry_point))
	defer delete(entry_point_cstr)

	spirv_size: uint
	spirv := shadercross.CompileSPIRVFromHLSL(
		{shader_stage = stage, source = src_cstr, entrypoint = entry_point_cstr},
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
			props = 0,
		},
		metadata.resource_info,
		0,
	)
	sdl_ensure(shader != nil)
	return shader
}
