@echo off

set SDL3_FOLDER=SDL-release-3.2.20
set SDL3_SHADERCROSS_FOLDER=SDL_shadercross

set CMAKE_COMPILER=-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_STANDARD=11 -DCMAKE_CXX_STANDARD=20
set CMAKE_LIBRARY_TARGET=-DBUILD_SHARED_LIBS=OFF
set CMAKE_INSTALL_PREFIX=-DCMAKE_INSTALL_PREFIX=../../installed_deps

:: Building SDL3
echo Building SDL3...
pushd %SDL3_FOLDER%

if exist build (
    rmdir build /S /Q
)

mkdir build && cd build

cmake .. -GNinja %CMAKE_COMPILER% %CMAKE_LIBRARY_TARGET% %CMAKE_INSTALL_PREFIX%

cmake --build .

cmake --install .

cd ..

if not exist prebuilt (
    mkdir prebuilt
)

if not exist prebuilt\win64 (
    mkdir prebuilt\win64
)

copy build\SDL3-static.lib prebuilt\win64\SDL3-static.lib

popd

pushd %SDL3_SHADERCROSS_FOLDER%

pushd external\spirv-cross

if exist build (
    rmdir build /S /Q
)

mkdir build && cd build

cmake .. -GNinja %CMAKE_COMPILER% %CMAKE_LIBRARY_TARGET% -DCMAKE_INSTALL_PREFIX=../../../../installed_deps

cmake --build .

cmake --install .

cd ..

popd

if exist build (
    rmdir build /S /Q
)

mkdir build && cd build

cmake .. -GNinja %CMAKE_COMPILER% %CMAKE_LIBRARY_TARGET% %CMAKE_INSTALL_PREFIX% ^
    -DSDLSHADERCROSS_SPIRVCROSS_SHARED=OFF ^
    -DSDLSHADERCROSS_DXC=OFF ^
    -DSDLSHADERCROSS_VENDORED=ON

cmake --build .

cmake --install .

cd ..

if not exist prebuilt (
    mkdir prebuilt
)

if not exist prebuilt\win64 (
    mkdir prebuilt\win64
)

copy build\SDL3_shadercross.lib prebuilt\win64\SDL3_shadercross.lib
copy external\SPIRV-Cross\build\spirv-cross-*.lib prebuilt\win64\spirv-cross-cd.lib

popd