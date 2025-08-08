@echo off

set INCLUDE_DIRS=-I3rd_party/wgpu-native/include -I../vectormath/include

clang src\main.c -o webgpu_demos.exe %INCLUDE_DIRS% 3rd_party/wgpu-native/lib/wgpu_native.lib -std=c11