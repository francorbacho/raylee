use os;
use strings;
use fmt;
use io;
use fs;
use path;
use time;

use raylee;
use raylee::math::{ v3, point };

use sdl2;
use sdl2::image;
use sdl2::{
    SDL_EventType, SDL_RendererFlags, SDL_WindowFlags,
    SDL_Surface, SDL_Texture,
};

use lua;

def MAX_FRAME_COUNT = 1000z;

type windowing_state = struct {
    done: bool,
    window_width: int,
    window_height: int,
    surface: nullable *SDL_Surface,
    texture: nullable *SDL_Texture,
    render: *sdl2::SDL_Renderer,
};

export fn main() void = {
    if (len(os::args) == 1) {
        run_sdl(768, 432)!;
        return;
    };

    run_lua_script(os::args[1]);
};

fn run_sdl(width: u32, height: u32) (void | fs::error | sdl2::error) = {
    const factor = 4;

    const window_width = 800;
    const window_height = (window_width: f64 * height: f64 / width: f32): int;

    sdl2::SDL_Init(sdl2::SDL_INIT_VIDEO)?;
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

    const before = time::now(time::clock::REALTIME);
    const result: raylee::image = raylee::render(raylee::default_scene);
    const after = time::now(time::clock::REALTIME);
    const took = time::diff(before, after) / 1e6;

    fmt::errorf("raytracing took {} ms\n", took)!;

    let surface = sdl2::SDL_CreateRGBSurface(
        0,
        result.width: int, result.height: int,
        32, 0, 0, 0, 0,
    )?;

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

    let texture = sdl2::SDL_CreateTextureFromSurface(state.render, surface)?;

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

fn run_lua_script(script_path: str) void = {
    let l = lua::luaL_newstate();
    defer lua::lua_close(l);
    lua::luaL_openlibs(l);

    const raylee_funcs = [
        lua::reg("set_camera_position", &set_camera_position),
        lua::reg("set_done", &set_done),
        lua::reg_null(),
    ];

    lua::lua_newtable(l);
    lua::luaL_setfuncs(l, raylee_funcs, 0);
    lua::lua_setglobal(l, "raylee");

    const width = 256;
    const height = 144;
    const aspect_ratio: f64 = width: f64 / height: f64;

    const viewport_height = 2.0;

    let scene = raylee::scene {
        width = 256,
        height = 144,
        camera = raylee::camera_settings {
            viewport_size = v3(viewport_height * aspect_ratio, viewport_height, 1.0),
            focal_length = 1.0,
            ...
        },
    };

    lua::luaL_loadfile(l, script_path)!;
    dispatch_lua(l, 0, 0);

    for (let i = 0z; i < MAX_FRAME_COUNT && !done; i += 1) {
        let img = raylee::render(scene);
        let buffer: [64]u8 = [0...];
        let path = fmt::bsprintf(buffer, "target/render{:03}.ppm", i);
        raylee::save_to_file(img, path);

        match (lua::lua_getglobal(l, "update")) {
        case void => void;
        case lua::errerr => void; // for some reason ok?
        case let err: lua::error => fmt::fatal("bad");
        };

        scene.camera.position = camera_position;

        lua::lua_pushinteger(l, i: int);
        dispatch_lua(l, 1, 0);

        lua::lua_pop(l, lua::lua_gettop(l));
    };
};

fn dispatch_lua(l: *lua::lua_State, nargs: int, nret: int) void = {
    match (lua::lua_pcall(l, nargs, nret, 0)) {
    case void =>
        for (let i = 0i; i < nret; i += 1)
            lua::lua_pop(l, lua::lua_gettop(l));
    case let err: lua::error =>
        let errmsg = lua::lua_tostring(l, lua::lua_gettop(l));
        fmt::printfln("err: {}: {}", lua::strerror(err), errmsg)!;
    };
};

let done: bool = false;
let camera_position: point = point { ... };

fn set_camera_position(l: *lua::lua_State) void = {
    let x = lua::luaL_checknumber(l, lua::lua_gettop(l) - 0);
    let y = lua::luaL_checknumber(l, lua::lua_gettop(l) - 1);
    let z = lua::luaL_checknumber(l, lua::lua_gettop(l) - 2);

    camera_position.x = x;
    camera_position.y = y;
    camera_position.z = z;
};

fn set_done(l: *lua::lua_State) void = {
    let done_idx = lua::lua_gettop(l);
    if (!lua::lua_isboolean(l, done_idx)) {
        lua::luaL_typeerror(l, done_idx, "bool");
    };

    done = lua::lua_toboolean(l, done_idx);
};
