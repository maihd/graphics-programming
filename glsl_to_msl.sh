glslc -fshader-stage=vertex shaders/glsl/triangle.vert -o shaders-out/triangle-vert.spv

mkdir -p shaders-out

spirv-cross --msl shaders-out/triangle-vert.spv --output shaders-out/triangle-vert.msl

glslc -fshader-stage=fragment shaders/glsl/triangle.frag -o shaders-out/triangle-frag.spv

mkdir -p shaders-out

spirv-cross --msl shaders-out/triangle-frag.spv --output shaders-out/triangle-frag.msl