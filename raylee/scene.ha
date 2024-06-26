use fmt;
use fs;
use os;
use io;

use math::random;

use raylee::math::{
    vector2, vector3, point, color,
    v3,
};

export type image = struct {
    width: uint,
    height: uint,
    pixels: []color,
};

export type scene = struct {
    width: u32, height: u32,
    camera: camera_settings,
    light_direction: vector3,
    surfaces: surface_compose,

    rng: random::random,
    samples_per_pixel: uint,

    done: bool,
};

export fn default_scene() scene = scene {
    width = 256,
    height = 144,
    camera = camera_settings {
        position = point { ... },
        viewport_size = vector3 { x = 3.555, y = 2.0, z = 0.0 },
        focal_length = 1.0,
    },

    light_direction = vector3 { x = 0.72, y = 0.27, z = 0.63 },
    surfaces = compose(),

    rng = 0: random::random,
    samples_per_pixel = 10,

    done = false,
};

export type camera_settings = struct {
    position: point,
    viewport_size: vector2,
    focal_length: f64,
};

export fn save_to_file(image: image, filepath: str) void = {
    const file = match (os::create(filepath, fs::mode::USER_RW)) {
        case let file: io::file =>
            yield file;
        case let err: fs::error =>
            fmt::fatalf("Could not open file {}: {}", filepath, fs::strerror(err));
    };
    defer io::close(file)!;

    fmt::fprintf(file, "P3\n")!;
    fmt::fprintf(file, "{} {}\n", image.width, image.height)!;
    fmt::fprintf(file, "255\n")!;

    for (let i = 0z; i < len(image.pixels); i += 1) {
        const col = image.pixels[i];
        const r = col.x: u8;
        const g = col.y: u8;
        const b = col.z: u8;

        fmt::fprintf(file, "{} {} {}\n", r, g, b)!;
    };
};
