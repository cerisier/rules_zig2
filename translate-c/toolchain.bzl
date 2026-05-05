"""Rules to declare translate-c toolchains."""

TranslateCToolchainInfo = provider(
    doc = "Information about how to invoke an external translate-c executable.",
    fields = {
        "executable": "File, The translate-c executable.",
        "runfiles": "Depset of files required to run the translate-c executable.",
    },
)

def _disable_translate_c_transition_impl(_, __):
    return {
        "//zig/settings:translate_c": False,
    }

_disable_translate_c_transition = transition(
    implementation = _disable_translate_c_transition_impl,
    inputs = [],
    outputs = [
        "//zig/settings:translate_c",
    ],
)

def _translate_c_toolchain_impl(ctx):
    translate_c = ctx.attr.translate_c[0] if type(ctx.attr.translate_c) == "list" else ctx.attr.translate_c
    default_info = translate_c[DefaultInfo]
    executable = default_info.files_to_run.executable
    if not executable:
        fail("translate_c must provide an executable")
    translatectoolchaininfo = TranslateCToolchainInfo(
        executable = executable,
        runfiles = default_info.default_runfiles.files,
    )
    return [
        platform_common.ToolchainInfo(
            translatectoolchaininfo = translatectoolchaininfo,
        ),
    ]

translate_c_toolchain = rule(
    implementation = _translate_c_toolchain_impl,
    attrs = {
        "translate_c": attr.label(
            doc = "The translate-c executable target.",
            mandatory = True,
            cfg = _disable_translate_c_transition,
        ),
    },
    doc = "Defines a translate-c toolchain.",
)
