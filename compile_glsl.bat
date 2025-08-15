@echo off

if not exist shaders-out (
    mkdir shaders-out
)

glslc -fshader-stage=vertex shaders/glsl/triangle.vert -o shaders-out/triangle-vert.spv
glslc -fshader-stage=fragment shaders/glsl/triangle.frag -o shaders-out/triangle-frag.spv