@echo off

set SDL3_FOLDER=../SDL-Release-3.2.20

clang main.c -I%SDL3_FOLDER%/include %SDL3_FOLDER%/prebuilt/win64/SDL3-static.lib -D_CRT_SECURE_NO_WARNINGS