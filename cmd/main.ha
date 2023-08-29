use os;
use os::exec;
use strings;
use fmt;
use io;
use fs;
use path;
use time;
use getopt;
use strconv;
use log;

use raylee;
use raylee::math::{ v3, point };

use sdl2;
use sdl2::image;
use sdl2::{
    SDL_Window,
    SDL_EventType, SDL_RendererFlags, SDL_WindowFlags,
    SDL_Surface, SDL_Texture, SDL_Renderer,
};

use lua;

def MAX_FRAME_COUNT = 1000z;

type config = struct {
    width: u32, height: u32,
    samples_per_pixel: u32,
    windowing_state: (void | windowing_state),
    headless: bool,
    script: (void | str),
};

type windowing_state = struct {
    window_width: int,
    window_height: int,

    window: *SDL_Window,
    renderer: *SDL_Renderer,
    surface: nullable *SDL_Surface,
    texture: nullable *SDL_Texture,
};

export fn main() void = {
    const cmd = getopt::parse(os::args,
        "simple raytracer",
        ('v', "verbose"),
        ('w', "width", "width of the raytraced image (default: 768)"),
        ('h', "height", "height of the raytraced image (default: 432)"),
        "files..."
    );
    defer getopt::finish(&cmd);

    let config = config {
        width = 768, height = 432,
        samples_per_pixel = 5,
        headless = false,
        script = void,
        windowing_state = void,
    };

    log::setlogger(log::silent);

    for (let i = 0z; i < len(cmd.opts); i += 1) {
        let opt = cmd.opts[i];
        switch (opt.0) {
        case 'v' =>
            log::setlogger(log::default);
        case 'w' =>
            config.width = match (strconv::stou32(opt.1)) {
            case let v: u32 => yield v;
            case strconv::overflow => abort();
            case strconv::invalid =>
                fmt::fatalf("cannot parse width {}: is invalid", opt.1);
            };
        case 'h' =>
            config.height = match (strconv::stou32(opt.1)) {
            case let v: u32 => yield v;
            case strconv::overflow => abort();
            case strconv::invalid =>
                fmt::fatalf("cannot parse height {}: is invalid", opt.1);
            };
        case =>
            fmt::fatalf("bad opt: {}", opt.0);
        };
    };

    run(config)!;
};

def WINDOW_WIDTH: int = 720;
// Window height is determined at via its ratio.

fn run(config: config) (void | sdl2::error) = {
    log::printfln("dumping config...");
    log::printfln("resolution :: {}x{}", config.width, config.height);
    log::printfln("samples pp :: {}", config.samples_per_pixel);
    log::printfln("headless :: {}", config.headless);
    log::printfln("script :: {}", match (config.script) {
        case void => yield "no";
        case let script: str => yield script;
    });

    if (!config.headless) {
        match (os::exec::fork()) {
        case void => void;
        case let p: os::exec::process =>
            return run_sdl(config)!;
        case let e: os::exec::error =>
            log::fatalf("error forking process: {}", os::exec::strerror(e));
        };

        return;
    };
};

fn run_sdl(config: config) (void | sdl2::error) = {
    const ratio = config.height: f64 / config.width: f64;
    const window_width = WINDOW_WIDTH;
    const window_height = (ratio * window_width: f64): int;

    log::println("[sdl2] initializing sdl2");
    sdl2::SDL_Init(sdl2::SDL_INIT_VIDEO)?;
    defer sdl2::SDL_Quit();

    log::printfln("[sdl2] creating window with size: {}x{}", window_width, window_height);
    const window = sdl2::SDL_CreateWindow("raylee",
        sdl2::SDL_WINDOWPOS_UNDEFINED, sdl2::SDL_WINDOWPOS_UNDEFINED,
        window_width, window_height, SDL_WindowFlags::NONE
    )?;
    defer sdl2::SDL_DestroyWindow(window);

    const renderer = sdl2::SDL_CreateRenderer(window, -1, SDL_RendererFlags::NONE)?;
    defer sdl2::SDL_DestroyRenderer(renderer);

    const windowing_state = windowing_state {
        window_width = window_width,
        window_height = window_height,
        window = window,
        renderer = renderer,
        surface = null,
        texture = null,
    };

    let done = false;

    for (!done) {
        log::println("frame");

        done = update(&windowing_state)?;
        draw(&windowing_state)?;

        time::sleep(10 * time::MILLISECOND);
    };
};

fn update(state: *windowing_state) (bool | sdl2::error) = {
	let ev = sdl2::event { ... };
	for (sdl2::SDL_PollEvent(&ev)? == 1) switch (ev.event_type) {
	case SDL_EventType::QUIT =>
		return true;
	case => void;
	};

    return false;
};

fn draw(state: *windowing_state) (void | sdl2::error) = {
    let texture = match (state.texture) {
    case null => return;
    case let texture: *sdl2::SDL_Texture => yield texture;
    };

    sdl2::SDL_RenderClear(state.renderer)?;
    sdl2::SDL_RenderCopy(state.renderer, texture, null, &sdl2::SDL_Rect {
		x = 0,
		y = 0,
		w = state.window_width,
		h = state.window_height,
	})?;

    sdl2::SDL_RenderPresent(state.renderer);
};

fn run_lua_script(script_path: str) void = {
    let l = lua::luaL_newstate();
    defer lua::lua_close(l);
    lua::luaL_openlibs(l);

    const raylee_funcs = [
        lua::reg("set_camera_position", &set_camera_position),
        lua::reg("set_light_direction", &set_light_direction),
        lua::reg("set_done", &set_done),
        lua::reg_null(),
    ];

    lua::lua_newtable(l);
    lua::luaL_setfuncs(l, raylee_funcs, 0);
    lua::lua_setglobal(l, "raylee");

    lua::luaL_loadfile(l, script_path)!;
    dispatch_lua(l, 0, 0);

    let scene = global_scene();
    fmt::printfln("scene is {}x{}", scene.width, scene.height)!;

    for (let i = 0z; i < MAX_FRAME_COUNT && !scene.done; i += 1) {
        let img = raylee::render(*scene);
        let buffer: [64]u8 = [0...];
        let path = fmt::bsprintf(buffer, "target/render{:03}.ppm", i);
        raylee::save_to_file(img, path);

        match (lua::lua_getglobal(l, "update")) {
        case void => void;
        case lua::errerr => void; // for some reason ok?
        case let err: lua::error => fmt::fatal("bad");
        };

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
