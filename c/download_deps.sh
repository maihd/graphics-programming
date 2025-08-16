if [ ! -d "SDL_shadercross" ]; then
    git clone https://github.com/libsdl-org/SDL_shadercross --depth=1

    cd SDL_shadercross/external

    ./download.sh

    cd ../..
fi