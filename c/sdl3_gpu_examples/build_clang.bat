@echo off

set SDL3_FOLDER=../SDL-Release-3.2.20

set WIN32_LIBS=^
    -lKernel32 -lUser32 -lGdi32 -lShell32 -lWinmm -lOle32 -lVersion ^
    -lCfgMgr32 -lImm32 -lSetupapi -lAdvapi32 -lOleAut32 ^
    -lMsvcrt


clang main.c -I%SDL3_FOLDER%/include %SDL3_FOLDER%/prebuilt/win64/SDL3-static.lib -D_CRT_SECURE_NO_WARNINGS %WIN32_LIBS%