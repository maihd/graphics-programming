@echo off

set INCLUDE_DIRS=-I3rd_party/wgpu-native/include -I../vectormath/include
set LIBRARY_DIRS=-L3rd_party/wgpu-native/lib/win64

clang src\main.c -o webgpu_demos.exe %INCLUDE_DIRS% %LIBRARY_DIRS% -lwgpu_native -std=c11