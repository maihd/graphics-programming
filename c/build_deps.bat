@echo off

set SDL3_FOLDER=SDL-release-3.2.20

set CMAKE_COMPILER=-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_STANDARD=11 -DCMAKE_CXX_STANDARD=20
set CMAKE_LIBRARY_TARGET=-DBUILD_SHARED_LIBS=OFF

:: Building SDL3
echo Building SDL3...
pushd %SDL3_FOLDER%

if exist build (
    rmdir build /S /Q
)

mkdir build && cd build

cmake .. -GNinja %CMAKE_COMPILER% %CMAKE_LIBRARY_TARGET%

cmake --build .

cd ..

if not exist prebuilt (
    mkdir prebuilt
)

if not exist prebuilt\win64 (
    mkdir prebuilt\win64
)

copy build\SDL3-static.lib prebuilt\win64\SDL3-static.lib

popd