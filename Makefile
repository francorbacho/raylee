HAREPATH=/usr/src/hare/stdlib:/usr/src/hare/third-party/:./third-party/hare-sdl2/
LIBS=-lc -lSDL2_image -lSDL2_mixer -lSDL2

all: raylee

raylee:
	mkdir -p target
	HAREPATH=$(HAREPATH) hare build $(LIBS) -o ./target/$@ cmd/

clean:
	rm -rf target render.ppm

.PHONY: all raylee clean
