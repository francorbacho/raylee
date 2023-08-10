all: raylee

raylee:
	mkdir -p target
	hare build -o ./target/$@ cmd/

clean:
	rm -rf target render.ppm

.PHONY: all raylee clean
