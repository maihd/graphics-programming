# No Graphics API shorts explain
Shorts explain, TLDR version for lazy developers from article: https://www.sebastianaaltonen.com/blog/no-graphics-api

## Core ideas
- Using direct 64-bit pointer, data can be shared
- Avoid descriptor
- Compute by default
- Simpler and more controls, can be better performant
- Bindless and indirect rendering

## Usable libraries
- From the author of the articles: https://github.com/sebbbi/NoGraphicsAPI
- Odin version: https://github.com/leotmp/no_gfx_api

## Topics
- Memory
- Modern data
- Root arguments
- Texture bindings
- Shader pipelines
- Static constants
- Barriers and fences
- Command buffers
- Graphics shaders
- Raster pipelines
- Graphics shader bindings
- Rasterizer state
- Indirect drawing
- Render passes

## Min Spec Hardware
- Nvidia Turing
- AMD RDNA2
- Intel Alchemist / Xe1
- Apple M1 / A14
- ARM Mali-G710
- Qualcomm Adreno 650
- PowerVR DXT

## Additional resources
- https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/6763.2026_2D00_mmg_2D00_seb_2D00_gfx_2D00_api.pdf