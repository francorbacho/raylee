use lua;
use fmt;
use raylee;
use raylee::math::{ v3, vunit };

let _global_scene = raylee::scene { ... };

@init fn init_global_scene() void = {
    const width = 256u;
    const height = 144u;
    const aspect_ratio: f64 = width: f64 / height: f64;

    const viewport_height = 2.0;
    const viewport_width = aspect_ratio * viewport_height;
    const focal_length = 1.0;

    _global_scene = raylee::scene {
        width = width,
        height = height,
        camera = raylee::camera_settings {
            position = v3(0.0, 0.0, 0.0),
            viewport_size = v3(viewport_width, viewport_height, 0.0),
            focal_length = focal_length,
        },
        light_direction = vunit(v3(0.8, 0.3, 0.7)),
        done = false,
    };
};

fn global_scene() *raylee::scene = {
    return &_global_scene;
};

fn set_camera_position(l: *lua::lua_State) void = {
    let x = lua::luaL_checknumber(l, lua::lua_gettop(l) - 0);
    let y = lua::luaL_checknumber(l, lua::lua_gettop(l) - 1);
    let z = lua::luaL_checknumber(l, lua::lua_gettop(l) - 2);

    global_scene().camera.position.x = x;
    global_scene().camera.position.y = y;
    global_scene().camera.position.z = z;
};

fn set_light_direction(l: *lua::lua_State) void = {
    let x = lua::luaL_checknumber(l, lua::lua_gettop(l) - 0);
    let y = lua::luaL_checknumber(l, lua::lua_gettop(l) - 1);
    let z = lua::luaL_checknumber(l, lua::lua_gettop(l) - 2);

    global_scene().light_direction.x = x;
    global_scene().light_direction.y = y;
    global_scene().light_direction.z = z;
};

fn set_done(l: *lua::lua_State) void = {
    let done_idx = lua::lua_gettop(l);
    if (!lua::lua_isboolean(l, done_idx)) {
        lua::luaL_typeerror(l, done_idx, "bool");
    };

    global_scene().done = lua::lua_toboolean(l, done_idx);
};
