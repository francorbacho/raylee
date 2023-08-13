HAREPATH := $(shell hare version -v | grep HAREPATH | cut -d'	' -f 2)
HAREPATH := $(HAREPATH):./third-party/hare-lua/
HAREPATH := $(HAREPATH):./third-party/hare-sdl2/

LIBS := -lc -lSDL2_image -lSDL2_mixer -lSDL2
LIBS := $(LIBS) -llua -lm

all: raylee

raylee:
	mkdir -p target
	HAREPATH=$(HAREPATH) hare build $(LIBS) -o ./target/$@ cmd/

clean:
	rm -rf target render.ppm

.PHONY: all raylee clean
