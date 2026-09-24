package gfx

import "core:fmt"
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

	panic("Unsupported stage!")
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
	_err: Maybe(string),
) {
	_shader, _err = create_shader_str(gpu_device, string(hlsl_src), stage, entry_point)
	return
}

create_shader_str :: proc(
	gpu_device: ^sdl.GPUDevice,
	hlsl_src: string,
	stage: sdl.GPUShaderStage,
	entry_point: string,
) -> (
	_shader: ^sdl.GPUShader,
	_err: Maybe(string),
) {
	entry_point_cstr := strings.clone_to_cstring(entry_point)
	defer delete(entry_point_cstr)

	hlsl_src_cstr := strings.clone_to_cstring(hlsl_src)
	defer delete(hlsl_src_cstr)

	code_size: uint
	code := shadercross.CompileSPIRVFromHLSL(
		{
			entrypoint = entry_point_cstr,
			shader_stage = get_shadercross_stage(stage),
			source = hlsl_src_cstr,
		},
		&code_size,
	)
	if code == nil {
		_err = string(sdl.GetError())
		return
	}
	defer sdl.free(code)

	metadata := shadercross.ReflectGraphicsSPIRV(code, code_size, 0)
	defer sdl.free(metadata)

	resource_info := metadata != nil ? metadata.resource_info : {}

	_shader = shadercross.CompileGraphicsShaderFromSPIRV(
		gpu_device,
		{
			bytecode = code,
			bytecode_size = code_size,
			entrypoint = entry_point_cstr,
			shader_stage = get_shadercross_stage(stage),
		},
		resource_info,
		0,
	)
	if _shader == nil {
		_err = string(sdl.GetError())
	}
	return
}

load_shader :: proc(
	gpu_device: ^sdl.GPUDevice,
	file: string,
	entry_point: string,
	stage: sdl.GPUShaderStage,
	allocator := context.allocator,
) -> (
	_shader: ^sdl.GPUShader,
	_err: Maybe(string),
) {
	source, err := os.read_entire_file(file, allocator)
	if err != nil {
		_err = fmt.tprintf("Failed to load shader file: %v", err)
		return
	}

	_shader, _err = create_shader(gpu_device, source, stage, entry_point)
	return
}
