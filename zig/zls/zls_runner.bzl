def build_runner_tpl(target):
    return """\
const std = @import("std");

pub fn main() !void {{
    var gpa: std.heap.GeneralPurposeAllocator(.{{}}) = .{{}};
    defer _ = gpa.deinit();
    var arena_ = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena_.deinit();
    const arena = arena_.allocator();

    const build_workspace_directory = try std.process.getEnvVarOwned(arena, "BUILD_WORKSPACE_DIRECTORY");
    var child = std.process.Child.init(&.{{
        "bazel",
        "run",
        {target},
    }}, arena);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    child.cwd = build_workspace_directory;
    _ = try child.spawnAndWait();
}}
""".format(target = repr(target))

def runner_tpl(zls, zig_exe_path, zig_lib_path, zig_cache, build_runner):
    return """\
#!/bin/bash
set -eo pipefail

json_config="$(mktemp)"
cat <<EOF > ${{json_config}}
{{
    "build_runner_path": "$(realpath {build_runner})",
    "global_cache_path": "$(realpath {zig_cache})",
    "zig_exe_path": "$(realpath {zig_exe_path})",
    "zig_lib_path": "$(realpath {zig_lib_path})"
}}
EOF

exec {zls} "${{@}}" --config-path "${{json_config}}"
""".format(
        zig_lib_path = zig_lib_path,
        zig_exe_path = zig_exe_path,
        zig_cache = zig_cache,
        zls = zls,
        build_runner = build_runner,
    )

def _zls_runner_impl(ctx):
    zigtoolchaininfo = ctx.toolchains["@rules_zig//zig:toolchain_type"].zigtoolchaininfo
    zlsinfo = ctx.toolchains["@rules_zig//zig/zls:toolchain_type"].zlsinfo

    build_runner = ctx.actions.declare_file(ctx.label.name + ".build_runner.zig")
    ctx.actions.write(build_runner, build_runner_tpl(str(ctx.attr.target.label)))

    zls_runner = ctx.actions.declare_file(ctx.label.name + ".zls_runner.sh")
    ctx.actions.write(zls_runner, runner_tpl(
        zig_cache = zigtoolchaininfo.zig_cache,
        zig_exe_path = zigtoolchaininfo.zig_exe_path,
        zig_lib_path = zigtoolchaininfo.zig_lib_path,
        zls = zlsinfo.bin.short_path,
        build_runner = build_runner.short_path,
    ))

    return [
        DefaultInfo(
            files = depset([zls_runner]),
            executable = zls_runner,
            runfiles = ctx.runfiles(
                files = [
                    build_runner,
                    zlsinfo.bin,
                ],
                transitive_files = depset(zigtoolchaininfo.zig_files),
            ),
        ),
    ]

zls_runner = rule(
    implementation = _zls_runner_impl,
    attrs = {
        "target": attr.label(mandatory = True, executable = True, cfg = "exec"),
    },
    executable = True,
    toolchains = [
        "@rules_zig//zig:toolchain_type",
        "@rules_zig//zig/zls:toolchain_type",
    ],
)
