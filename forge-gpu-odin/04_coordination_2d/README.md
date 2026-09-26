# SDL3 GPU Coordination 2D

## Learned from this lesson
- Use gfx to avoid initialization, runtime setup. But keep raw SDL3 GPU objects code.
- Avoid rewritten load_shader/create_shader with gfx.load_shader/gfx.create_shader
- Avoid rewritten load_texture/create_texture with gfx.load_texture/gfx.create_texture
- 2D Coordination and math application. Shader uniform.