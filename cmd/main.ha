use fmt;
use fs;
use getopt;
use io;
use log;
use os;
use os::exec;
use strconv;
use strings;

use raylee;
use raylee::{ region };
use raylee::math::{ v3, point };

def WHOLE_REGION: region = region { x1 = 0.0, y1 = 0.0, x2 = 1.0, y2 = 1.0 };
def HALF_WIDTH: region = region { x1 = 0.5, y1 = 0.0, x2 = 1.0, y2 = 1.0 };

def MAX_FRAME_COUNT = 1000z;

// e.i. server
type overseer = void;
// e.i. client
type worker = struct {
    region: region,
};

type task = (overseer | worker);

type config = struct {
    width: u32, height: u32,
    samples_per_pixel: u32,
    headless: bool,
    script: (void | str),
    numworkers: size,
    port: u16,
    task: task,
};

export fn main() void = {
    const cmd = getopt::parse(os::args,
        "simple raytracer",
        ('v', "verbose"),
        ('w', "workers", "number of workers to spawn (default: 1)"),
        ('W', "width", "width of the raytraced image (default: 256)"),
        ('H', "height", "height of the raytraced image (default: 144)"),
        ('s', "samples", "samples per pixel (default: 5)"),
        ('p', "port", "port to use (default: 8221)"),
        "[file]"
    );
    defer getopt::finish(&cmd);

    let config = config {
        width = 256, height = 144,
        samples_per_pixel = 5,
        headless = false,
        script = void,
        task = overseer,
        port = 8221,
        numworkers = 1,
    };

    log::setlogger(log::silent);

    for (let i = 0z; i < len(cmd.opts); i += 1) {
        let opt = cmd.opts[i];
        switch (opt.0) {
        case 'v' =>
            log::setlogger(log::default);
        case 'w' =>
            config.numworkers = match (strconv::stoz(opt.1)) {
            case let v: size => yield v;
            case strconv::overflow => abort();
            case strconv::invalid =>
                fmt::fatalf("cannot parse workers {}: is invalid", opt.1);
            };
        case 'W' =>
            config.width = match (strconv::stou32(opt.1)) {
            case let v: u32 => yield v;
            case strconv::overflow => abort();
            case strconv::invalid =>
                fmt::fatalf("cannot parse width {}: is invalid", opt.1);
            };
        case 'H' =>
            config.height = match (strconv::stou32(opt.1)) {
            case let v: u32 => yield v;
            case strconv::overflow => abort();
            case strconv::invalid =>
                fmt::fatalf("cannot parse height {}: is invalid", opt.1);
            };
        case 's' =>
            config.samples_per_pixel = match (strconv::stou32(opt.1)) {
            case let v: u32 => yield v;
            case strconv::overflow => abort();
            case strconv::invalid =>
                fmt::fatalf("cannot parse samples {}: is invalid", opt.1);
            };
        case 'p' =>
            config.port = match (strconv::stou16(opt.1)) {
            case let v: u16 => yield v;
            case strconv::overflow => abort();
            case strconv::invalid =>
                fmt::fatalf("cannot parse port {}: is invalid", opt.1);
            };
        case =>
            fmt::fatalf("bad opt: {}", opt.0);
        };
    };

    if (len(cmd.args) == 1) {
        config.script = cmd.args[0];
    } else if (len(cmd.args) > 1) {
        fmt::fatalf("Only one script can be specified");
    };

    run(config);
};

// Window height is determined at runtime keeping the same aspect ratio.
def WINDOW_WIDTH: int = 720;

fn run(config: config) void = {
    log::printfln("[conf] dumping config...");
    log::printfln("[conf] resolution :: {}x{}", config.width, config.height);
    log::printfln("[conf] samples pp :: {}", config.samples_per_pixel);
    log::printfln("[conf] headless :: {}", config.headless);
    log::printfln("[conf] script :: {}", match (config.script) {
        case void => yield "no";
        case let script: str => yield script;
    });
    log::printfln("[conf] task :: {}", taskstr(config.task));

    if (config.headless && config.task is overseer) {
        // XXX: Allow this?
        fmt::fatalf("cannot run overseer as headless mode");
    };

    if (!config.headless) {
        match (os::exec::fork()) {
        case void =>
            config.task = worker { region = WHOLE_REGION };
        case let p: os::exec::process =>
            config.task = overseer;
            return run_sdl(config)!;
        case let e: os::exec::error =>
            log::fatalf("error forking process: {}", os::exec::strerror(e));
        };
    };

    assert(config.task is worker);
    assert(config.numworkers >= 0);

    const task = config.task as worker;

    if (config.numworkers == 0) {
        return;
    } else if (config.numworkers == 1) {
        run_worker(config);
        return;
    };

    const height = task.region.y2 - task.region.y1;
    const height_per_region = height / config.numworkers: f32;

    for (let i = 0z; i < config.numworkers; i += 1) {
        match (os::exec::fork()) {
        case void =>
            let buf: [128]u8 = [0...];
            let buf = fmt::bsprintf(buf, "/tmp/raylee-worker-{:02}.dump", i);
            let handle = os::create(buf, fs::mode::USER_RW, fs::flag::WRONLY)!;
            let logger = log::new(handle);

            log::setlogger(&logger);

            task.region.y1 = task.region.y1 + height_per_region * i: f32;
            task.region.y2 = task.region.y1 + height_per_region;
            config.task = task;
            run_worker(config);
            return;
        case os::exec::process => void;
        case let e: os::exec::error =>
            log::fatalf("error forking process: {}", os::exec::strerror(e));
        };
    };

    // FIXME: Output is still getting overlapped.
    const log_follower = exec::cmd("sh", "-c", "tail -f /tmp/raylee-worker-*.dump")!;
    exec::exec(&log_follower);
};

fn taskstr(task: task) str = match (task) {
    case overseer => return "overseer";
    case worker => return "worker";
};
