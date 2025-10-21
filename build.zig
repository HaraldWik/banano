const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "banano",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
            .link_libc = true,
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addArgs(b.args orelse &.{"main.test"});
}

// const std = @import("std");

// pub fn build(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});

//     const c_path: []const u8 = "c/";
//     const c_files: []const []const u8 = &.{
//         c_path ++ "browser.c",
//         c_path ++ "chars.c",
//         c_path ++ "color.c",
//         c_path ++ "cut.c",
//         c_path ++ "files.c",
//         c_path ++ "global.c",
//         c_path ++ "help.c",
//         c_path ++ "history.c",
//         c_path ++ "move.c",
//         c_path ++ "nano.c",
//         c_path ++ "prompt.c",
//         c_path ++ "rcfile.c",
//         c_path ++ "search.c",
//         c_path ++ "text.c",
//         c_path ++ "utils.c",
//         c_path ++ "winio.c",
//     };

//     const exe = b.addExecutable(.{
//         .name = "banano",
//         .root_module = b.createModule(.{
//             // .root_source_file = b.path("src/main.zig"),
//             .target = target,
//             .optimize = optimize,
//             .imports = &.{},
//             .link_libc = true,
//         }),
//     });
//     exe.root_module.addCMacro("NANO_REG_EXTENDED", "1");
//     exe.root_module.addIncludePath(b.path(c_path));
//     exe.root_module.addCSourceFiles(.{ .files = c_files });

//     exe.root_module.linkSystemLibrary("curses", .{});

//     b.installArtifact(exe);

//     const run_step = b.step("run", "Run the app");
//     const run_cmd = b.addRunArtifact(exe);
//     run_step.dependOn(&run_cmd.step);
//     run_cmd.step.dependOn(b.getInstallStep());
//     run_cmd.addArgs(b.args orelse &.{"main.test"});
// }
