src = \
    ./src/main.ha

all: raytracer

raytracer:
	mkdir -p target
	hare build -o target/$@ src/

clean:
	rm -rf target

.PHONY: all raytracer clean
