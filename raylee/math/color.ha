export type color = vector3;

export fn rgb(r: f64, g: f64, b: f64) color = color { x = r, y = g, z = b };

export fn lerp(v: f64, c1: color, c2: color) color = {
    return rgb(
        c2.x * v + c1.x * (1.0 - v),
        c2.y * v + c1.y * (1.0 - v),
        c2.z * v + c1.z * (1.0 - v),
    );
};
