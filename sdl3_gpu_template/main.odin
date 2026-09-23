package main

import "core:math"
import "core:fmt"
import "core:image/png"
import "core:strings"

import glm "core:math/linalg/glsl"

import sdl "vendor:sdl3"
import shadercross "libs/sdl_shadercross"

import tinyobj "libs/tinyobj"

frag_src_hlsl :: #load(#directory + "assets/shaders/frag.hlsl")
vert_src_hlsl :: #load(#directory + "assets/shaders/vert.hlsl")

MODEL :: #load(#directory + "assets/models/viking_room.obj")
TEXTURE_IMG_DATA :: #load(#directory + "assets/models/viking_room.png")

Vertex :: struct {
	pos: [3]f32,
	uv:  [2]f32,
}

UniformBufferObject :: struct {
	mvp: glm.mat4,
}

main :: proc() {
	fmt.printf("Odin GPU Programming\n")

	if !sdl.Init({.VIDEO}) {
		fmt.panicf("Failed to initialized: %s\n", sdl.GetError())
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("Odin GPU Programming", 800, 600, {})
	defer sdl.DestroyWindow(window)

	gpu_device := sdl.CreateGPUDevice({.SPIRV}, false, nil)
	defer sdl.DestroyGPUDevice(gpu_device)

	if !sdl.ClaimWindowForGPUDevice(gpu_device, window) {
		fmt.panicf("Failed to claim window for gpu_device: %s\n", sdl.GetError())
	}

	if !shadercross.Init() {
		fmt.panicf("Failed to init shadercross")
	}
	defer shadercross.Quit()

	vertices := make([dynamic]Vertex)
	indices := make([dynamic]u32)

	unique_vertices := make(map[Vertex]u32)
	defer delete(unique_vertices)

	model := tinyobj.parse_obj(
		string(MODEL),
		#directory + "assets/models",
		tinyobj.FLAG_TRIANGULATE,
	)
	defer tinyobj.destroy(&model)

	for shape in model.shapes {
		index_offset := 0
		for f := 0; f < shape.length; f += 1 {
			current_face_idx := shape.face_offset + f
			num_verts := model.attrib.face_num_verts[current_face_idx]

			vertex := Vertex{}

			for v := 0; v < num_verts; v += 1 {
				idx := model.attrib.faces[index_offset + v]

				vertex := Vertex {
					pos = {
						model.attrib.vertices[idx.v_idx * 3 + 0],
						model.attrib.vertices[idx.v_idx * 3 + 2],
						model.attrib.vertices[idx.v_idx * 3 + 1],
					},
					uv  = {
						model.attrib.texcoords[idx.vt_idx * 2 + 0],
						1.0 - model.attrib.texcoords[idx.vt_idx * 2 + 1],
					},
				}

				if vertex not_in unique_vertices {
					unique_vertices[vertex] = u32(len(vertices))
					append(&vertices, vertex)
				}

				append(&indices, unique_vertices[vertex])
			}

			index_offset += num_verts
		}
	}

	vertex_buffer := sdl.CreateGPUBuffer(gpu_device, {
		usage = {.VERTEX},
		size  = u32(len(vertices) * size_of(Vertex)),
	})
	defer sdl.ReleaseGPUBuffer(gpu_device, vertex_buffer)

	{
		transfer_buffer := sdl.CreateGPUTransferBuffer(gpu_device, {
			usage = .UPLOAD,
			size  = u32(len(vertices) * size_of(Vertex)),
		})
		defer sdl.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)

		transfer_data := cast([^]Vertex)sdl.MapGPUTransferBuffer(
			gpu_device,
			transfer_buffer,
			false,
		)
		if transfer_data == nil {
			fmt.panicf("Failed to map gpu data: %s", sdl.GetError())
		}

		sdl.memcpy(transfer_data, raw_data(vertices), len(vertices) * size_of(Vertex))

		upload_cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)
		copy_pass := sdl.BeginGPUCopyPass(upload_cmdbuf)
		buffer_location := sdl.GPUTransferBufferLocation {
			transfer_buffer = transfer_buffer,
			offset          = 0,
		}
		buffer_region := sdl.GPUBufferRegion {
			buffer = vertex_buffer,
			offset = 0,
			size   = u32(len(vertices) * size_of(Vertex)),
		}
		sdl.UploadToGPUBuffer(copy_pass, buffer_location, buffer_region, false)
		sdl.EndGPUCopyPass(copy_pass)
		if !sdl.SubmitGPUCommandBuffer(upload_cmdbuf) {
			fmt.panicf("Failed to submit copy pass for vertex buffer: %s\n", sdl.GetError())
		}
	}

	index_buffer := sdl.CreateGPUBuffer(gpu_device, {
		usage = {.INDEX},
		size  = u32(len(indices) * size_of(u32)),
	})
	defer sdl.ReleaseGPUBuffer(gpu_device, index_buffer)

	{
		transfer_buffer := sdl.CreateGPUTransferBuffer(gpu_device, {
			usage = .UPLOAD,
			size  = u32(len(indices) * size_of(u32)),
		})
		defer sdl.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)

		transfer_data := cast([^]Vertex)sdl.MapGPUTransferBuffer(
			gpu_device,
			transfer_buffer,
			false,
		)
		if transfer_data == nil {
			fmt.panicf("Failed to map gpu data: %s", sdl.GetError())
		}

		sdl.memcpy(transfer_data, raw_data(indices), len(indices) * size_of(u32))

		upload_cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)
		copy_pass := sdl.BeginGPUCopyPass(upload_cmdbuf)
		buffer_location := sdl.GPUTransferBufferLocation {
			transfer_buffer = transfer_buffer,
			offset          = 0,
		}
		buffer_region := sdl.GPUBufferRegion {
			buffer = index_buffer,
			offset = 0,
			size   = u32(len(indices) * size_of(u32)),
		}
		sdl.UploadToGPUBuffer(copy_pass, buffer_location, buffer_region, false)
		sdl.EndGPUCopyPass(copy_pass)
		if !sdl.SubmitGPUCommandBuffer(upload_cmdbuf) {
			fmt.panicf("Failed to submit copy pass for index buffer: %s\n", sdl.GetError())
		}
	}

	texture_img, _ := png.load_from_bytes(TEXTURE_IMG_DATA)
	defer png.destroy(texture_img)

	texture_pixels := texture_img.pixels.buf[texture_img.pixels.off:]

	texture := sdl.CreateGPUTexture(gpu_device, {
		type                 = .D2,
		format               = .R8G8B8A8_UNORM,
		width                = u32(texture_img.width),
		height               = u32(texture_img.height),
		usage                = {.SAMPLER},
		num_levels           = 1,
		layer_count_or_depth = 1,
	})

	sampler := sdl.CreateGPUSampler(gpu_device, {
		min_filter     = .NEAREST,
		mag_filter     = .NEAREST,
		mipmap_mode    = .NEAREST,
		address_mode_u = .CLAMP_TO_EDGE,
		address_mode_v = .CLAMP_TO_EDGE,
		address_mode_w = .CLAMP_TO_EDGE,
	})

	{
		transfer_buffer := sdl.CreateGPUTransferBuffer(gpu_device, {
			usage = .UPLOAD,
			size  = u32(len(texture_pixels) / 3 * 4),
		})

		transfer_data := cast([^]u8)sdl.MapGPUTransferBuffer(gpu_device, transfer_buffer, false)
		//sdl.memcpy(transfer_data, raw_data(texture_pixels), len(texture_pixels))
		for i in 0 ..< texture_img.width * texture_img.height {
			transfer_data[i * 4 + 0] = texture_pixels[i * 3 + 0]
			transfer_data[i * 4 + 1] = texture_pixels[i * 3 + 1]
			transfer_data[i * 4 + 2] = texture_pixels[i * 3 + 2]
			transfer_data[i * 4 + 3] = 255
		}

		upload_cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)
		copy_pass := sdl.BeginGPUCopyPass(upload_cmdbuf)

		sdl.UploadToGPUTexture(copy_pass, {
				transfer_buffer = transfer_buffer,
				offset          = 0,
			}, {
				texture = texture,
				w       = u32(texture_img.width),
				h       = u32(texture_img.height),
				d       = 1,
			}, false)

		sdl.EndGPUCopyPass(copy_pass)
		_ = sdl.SubmitGPUCommandBuffer(upload_cmdbuf)
	}

	vert_src_size: uint
	vert_src := shadercross.CompileSPIRVFromHLSL({
			entrypoint   = "main",
			shader_stage = .VERTEX,
			source       = strings.clone_to_cstring(string(vert_src_hlsl)),
		}, &vert_src_size)
	if vert_src == nil {
		fmt.panicf("Failed to compile vertex HLSL into spirv")
	}

	vert_shader := sdl.CreateGPUShader(gpu_device, {
		code                 = vert_src,
		code_size            = vert_src_size,
		format               = {.SPIRV},
		stage                = .VERTEX,
		entrypoint           = "main",
		num_samplers         = 0,
		num_storage_buffers  = 0,
		num_storage_textures = 0,
		num_uniform_buffers  = 1,
	})

	frag_src_size: uint
	frag_src := shadercross.CompileSPIRVFromHLSL({
			entrypoint   = "main",
			shader_stage = .FRAGMENT,
			source       = strings.clone_to_cstring(string(frag_src_hlsl)),
		}, &frag_src_size)

	frag_shader := sdl.CreateGPUShader(gpu_device, {
		code                 = frag_src,
		code_size            = frag_src_size,
		format               = {.SPIRV},
		stage                = .FRAGMENT,
		entrypoint           = "main",
		num_samplers         = 1,
		num_storage_buffers  = 0,
		num_storage_textures = 0,
		num_uniform_buffers  = 0,
	})

	pipeline := sdl.CreateGPUGraphicsPipeline(
	gpu_device,
	{
		multisample_state = {
			enable_alpha_to_coverage = true,
			enable_mask              = false,
			sample_count             = ._1,
			sample_mask              = 0,
		},
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		primitive_type = .TRIANGLELIST,
		rasterizer_state = {
			fill_mode = .FILL,
		},
		target_info = {
			num_color_targets         = 1,
			color_target_descriptions = &sdl.GPUColorTargetDescription {
				format = sdl.GetGPUSwapchainTextureFormat(gpu_device, window),
				blend_state = {
					enable_blend          = true,
					color_blend_op        = .ADD,
					alpha_blend_op        = .ADD,
					src_color_blendfactor = .SRC_ALPHA,
					dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
					src_alpha_blendfactor = .SRC_ALPHA,
					dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
				},
			},
			has_depth_stencil_target  = true,
			depth_stencil_format      = .D24_UNORM_S8_UINT,
		},
		depth_stencil_state = {
			compare_op         = .LESS,
			enable_depth_test  = true,
			enable_depth_write = true,
			// enable_stencil_test = true,
		},
		vertex_input_state = {
			num_vertex_buffers         = 1,
			vertex_buffer_descriptions = &sdl.GPUVertexBufferDescription {
				slot               = 0,
				pitch              = size_of(Vertex),
				input_rate         = .VERTEX,
				instance_step_rate = 0,
			},
			num_vertex_attributes      = 2,
			vertex_attributes          = raw_data([]sdl.GPUVertexAttribute {
				{
					location    = 0,
					buffer_slot = 0,
					format      = .FLOAT3,
					offset      = u32(offset_of(Vertex, pos)),
				},
				{
					location    = 1,
					buffer_slot = 0,
					format      = .FLOAT2,
					offset      = u32(offset_of(Vertex, uv)),
				},
			}),
		},
	},
	)
	defer sdl.ReleaseGPUGraphicsPipeline(gpu_device, pipeline)

	sdl.ReleaseGPUShader(gpu_device, vert_shader)
	sdl.ReleaseGPUShader(gpu_device, frag_shader)

	camera :=
		glm.mat4Perspective(90, 800.0 / 600.0, -100, 100) *
		glm.mat4LookAt({10, 10, 10}, {0, 0, 0}, {0, 1, 0})
	model_mat := glm.mat4Translate({0, 0, 0}) * glm.mat4Scale({10, 10, 10})

	uniform := UniformBufferObject {
		mvp = camera * model_mat,
	}

	for quit := false; !quit; {
		for e: sdl.Event; sdl.PollEvent(&e); {
			if e.type == .QUIT {
				quit = true
				break
			}
		}

		model_mat =
			glm.mat4Translate({400, 300, 0}) *
			glm.mat4Rotate(
				{0, 0, 1},
				f32(f64(sdl.GetPerformanceCounter()) / f64(sdl.GetPerformanceFrequency())),
			) *
			glm.mat4Scale({100, 100, 1})
		// uniform.mvp = camera * model_mat

		cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)
		if cmdbuf == nil {
			fmt.panicf("Failed to acquire cmdbuf: %s\n", sdl.GetError())
		}

		swapchain_texture: ^sdl.GPUTexture
		swapchain_width, swapchain_height: u32
		swapchain_ok := sdl.WaitAndAcquireGPUSwapchainTexture(
			cmdbuf,
			window,
			&swapchain_texture,
			&swapchain_width,
			&swapchain_height,
		)
		if !swapchain_ok {
			fmt.panicf("Failed to acquire swapchain: %s\n", sdl.GetError())
		}

		render_pass := sdl.BeginGPURenderPass(cmdbuf, &sdl.GPUColorTargetInfo {
				load_op     = .CLEAR,
				store_op    = .DONT_CARE,
				clear_color = {0, 0, 0, 1},
				texture     = swapchain_texture,
			}, 1, nil)

		sdl.BindGPUGraphicsPipeline(render_pass, pipeline)

		sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding {
				buffer = vertex_buffer,
				offset = 0,
			}, 1)
		sdl.BindGPUIndexBuffer(render_pass, {
				buffer = index_buffer,
				offset = 0,
			}, ._32BIT)

		sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding {
				sampler = sampler,
				texture = texture,
			}, 1)

		sdl.PushGPUVertexUniformData(cmdbuf, 0, &uniform, size_of(uniform))
		sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(indices)), 1, 0, 0, 0)

		sdl.EndGPURenderPass(render_pass)

		if !sdl.SubmitGPUCommandBuffer(cmdbuf) {
			fmt.panicf("Failed to submit command buffer: %s\n", sdl.GetError())
		}
	}
}
