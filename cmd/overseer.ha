use bytes;
use errors;
use fmt;
use io;
use log;
use net;
use net::ip;
use net::tcp;
use os;
use strconv;
use strings;
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

use raylee;
use raylee::math;
use raylee::math::{color};

def BUFSIZE: size = 8096;

type rt_state = struct {
    loop: *ev::loop,
    config: *config,
    socket: *ev::file,
    windowing_state: *windowing_state,
    success: bool,
};

type windowing_state = struct {
    window_width: int,
    window_height: int,
    window: *SDL_Window,
    renderer: *SDL_Renderer,
    surface: *SDL_Surface,
    texture: nullable *SDL_Texture,
};

type worker_connection = struct {
    rt_state: *rt_state,
    socket: *ev::file,
    addr: ip::addr,
    port: u16,
    sent: size,
    buf: [BUFSIZE]u8,
    wbuf: []u8,
};

fn run_sdl(config: config) (void | sdl2::error) = {
    assert(config.task is overseer);

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

    const surface = sdl2::SDL_CreateRGBSurface(
        0,
        config.width: int, config.height: int,
        32, 0, 0, 0, 0,
    )!;

    const buf = alloc([0u32...], config.width * config.height);
    defer free(buf);

    surface.pixels = &buf[0];

    const windowing_state = windowing_state {
        window_width = window_width,
        window_height = window_height,
        window = window,
        renderer = renderer,
        surface = surface,
        texture = null,
    };

    let loop = ev::newloop()!;
    defer ev::finish(&loop);

    log::println("[inet] listening on port", PORT);

    const socket = match (ev::listen_tcp(&loop, ip::LOCAL_V4, PORT)) {
    case let err: net::error =>
        log::fatalf("Error: listen: {}", net::strerror(err));
    case let err: errors::error =>
        log::fatalf("Error: listen: {}", errors::strerror(err));
    case let socket: *ev::file =>
        yield socket;
    };
    defer ev::close(socket);

    let rt_state = rt_state {
        loop = &loop,
        config = &config,
        windowing_state = &windowing_state,
        socket = socket,
        success = true,
    };

    ev::setuser(socket, &rt_state);
    ev::accept(socket, &on_new_connection);

    const timer = ev::newtimer(&loop, &update_sdl, time::clock::MONOTONIC)!;
    ev::timer_configure(timer, 30 * time::MILLISECOND, 30 * time::MILLISECOND);
    ev::setuser(timer, &rt_state);

    const sig = ev::signal(&loop, &signal, signal::sig::INT, signal::sig::TERM)!;
    defer ev::close(sig);
    ev::setuser(sig, &rt_state);

    for (ev::dispatch(&loop, -1)!) void;

    if (!rt_state.success)
        fmt::fatalf("error");
};

fn on_new_connection(file: *ev::file, r: (*ev::file | net::error)) void = {
    let rt_state = ev::getuser(file): *rt_state;
    const socket = match (r) {
    case let socket: *ev::file => yield socket;
    case let err: net::error =>
          log::printfln("[inet] error: accept: {}", net::strerror(err));
          ev::stop(rt_state.loop);
          rt_state.success = false;
          return;
    };

    const file = ev::getfd(socket);
    const (addr, port) = tcp::peeraddr(file) as (ip::addr, u16);

    log::printfln("[inet] new connection from {}:{}", ip::string(addr), port);

    const conn = alloc(worker_connection {
        rt_state = rt_state,
        socket = socket,
        addr = addr,
        port = port,
        // XXX: Hare does not allow allocating empty arrays.
        wbuf = alloc([0]),
        ...
    });
    ev::setuser(socket, conn);
    ev::read(socket, &on_worker_submit, conn.buf);

    ev::accept(rt_state.socket, &on_new_connection);
};

fn on_worker_submit(file: *ev::file, r: (size | io::EOF | io::error)) void = {
    const worker_conn = ev::getuser(file): *worker_connection;
    ev::read(worker_conn.socket, &on_worker_submit, worker_conn.buf);

    const n = match (r) {
    case let n: size =>
        yield n;
    case io::EOF =>
        worker_connection_close(worker_conn);
        return;
    case let err: io::error =>
        log::printfln("[inet] error with connection: {}", io::strerror(err));
        worker_connection_close(worker_conn);
        return;
    };

    append(worker_conn.wbuf,  worker_conn.buf[..n]...);
    worker_conn.sent += n;

    if (bytes::contains(worker_conn.buf, &SUBMIT)) {
        const buf = worker_conn.wbuf;
        const (zero, rest) = bytes::cut(buf, &HELO);
        assert(bytes::equal(zero, [0]));

        const (region, rest) = bytes::cut(rest, '\n');

        const region = strings::fromutf8(region)!;
        const (x1, region) = strings::cut(region, " ");
        const (y1, region) = strings::cut(region, " ");
        const (x2, y2) = strings::cut(region, " ");

        const x1 = strconv::stoz(x1)!;
        const y1 = strconv::stoz(y1)!;
        const x2 = strconv::stoz(x2)!;
        const y2 = strconv::stoz(y2)!;

        const width = x2 - x1;
        const height = y2 - y1;

        const data: []u8 = bytes::rtrim(rest, &SUBMIT...);
        const pixels_len = (width * height): size;
        const pixels_received = len(data) * size(u8) / size(color);

        if (pixels_len != pixels_received) {
            fmt::printfln("received {} but expected {}", pixels_received, pixels_len)!;
        };
        assert(pixels_len == pixels_received);

        const colors = &data[0]: *[*]color;
        const colors: []color = colors[..pixels_len];

        const ws = worker_conn.rt_state.windowing_state;
        const region = raylee::dregion { x1 = x1, y1 = y1, x2 = x2, y2 = y2 };
        copy_to_surface(ws, colors, region);

        match (ws.texture) {
        case let t: *SDL_Texture =>
            sdl2::SDL_DestroyTexture(t);
        case null => void;
        };

        ws.texture = sdl2::SDL_CreateTextureFromSurface(ws.renderer, ws.surface)!;
        free(worker_conn.wbuf);
        worker_conn.wbuf = alloc([0]);

        bytes::zero(worker_conn.buf);
    };
};

fn copy_to_surface(ws: *windowing_state, colors: []color, region: raylee::dregion) void = {
    const w = ws.surface.w: size;
    const h = ws.surface.h: size;

    const pixels = match (ws.surface.pixels) {
    case null => abort();
    case let p: *opaque => yield p: *[*]u32;
    };

    const pixels = pixels[..w * h];

    const from_x = region.x1;
    const from_y = region.y1;
    const to_x = region.x2;
    const to_y = region.y2;

    const region_w = to_x - from_x;
    const region_h = to_y - from_y;

    assert(len(colors) == region_w * region_h);

    let ci = 0z;
    for (let j = from_y; j < to_y; j += 1) {
        for (let i = from_x; i < to_x; i += 1) {
            const color = colors[ci];
            ci += 1;

            const r = color.x: u32;
            const g = color.y: u32;
            const b = color.z: u32;
            const color: u32 = (r << 16) | (g << 8) | b;

            const ji = j * w + i;
            pixels[ji] = color;
        };
    };
};

fn worker_connection_close(conn: *worker_connection) void = {
    log::printfln("[inet] connection {}:{} closed", ip::string(conn.addr), conn.port);
    ev::close(conn.socket);
    free(conn.wbuf);
    free(conn);
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
        return;
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

