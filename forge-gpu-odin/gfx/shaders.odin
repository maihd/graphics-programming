package gfx

import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"

import shadercross "sdl3_shadercross"
import sdl "vendor:sdl3"

@(private = "file")
get_shadercross_stage :: proc(stage: sdl.GPUShaderStage) -> shadercross.ShaderStage {
	switch stage {
	case .VERTEX:
		return .VERTEX

	case .FRAGMENT:
		return .FRAGMENT
	}

	log.panic("Unsupported stage!")
}

create_shader :: proc {
	create_shader_bytes,
	create_shader_str,
}

create_shader_bytes :: proc(
	gpu_device: ^sdl.GPUDevice,
	hlsl_src: []u8,
	stage: sdl.GPUShaderStage,
	entry_point: string,
) -> (
	_shader: ^sdl.GPUShader,
) {
	_shader = create_shader_str(gpu_device, string(hlsl_src), stage, entry_point)
	return
}

create_shader_str :: proc(
	gpu_device: ^sdl.GPUDevice,
	hlsl_src: string,
	stage: sdl.GPUShaderStage,
	entry_point: string,
) -> (
	_shader: ^sdl.GPUShader,
) {
	TEMP_GUARD()

	hlsl_src_cstr := strings.clone_to_cstring(hlsl_src, context.temp_allocator)
	entry_point_cstr := strings.clone_to_cstring(entry_point, context.temp_allocator)

	spirv_size: uint
	spirv := shadercross.CompileSPIRVFromHLSL(
		{
			entrypoint = entry_point_cstr,
			shader_stage = get_shadercross_stage(stage),
			source = hlsl_src_cstr,
		},
		&spirv_size,
	)
	sdl_ensure(spirv != nil)
	defer sdl.free(spirv)

	metadata := shadercross.ReflectGraphicsSPIRV(spirv, spirv_size, 0)
	defer sdl.free(metadata)

	resource_info := metadata != nil ? metadata.resource_info : {}

	_shader = shadercross.CompileGraphicsShaderFromSPIRV(
		gpu_device,
		{
			bytecode = spirv,
			bytecode_size = spirv_size,
			entrypoint = entry_point_cstr,
			shader_stage = get_shadercross_stage(stage),
		},
		resource_info,
		0,
	)
	sdl_ensure(_shader != nil)
	return
}

load_shader :: proc(
	gpu_device: ^sdl.GPUDevice,
	filename: string,
	entry_point: string,
	stage: sdl.GPUShaderStage,
	allocator := context.temp_allocator,
) -> (
	_shader: ^sdl.GPUShader,
) {
	TEMP_GUARD()

	full_path := strings.join(
		{#directory, "..", "assets", "shaders", filename},
		"/",
		context.temp_allocator,
	)

	source, err := os.read_entire_file(full_path, allocator)
	if err != nil {
		log.panicf("Failed to load shader file (%s): %v", filename, err)
	}

	_shader = create_shader(gpu_device, source, stage, entry_point)
	return
}
