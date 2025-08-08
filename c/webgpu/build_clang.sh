INCLUDE_DIRS="-I3rd_party/wgpu-native/include -I../vectormath/include"
LIBRARY_DIRS="3rd_party/wgpu-native/lib/mac_arm64"


clang src/main.c -o webgpu_demos $INCLUDE_DIRS $LIBRARY_DIRS/libwgpu_native.a -std=c11
