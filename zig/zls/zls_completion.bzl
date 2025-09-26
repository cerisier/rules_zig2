load("//zig/private/common:zig_build.bzl", "TOOLCHAINS")

# load("//zig/private/common:zig_cache.bzl", "zig_cache_output")
# load("//zig/private/common:zig_lib_dir.bzl", "zig_lib_dir")
# load("//zig/private/common:translate_c.bzl", "zig_translate_c")
load("//zig/private/providers:zig_module_info.bzl", "ZigModuleInfo")

def _add_context(context):
    return json.encode(struct(name = context.name, path = context.main))

def _zls_completion_impl(ctx):
    contexts = depset(
        direct = [dep[ZigModuleInfo].module_context for dep in ctx.attr.deps],
        transitive = [dep[ZigModuleInfo].transitive_module_contexts for dep in ctx.attr.deps],
    )

    inputs = depset(
        transitive = [dep[ZigModuleInfo].transitive_inputs for dep in ctx.attr.deps],
    )

    template_dict = ctx.actions.template_dict()
    template_dict.add_joined("@@PACKAGES@@", contexts, map_each = _add_context, join_with = ",\n        ")

    config = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.expand_template(
        output = config,
        template = ctx.file._zls_completion_tpl,
        computed_substitutions = template_dict,
    )

    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        output = runner,
        template = ctx.file._zls_completion_sh_tpl,
        substitutions = {
            "@@COMPLETION_FILE_PATH@@": config.short_path,
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            files = depset(direct = [runner]),
            executable = runner,
            runfiles = ctx.runfiles(files = [config], transitive_files = depset(transitive = [inputs])),
        ),
    ]

zls_completion = rule(
    implementation = _zls_completion_impl,
    attrs = {
        "deps": attr.label_list(
            providers = [ZigModuleInfo],
            mandatory = True,
        ),
        "_zls_completion_tpl": attr.label(
            default = ":zls.completion.tpl",
            allow_single_file = True,
        ),
        "_zls_completion_sh_tpl": attr.label(
            default = ":zls.completion.sh.tpl",
            allow_single_file = True,
        ),
    },
    toolchains = TOOLCHAINS,
    fragments = ["cpp"],
    executable = True,
)
