use os;
use strings;
use fmt;
use io;
use fs;

export fn main() void = {
    const width = 256z;
    const height = 256z;

    const filepath = "render.ppm";
    const file = match (os::create(filepath, fs::mode::USER_RW)) {
    case let file: io::file =>
        yield file;
    case let err: fs::error =>
        fmt::fatalf("Could not open file {}: {}", filepath, fs::strerror(err));
    };
    defer io::close(file)!;

    const buf: [1000240]u8 = [0...];
    let bw = len(fmt::bsprintf(buf, "P3\n{} {}\n255\n", width, height));

    for (let i = 0z; i < width; i += 1) {
        for (let j = 0z; j < height; j += 1) {
            const r = 256 * j / (width - 1);
            const g = 256 * i / (height - 1);
            const b = 0;

            if (r >= 256) r = 255;
            if (g >= 256) g = 255;

            bw += len(fmt::bsprintf(buf[bw..], "{} {} {}\n", r, g, b));
        };
    };

    io::write(file, buf[..bw])!;
};
