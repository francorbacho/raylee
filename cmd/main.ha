use os;
use strings;
use fmt;
use io;
use fs;

use raylee;

use sdl2;
use sdl2::{
    SDL_EventType, SDL_RendererFlags, SDL_WindowFlags,
    SDL_Surface, SDL_Texture,
};

use sdl2::image;

type windowing_state = struct {
    done: bool,
    window_width: int,
    window_height: int,
    surface: nullable *SDL_Surface,
    texture: nullable *SDL_Texture,
    render: *sdl2::SDL_Renderer,
};

export fn main() void = {
    run(256, 144)!;
};

fn run(width: u32, height: u32) (void | fs::error | sdl2::error) = {
    const factor = 4;

    const window_width = width: int * factor;
    const window_height = height: int * factor;

    sdl2::SDL_Init(sdl2::SDL_INIT_VIDEO)!;
    defer sdl2::SDL_Quit();

	const win = sdl2::SDL_CreateWindow("raylee",
		sdl2::SDL_WINDOWPOS_UNDEFINED, sdl2::SDL_WINDOWPOS_UNDEFINED,
        window_width, window_height, SDL_WindowFlags::NONE
    )?;
	defer sdl2::SDL_DestroyWindow(win);

	const render = sdl2::SDL_CreateRenderer(win, -1, SDL_RendererFlags::NONE)?;
	defer sdl2::SDL_DestroyRenderer(render);

    let state = windowing_state {
        render = render,
        window_width = window_width,
        window_height = window_height,
        ...
    };
    defer free(state.surface);

    const result: raylee::image = raylee::scene(width, height);

    let surface = sdl2::SDL_CreateRGBSurface(
        0,
        result.width: int, result.height: int,
        32, 0, 0, 0, 0,
    )!;

    let pixels: []u32 = [];

    for (let i = 0z; i < result.width * result.height; i += 1) {
        let color = result.pixels[i];
        let r = color.x: u32;
        let g = color.y: u32;
        let b = color.z: u32;

        let color: u32 = (r << 16) | (g << 8) | b;
        append(pixels, color);
    };

    surface.pixels = &pixels[0];

    let texture = sdl2::SDL_CreateTextureFromSurface(state.render, surface)!;

    state.surface = surface;
    state.texture = texture;

	for (!state.done) {
        update(&state)?;
        draw(&state)?;
		sdl2::SDL_Delay(1000 / 30);
	};
};

fn update(state: *windowing_state) (void | sdl2::error) = {
	let ev = sdl2::event { ... };
	for (sdl2::SDL_PollEvent(&ev)? == 1) switch (ev.event_type) {
	case SDL_EventType::QUIT =>
		state.done = true;
		return;
	case => void;
	};
};

fn draw(state: *windowing_state) (void | sdl2::error) = {
    let texture = match (state.texture) {
    case null => return;
    case let texture: *sdl2::SDL_Texture => yield texture;
    };

    sdl2::SDL_RenderClear(state.render)?;
    sdl2::SDL_RenderCopy(state.render, texture, null, &sdl2::SDL_Rect {
		x = 0,
		y = 0,
		w = state.window_width,
		h = state.window_height,
	})?;

    sdl2::SDL_RenderPresent(state.render);
};
