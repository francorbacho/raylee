use fmt;
use io;
use log;
use net;
use net::ip;
use net::tcp;
use strings;
use time;

use lua;

use raylee;
use raylee::math;
use raylee::math::{color};

type worker_state = struct {
    config: *config,
    l: *lua::lua_State,
};

fn run_worker(config: config) void = {
    assert(config.task is worker);
    const task = config.task as worker;

    // XXX: We need to wait here to give time to the overseer program to start
    //      accepting connections.
    time::sleep(100 * time::MILLISECOND);

    let connection = tcp::connect(ip::LOCAL_V4, PORT)!;
    let scene = global_scene();

    scene.width = config.width;
    scene.height = config.height;
    scene.samples_per_pixel = config.samples_per_pixel;

    const l = init_lua();
    defer lua::lua_close(l);

    let state = worker_state {
        config = &config,
        l = l,
    };

    log::println("[work] starting work on scene...");
    log::printfln("[work] my job is {}x{}::{}x{}", task.region.x1, task.region.y1, task.region.x2, task.region.y2);

    if (config.script is str) {
        const script_path = config.script as str;
        lua::luaL_loadfile(l, script_path)!;
        dispatch_lua(l, 0, 0);
    };

    const MS_IN_S = 1e3;
    const NS_IN_S = 1e9;
    const MAX_FRAMES = 5z;

    for (let i = 0z; i < MAX_FRAMES; i += 1) {
        if (scene.done)
            break;

        log::println("[work] starting work on frame...");

        let before = time::now(time::clock::MONOTONIC);
        let img = raylee::render(*scene, task.region);
        let after = time::now(time::clock::MONOTONIC);

        let duration_ms = time::diff(before, after) * MS_IN_S / NS_IN_S;
        log::printfln("[work] work on the scene ended in {} ms", duration_ms);
        send_region(connection, &img, task.region);
        time::sleep(3 * time::SECOND);
    };

    log::println("[work] done");
};

fn send_region(socket: io::file, img: *raylee::image, region: raylee::region) void = {
    log::printfln("[work] sending region...");

    const region = raylee::calc_pixels_from_region(region, img.width, img.height);

    let tmpbuf: [128]u8 = [0...];
    const line = fmt::bsprintf(tmpbuf, "{} {} {} {}\n", region.x1, region.y1, region.x2, region.y2);
    const buf = strings::toutf8(line);

    write(socket, &HELO);
    write(socket, buf);

    const color_bytes_amount = len(img.pixels) * size(color) / size(u8);
    const color_bytes = &img.pixels[0]: *[*]u8;
    const color_bytes: []u8 = color_bytes[..color_bytes_amount];

    const expected_first_byte = *(&img.pixels[0]: *u8);
    const first_pixel_byte = color_bytes[0];

    // FIXME: Remove this.
    assert(first_pixel_byte == expected_first_byte);

    write(socket, color_bytes);
    write(socket, &SUBMIT);
    log::printfln("[work] region sent");
};

fn write(socket: io::file, buf: []u8) void = {
    match (io::write(socket, buf)) {
    case size => void;
    case let e: io::error =>
        log::printfln("[work] write: {}", io::strerror(e));
    };
};

fn init_lua() *lua::lua_State = {
    let l = lua::luaL_newstate();
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

    return l;
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
