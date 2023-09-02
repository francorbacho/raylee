// Values are percentages.
export type region = struct {
    x1: f32, y1: f32,
    x2: f32, y2: f32,
};

// Discrete values.
export type dregion = struct {
    x1: size, y1: size,
    x2: size, y2: size,
};

export fn calc_pixels_from_region(region: region, width: u32, height: u32) dregion =
{
    const x1 = (region.x1 * width: f32): u32;
    const y1 = (region.y1 * height: f32): u32;
    const x2 = (region.x2 * width: f32): u32;
    const y2 = (region.y2 * height: f32): u32;

    return dregion { x1 = x1, y1 = y1, x2 = x2, y2 = y2 };
};
