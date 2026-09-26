package forge_gpu_odin

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

ODIN_EXE_DEFAULT :: "odin"
BUILD_DIR :: #directory + "build"

main :: proc() {
	if !check_odin_installed() {
		fmt.eprintfln("Odin is not installed, or not add to env path")
		return
	}

	pattern := os.args[1]
	example_path := find_example_path(pattern)
	if example_path == nil {
		fmt.eprintfln("No example match with pattern: %s", pattern)
		return
	}

	run_example(example_path.(string))
	fmt.printfln("")
}

check_odin_installed :: proc(odin_exe := ODIN_EXE_DEFAULT) -> bool {
	state, stdout, stderr, err := os.process_exec(
		{command = {odin_exe, "-version"}},
		allocator = context.allocator,
	)
	if err != nil {
		return false
	}
	defer {
		delete(stdout)
		delete(stderr)
	}

	return true
}

find_example_path :: proc(pattern: string) -> Maybe(string) {
	file, file_err := os.open(#directory)
	if file_err != nil {
		unreachable()
	}

	dir, dir_err := os.read_all_directory(file, allocator = context.allocator)
	if dir_err != nil {
		unreachable()
	}
	defer os.file_info_slice_delete(dir, context.allocator)

	for info in dir {
		if info.type == .Directory && strings.contains(info.name, pattern) {
			return strings.clone(info.fullpath)
		}
	}

	return nil
}

run_example :: proc(example_path: string, odin_exe := ODIN_EXE_DEFAULT) {
	if !os.exists(BUILD_DIR) {
		_ = os.mkdir(BUILD_DIR)
	}

	output_path, _ := strings.join({BUILD_DIR, "/", filepath.stem(example_path), ".exe"}, "")
	defer delete(output_path)

	output_option := strings.join({"-out:", output_path}, "")
	defer delete(output_option)

	p, err := os.process_start(
		{
			command = {odin_exe, "build", example_path, output_option, "-debug"},
			stdout = os.stdout,
			stderr = os.stderr,
		},
	)
	if err != nil {
		fmt.eprintfln("Failed to run examples: %v", err)
	}

	_, _ = os.process_wait(p)

	gfx_bin_dir :: #directory + "gfx_bin"
	gfx_bin_files :: []string {
		"dxcompiler.dll",
		"dxil.dll",
		"SDL3_shadercross.dll",
		"sdl3.dll",
		"spirv-cross-c-shared.dll",
	}
	for bin_file in gfx_bin_files {
		dst_file, _ := filepath.join({BUILD_DIR, bin_file})
		src_file, _ := filepath.join({gfx_bin_dir, bin_file})
		if !os.exists(dst_file) {
			_ = os.copy_file(dst_file, src_file)
		}
	}

	p, err = os.process_start({command = {output_path}, stdout = os.stdout, stderr = os.stderr})
	if err != nil {
		fmt.eprintfln("Failed to run examples: %v", err)
	}

	_, _ = os.process_wait(p)
}
