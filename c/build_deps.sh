SDL3_FOLDER="SDL-release-3.2.20"
SDL3_SHADERCROSS_FOLDER="SDL_shadercross"

# Detect platform for target prebuilt path
PREBUILT_FOLDER="prebuilt"
PROJECT_BUILD_SYSTEM="Ninja"

OSNAME=$(uname)
if [ "$OSNAME" == "Linux" ]; then
    PREBUILT_FOLDER="$PREBUILT_FOLDER/linux64"
    CMAKE_ARCHITECTURES=""
elif [ "$OSNAME" == "Darwin" ]; then
    PREBUILT_FOLDER="$PREBUILT_FOLDER/mac_arm64"
    PROJECT_BUILD_SYSTEM="Ninja"
    CMAKE_ARCHITECTURES="-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"
fi

# Cmake config
CMAKE_COMPILER="-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_STANDARD=11 -DCMAKE_CXX_STANDARD=20"
CMAKE_LIBRARY_TARGET="-DBUILD_SHARED_LIBS=OFF"

# Building SDL3
echo Building SDL3...
cd $SDL3_FOLDER

# rm -rf build
mkdir -p build && cd build

cmake .. -G "$PROJECT_BUILD_SYSTEM" \
    $CMAKE_ARCHITECTURES            \
    $CMAKE_COMPILER                 \
    $CMAKE_LIBRARY_TARGET           \
    -DCMAKE_INSTALL_PREFIX=../../installed_deps

cmake --build . --config Release

cmake --install . # to build SDL_shadercross

cd ..

mkdir -p $PREBUILT_FOLDER

cp installed_deps/lib/libSDL3.a $PREBUILT_FOLDER/libSDL3.a

cd ..

# Build shadercross deps
echo Building SDL3 ShaderCross dependencies...

cd $SDL3_SHADERCROSS_FOLDER/external/SPIRV-Cross

cmake -B build -S . -G "$PROJECT_BUILD_SYSTEM"  \
    $CMAKE_ARCHITECTURES                        \
    $CMAKE_COMPILER                             \
    $CMAKE_LIBRARY_TARGET                       \
    -DCMAKE_INSTALL_PREFIX=../../../installed_deps  

cmake --build build --config Release

cmake --install build

cd ../../..

# Build shadercross
echo Building SDL3 ShaderCross...

cd $SDL3_SHADERCROSS_FOLDER

# rm -rf build

cmake -B build . -G "$PROJECT_BUILD_SYSTEM" \
    $CMAKE_ARCHITECTURES                    \
    $CMAKE_COMPILER                         \
    $CMAKE_LIBRARY_TARGET                   \
    -DBUILD_SHARED_LIBS=OFF                 \
    -DSDLSHADERCROSS_SPIRVCROSS_SHARED=OFF  \
    -DSDLSHADERCROSS_DXC=OFF                \
    -DSDLSHADERCROSS_VENDORED=ON            \
    -DCMAKE_INSTALL_PREFIX=../installed_deps
    # -DSDL3_DIR=../SDL-release-3.2.20/build        

cmake --build build --config Release

cmake --install build

mkdir -p $PREBUILT_FOLDER

cp build/libSDL3_shadercross.a $PREBUILT_FOLDER/libSDL3_shadercross.a

cp ../installed_deps/lib/libspirv-cross-*.a $PREBUILT_FOLDER