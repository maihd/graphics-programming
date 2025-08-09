OSNAME=$(uname)
PREBUILT_FOLDER="prebuilt"

if [ "$OSNAME" == "Linux" ]; then
    PREBUILT_FOLDER="$PREBUILT_FOLDER/linux64"
elif [ "$OSNAME" == "Darwin" ]; then
    PREBUILT_FOLDER="$PREBUILT_FOLDER/mac_arm64"
    CMAKE_ARCHITECTURES="-DCMAKE_ARCHITECTURES=arm64"
fi

SDL3_FOLDER="../SDL-release-3.2.20"

clang main.c -I$SDL3_FOLDER/include $SDL3_FOLDER/$PREBUILT_FOLDER/libSDL3.a