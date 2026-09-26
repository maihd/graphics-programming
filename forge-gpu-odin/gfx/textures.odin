package gfx

import "core:image/png"
import "core:log"
import "core:mem"
import "core:strings"

import sdl "vendor:sdl3"

load_texture :: proc(gpu_device: ^sdl.GPUDevice, filename: string) -> (^sdl.GPUTexture, int, int) {
	TEMP_GUARD()

	full_path := strings.join({#directory, "..", "assets", filename}, "/", context.temp_allocator)

	img, err := png.load_from_file(full_path, {.alpha_add_if_missing}, context.temp_allocator)
	if err != nil {
		log.panicf("Failed to load image %s. Error: %v", filename, err)
	}
	ensure(img.width > 0)
	ensure(img.height > 0)
	ensure(img.channels == 4)

	texture := sdl.CreateGPUTexture(
		gpu_device,
		{
			type = .D2,
			format = .R8G8B8A8_UNORM,
			width = u32(img.width),
			height = u32(img.height),
			layer_count_or_depth = 1,
			num_levels = 1,
			usage = {.SAMPLER},
		},
	)
	sdl_ensure(texture != nil)

	upload_texture: {
		pixels := img.pixels.buf[img.pixels.off:]

		transfer_buffer := sdl.CreateGPUTransferBuffer(
			gpu_device,
			{usage = .UPLOAD, size = u32(len(pixels))},
		)
		sdl_ensure(transfer_buffer != nil)
		defer sdl.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)

		transfer_data := sdl.MapGPUTransferBuffer(gpu_device, transfer_buffer, false)
		mem.copy(transfer_data, raw_data(pixels), len(pixels))
		sdl.UnmapGPUTransferBuffer(gpu_device, transfer_buffer)

		cmdbuf := sdl.AcquireGPUCommandBuffer(gpu_device)
		sdl_ensure(cmdbuf != nil)

		copy_pass := sdl.BeginGPUCopyPass(cmdbuf)
		sdl.UploadToGPUTexture(
			copy_pass,
			{transfer_buffer = transfer_buffer, offset = 0},
			{texture = texture, w = u32(img.width), h = u32(img.height), d = 1},
			false,
		)
		sdl.EndGPUCopyPass(copy_pass)

		sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdbuf))
	}

	return texture, img.width, img.height
}
