use fmt;
use log;
use time;

use lua;

use raylee;

fn run_worker(config: config) void = {
    let scene = global_scene();

    log::println("[work] starting work on scene...");
    let before = time::now(time::clock::MONOTONIC);
    let img = raylee::render(*scene);
    let after = time::now(time::clock::MONOTONIC);

    const MS_IN_S = 1e3;
    const NS_IN_S = 1e9;

    let duration_ms = time::diff(before, after) * MS_IN_S / NS_IN_S;
    log::printfln("[work] work on the scene ended in {} ms", duration_ms);
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
    log::printfln("scene is {}x{}", scene.width, scene.height);

    for (let i = 0z; i < MAX_FRAME_COUNT && !scene.done; i += 1) {
        let img = raylee::render(*scene);
        let buffer: [64]u8 = [0...];
        let path = fmt::bsprintf(buffer, "target/render{:03}.ppm", i);
        raylee::save_to_file(img, path);

        match (lua::lua_getglobal(l, "update")) {
        case void => void;
        case lua::errerr => void; // for some reason ok?
        case let err: lua::error => abort();
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
