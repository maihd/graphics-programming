@echo off

set SDL3_FOLDER=../SDL-release-3.2.20
set SDL3_SHADERCROSS_FOLDER=../SDL_shadercross

set PREBUILT_FOLDER=prebuilt/win64

set WIN32_LIBS=^
    -lKernel32 -lUser32 -lGdi32 -lShell32 -lWinmm -lOle32 -lVersion ^
    -lCfgMgr32 -lImm32 -lSetupapi -lAdvapi32 -lOleAut32 ^
    -lMsvcrtd

set SHADERCROSS_LIBS=^
    -I%SDL3_SHADERCROSS_FOLDER%/include                             ^
    -L%SDL3_SHADERCROSS_FOLDER%/%PREBUILT_FOLDER%                   ^
    -lSDL3_shadercross                                              ^
    -lspirv-cross-cored -lspirv-cross-cd  -lspirv-cross-cppd        ^
    -lspirv-cross-msld -lspirv-cross-hlsld -lspirv-cross-glsld      ^
    -lspirv-cross-reflectd -lspirv-cross-utild                      ^
    -lstdc++

clang main.c -I%SDL3_FOLDER%/include %SDL3_FOLDER%/%PREBUILT_FOLDER%/SDL3-static.lib -D_CRT_SECURE_NO_WARNINGS %WIN32_LIBS% %SHADERCROSS_LIBS%