use errors;
use log;
use net;
use net::ip;
use net::tcp;
use time;
use unix::signal;

use ev;

use sdl2;
use sdl2::image;
use sdl2::{
    SDL_Window,
    SDL_EventType, SDL_RendererFlags, SDL_WindowFlags,
    SDL_Surface, SDL_Texture, SDL_Renderer,
};

type rt_state = struct {
    loop: *ev::loop,
    config: *config,
    windowing_state: *windowing_state,
};

type windowing_state = struct {
    window_width: int,
    window_height: int,
    window: *SDL_Window,
    renderer: *SDL_Renderer,
    surface: nullable *SDL_Surface,
    texture: nullable *SDL_Texture,
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

    let loop = ev::newloop()!;
    defer ev::finish(&loop);

    let rt_state = rt_state {
        loop = &loop,
        config = &config,
        windowing_state = &windowing_state,
    };

    const socket = match (ev::listen_tcp(&loop, ip::LOCAL_V4, PORT)) {
    case let err: net::error =>
        log::fatalf("Error: listen: {}", net::strerror(err));
    case let err: errors::error =>
        log::fatalf("Error: listen: {}", errors::strerror(err));
    case let socket: *ev::file =>
        yield socket;
    };
    defer ev::close(socket);

    const timer = ev::newtimer(&loop, &update_sdl, time::clock::MONOTONIC)!;
    ev::timer_configure(timer, 30 * time::MILLISECOND, 30 * time::MILLISECOND);
    ev::setuser(timer, &rt_state);

    const sig = ev::signal(&loop, &signal, signal::sig::INT, signal::sig::TERM)!;
    defer ev::close(sig);
    ev::setuser(sig, &rt_state);

    for (ev::dispatch(&loop, -1)!) void;
};

fn signal(file: *ev::file, sig: signal::sig) void = {
    log::printfln("Exiting due to {}", signal::signame(sig));

    const rt_state = ev::getuser(file): *rt_state;
    ev::stop(rt_state.loop);
};

fn update_sdl(file: *ev::file) void = {
    const rt_state = ev::getuser(file): *rt_state;

    if (update(rt_state.windowing_state)!) {
        ev::stop(rt_state.loop);
    };

    draw(rt_state.windowing_state)!;
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

