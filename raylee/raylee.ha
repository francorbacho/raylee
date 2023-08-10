use raylee::math;
use raylee::math::{ rgb, color, vector3, point, ray, splat };

use fmt;

export fn scene() void = {
    const camera_position = point { ... };

    const focal_length: f64 = 1.0;
    const aspect_ratio: f64 = 16.0 / 9.0;

    const height: uint = 144;
    const width: uint = (height: f64 * aspect_ratio): uint;

    const viewport_dim = {
        const viewport_height: f64 = 2.0;
        const viewport_width: f64 = viewport_height * aspect_ratio;
        yield vector3 { x = viewport_width, y = viewport_height, z = 1.0 };
    };

    const viewport_pixel_dim = {
        let tmp = viewport_dim;
        raylee::math::div(&tmp, &vector3 { x = width: f64, y = height: f64, z = 1.0 });
        yield tmp;
    };

    const viewport_topleft = {
        let tmp = camera_position;

        raylee::math::add(&tmp, &vector3 { z = -focal_length, ... });
        raylee::math::add(&tmp, &vector3 {
            x = -viewport_dim.x / 2.0,
            y = viewport_dim.y / 2.0,
            ...
        });

        yield tmp;
    };

    const pixel_00 = {
        let tmp1 = viewport_topleft;
        let tmp2 = viewport_pixel_dim;

        raylee::math::div(&tmp2, &splat(2.0));
        raylee::math::add(&tmp1, &tmp2);

        yield tmp1;
    };

    fmt::printf("P3\n{} {}\n 255\n", width, height)!;

    for (let j = 0z; j < height; j += 1) {
        for (let i = 0z; i < width; i += 1) {
            const pixel_ji = {
                let tmp = viewport_pixel_dim;
                raylee::math::mul(&tmp, &vector3 { x = i: f64, y = j: f64, ... });
                raylee::math::add(&tmp, &pixel_00);
                yield tmp;
            };

            const ray_ji = ray {
                point = pixel_ji,
                direction = {
                    let tmp = pixel_ji;
                    raylee::math::sub(&pixel_ji, &camera_position);
                    yield tmp;
                },
            };

            let color_ji = ray_color(ray_ji);
            raylee::math::mul(&color_ji, &splat(255.0));
            fmt::printf("{} {} {}\n", color_ji.x: int, color_ji.y: int, color_ji.z: int)!;
        };
    };
};

fn ray_color(ray: ray) color = {
    const direction_unit = {
        let tmp = ray.direction;
        raylee::math::unit(&tmp);
        yield tmp;
    };

    const blue = rgb(0.5, 0.7, 1.0);
    const white = rgb(1.0, 1.0, 1.0);

    return raylee::math::lerp(direction_unit.y, blue, white);
};
