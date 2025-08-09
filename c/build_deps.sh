SDL3_FOLDER="SDL-release-3.2.20"

# Detect platform for target prebuilt path
PREBUILT_FOLDER="prebuilt"

OSNAME=$(uname)
if [ "$OSNAME" == "Linux" ]; then
    PREBUILT_FOLDER="$PREBUILT_FOLDER/linux64"
elif [ "$OSNAME" == "Darwin" ]; then
    PREBUILT_FOLDER="$PREBUILT_FOLDER/mac_arm64"
    CMAKE_ARCHITECTURES="-DCMAKE_ARCHITECTURES=arm64"
fi

# Cmake config
CMAKE_COMPILER="-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_STANDARD=11 -DCMAKE_CXX_STANDARD=20"
CMAKE_LIBRARY_TARGET="-DBUILD_SHARED_LIBS=OFF"

# Building SDL3
echo Building SDL3...
cd $SDL3_FOLDER

rm -rf build
mkdir build && cd build

cmake .. -GNinja $CMAKE_COMPILER $CMAKE_LIBRARY_TARGET $CMAKE_ARCHITECTURES

cmake --build .

cd ..

mkdir -p $PREBUILT_FOLDER

cp build/libSDL3.a $PREBUILT_FOLDER/libSDL3.a

cd ..