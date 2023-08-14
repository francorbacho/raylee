# raylee
Simple raytracer in [Hare](https://harelang.org).

## Build instructions
```bash
$ make
$ ./target/raylee # sdl2
...
$ ./target/raylee scripts/move_camera.lua # writes frames to to target/render000.ppm
...
$ convert -delay 1 target/render???.ppm target/render.gif
```

