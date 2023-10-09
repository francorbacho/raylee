# raylee
Simple raytracer in [Hare](https://harelang.org).

## Dependencies
- `hare` — (last tested with `hare-git r3344.ec7fe6e0-1` on ArchLinux)
- `make`
- `SDL2`
- `SDL2_mixer`
- `SDL2_image`
- `lua5.3`

## Build instructions
```bash
$ make
$ ./target/raylee # sdl2
...
$ ./target/raylee scripts/move-camera.lua # writes frames to to target/render000.ppm
...
$ convert -delay 1 target/render???.ppm target/render.gif
```

