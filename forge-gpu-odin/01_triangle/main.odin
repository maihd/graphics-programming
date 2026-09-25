package forge_gpu_01_triangle

import "core:fmt"
import "core:strings"

import shadercross "../gfx/sdl3_shadercross"
import sdl "vendor:sdl3"

VERT_SRC :: #load(#directory + "../assets/shaders/raw_triangle.vert.hlsl")
FRAG_SRC :: #load(#directory + "../assets/shaders/solid_color.frag.hlsl")

create_shader :: proc(
	gpu_device: ^sdl.GPUDevice,
	source: []u8,
	stage: shadercross.ShaderStage,
	entry_point: string,
) -> ^sdl.GPUShader {
	source_cstr := strings.clone_to_cstring(string(source))
	defer delete(source_cstr)

	entry_point_cstr := strings.clone_to_cstring(entry_point)
	defer delete(entry_point_cstr)

	spirv_size: uint
	spirv := shadercross.CompileSPIRVFromHLSL(
		info = {entrypoint = entry_point_cstr, shader_stage = stage, source = source_cstr},
		size = &spirv_size,
	)
	defer sdl.free(spirv)

	if spirv == nil {
		fmt.panicf("Compile HLSL to failed:\n%s", sdl.GetError())
	}

	metadata := shadercross.ReflectGraphicsSPIRV(spirv, spirv_size, 0)
	defer sdl.free(metadata)

	shader := shadercross.CompileGraphicsShaderFromSPIRV(
		gpu_device,
		info = {
			bytecode = spirv,
			bytecode_size = spirv_size,
			entrypoint = entry_point_cstr,
			shader_stage = stage,
			props = 0,
		},
		resource_info = metadata.resource_info,
		// resource_info = {},
		props = 0,
	)
	return shader
}

main :: proc() {
	fmt.printfln("SDL3 GPU Triangle!")

	if !sdl.Init({.VIDEO}) {
		fmt.eprintfln("Failed to intialize SDL3: %s", sdl.GetError())
		return
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("SDL3 GPU Triangle", 800, 600, {})
	defer sdl.DestroyWindow(window)

	gpu_device := sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, false, nil)
	defer sdl.DestroyGPUDevice(gpu_device)

	if !sdl.ClaimWindowForGPUDevice(gpu_device, window) {
		fmt.eprintfln("Failed to claim window for GPU device: %s", sdl.GetError())
		return
	}
	defer sdl.ReleaseWindowFromGPUDevice(gpu_device, window)

	fmt.printfln("GPU Driver: %s", sdl.GetGPUDeviceDriver(gpu_device))
	fmt.printfln(
		"GPU Driver Version: %s",
		sdl.GetStringProperty(
			sdl.GetGPUDeviceProperties(gpu_device),
			sdl.PROP_GPU_DEVICE_DRIVER_VERSION_STRING,
			"<unspecified>",
		),
	)
	fmt.printfln("GPU Shader Format: %v", sdl.GetGPUShaderFormats(gpu_device))

	vert_shader := create_shader(gpu_device, VERT_SRC, .VERTEX, "main")
	frag_shader := create_shader(gpu_device, FRAG_SRC, .FRAGMENT, "main")
	defer sdl.ReleaseGPUShader(gpu_device, vert_shader)
	defer sdl.ReleaseGPUShader(gpu_device, frag_shader)

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
			vertex_shader = vert_shader,
			fragment_shader = frag_shader,
			rasterizer_state = {
				fill_mode = .FILL,
				cull_mode = .NONE,
				front_face = .COUNTER_CLOCKWISE,
			},
		},
	)
	defer sdl.ReleaseGPUGraphicsPipeline(gpu_device, pipeline)
	if pipeline == nil {
		fmt.panicf("Failed to create graphics pipeline: %s", sdl.GetError())
	}

	main_loop: for {
		for e: sdl.Event; sdl.PollEvent(&e); {
			if e.type == .QUIT {
				break main_loop
			}
		}

		cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)

		swapchain_texture: ^sdl.GPUTexture
		if !sdl.WaitAndAcquireGPUSwapchainTexture(cmdbuf, window, &swapchain_texture, nil, nil) {
			fmt.panicf("Failed to acquire swapchain texture: %s", sdl.GetError())
		}

		if swapchain_texture != nil {
			render_pass := sdl.BeginGPURenderPass(
				cmdbuf,
				&sdl.GPUColorTargetInfo {
					texture = swapchain_texture,
					load_op = .CLEAR,
					store_op = .STORE,
					clear_color = {0, 0, 0, 1},
				},
				1,
				nil,
			)

			sdl.BindGPUGraphicsPipeline(render_pass, pipeline)
			sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)

			sdl.EndGPURenderPass(render_pass)
		}

		if !sdl.SubmitGPUCommandBuffer(cmdbuf) {
			fmt.panicf("Failed to submit command buffer to GPU: %s", sdl.GetError())
		}
	}
}
