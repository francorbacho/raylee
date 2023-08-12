# raylee
Simple raytracer in [Hare](https://harelang.org).

## Build instructions
Until [the patch](https://lists.sr.ht/~sircmpwn/hare-users/patches/43535) is accepted,
you need to apply the patch manually to `hare-sdl`:

```bash
$ rm -rf third-party/hare-sdl2/ && git clone 'https://git.sr.ht/~sircmpwn/hare-sdl2' third-party/hare-sdl2/
$ (cd third-party/hare-sdl2 && curl -s https://lists.sr.ht/~sircmpwn/hare-users/patches/43535/mbox | git am -3)
$ make
```

