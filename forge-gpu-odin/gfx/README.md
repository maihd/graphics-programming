# Mid level graphics framework
Main purpose to avoid doing repeat works, but without hidden the actual code of SDL3 GPU.

## Philosophy
- Just provide simple, liteweight wrappers
- Not force to use, for some example we still write origin api
- All API must be export to end program

## Depedencies and features
- ImGui
- TinyObj, cgltf
- SDL3 ShaderCross
- Application Init & Deinit
- Shaders creating & loading
- Textures creating & loading
- Models/Materials creating & loading

## Things not included
Thoses things are required to written by hand. Specially for learning purpose.
- Main loop
- Destroy objects
- GPU Pipelines
- GPU Command buffers
- GPU Render pass
- Assets Pipeline
- Audio
- Physics
- Shapes

## Odin battery included
- IO (core:os, core:nbio)
- Time (core:time)
- Math (core:math/linalg/glsl)
- Format (core:fmt)
- Image (core:image)
- Memory allocator (core:mem, core:mem/virtual)
- Cmdline arguments (core:flags)
- Containers (string, slice, array, dynamic array, map)
- Reflection (core:reflect)
- SDL3 (vendor:sdl3)
- cgltf (vendor:cgltf)