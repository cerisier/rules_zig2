"""Unit tests for ZigModuleInfo functions."""

load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//zig/private/common:escape_label.bzl", "escape_label", "escape_label_str")
load("//zig/private/common:translate_c.bzl", "zig_translate_c")
load(
    "//zig/private/providers:zig_module_info.bzl",
    "ZigModuleInfo",
    "zig_module_specifications",
)

def _write_expected_impl(ctx):
    lines = [
        line.replace("{bin_dir}", ctx.bin_dir.path)
        for line in ctx.attr.lines
    ]

    ctx.actions.write(
        output = ctx.outputs.out,
        content = "\n".join(lines) + "\n",
    )

_write_expected = rule(
    _write_expected_impl,
    attrs = {
        "lines": attr.string_list(mandatory = True),
        "out": attr.output(mandatory = True),
    },
)

def _write_module_specs_args_impl(ctx):
    args = ctx.actions.args()

    c_module = None
    if ctx.attr.cmod:
        c_module = ctx.attr.cmod[ZigModuleInfo]

    zig_module_specifications(
        root_module = ctx.attr.mod[ZigModuleInfo],
        args = args,
        c_module = c_module,
    )

    ctx.actions.write(
        output = ctx.outputs.out,
        content = args,
    )

_write_module_specs_args = rule(
    _write_module_specs_args_impl,
    attrs = {
        "cmod": attr.label(providers = [ZigModuleInfo]),
        "mod": attr.label(providers = [ZigModuleInfo]),
        "out": attr.output(mandatory = True),
    },
)

def _global_c_module_impl(ctx):
    zigtoolchaininfo = ctx.toolchains["//zig:toolchain_type"].zigtoolchaininfo
    return [
        zig_translate_c(
            ctx = ctx,
            name = "c",
            canonical_name = "c",
            zigtoolchaininfo = zigtoolchaininfo,
            global_args = ctx.actions.args(),
            cc_infos = [dep[CcInfo] for dep in ctx.attr.cdeps],
        ),
    ]

_global_c_module = rule(
    _global_c_module_impl,
    attrs = {
        "cdeps": attr.label_list(
            mandatory = True,
            providers = [CcInfo],
        ),
    },
    fragments = ["cpp"],
    toolchains = [
        "//zig:toolchain_type",
    ] + use_cc_toolchain(mandatory = False),
)

def _module_specs_test(name, *, mod, expected, cmod = None):
    _write_expected(
        name = name + "_expected",
        lines = expected,
        out = name + "_expected.txt",
        tags = ["manual"],
    )

    _write_module_specs_args(
        name = name + "_actual",
        mod = mod,
        cmod = cmod,
        out = name + "_actual.txt",
        tags = ["manual"],
    )

    diff_test(
        name = name,
        failure_message = "generated module specifications do not match",
        file1 = name + "_expected.txt",
        file2 = name + "_actual.txt",
        size = "small",
    )

def _canonical_name(label):
    return escape_label(label = Label(label))

def _bazel_builtin_name(label):
    return "bazel_builtin_" + _canonical_name(label)

def _bazel_builtin_dep(label):
    return "'bazel_builtin={}'".format(_bazel_builtin_name(label))

def _bazel_builtin_module(label):
    label = Label(label)
    name = _bazel_builtin_name(str(label))
    return "'-M{name}={{bin_dir}}/{package}/{name}.zig'".format(
        name = name,
        package = label.package,
    )

def _dep(import_name, label):
    return "'{}={}'".format(import_name, _canonical_name(label))

def _module(label, src):
    return "'-M{}={}'".format(_canonical_name(label), src)

def _translate_c_name(label, import_name):
    return "{}__{}".format(_canonical_name(label), escape_label_str(import_name))

def _translate_c_module(label, import_name):
    label = Label(label)
    name = _translate_c_name(str(label), import_name)
    return "'-M{name}={{bin_dir}}/{package}/{target}_c.zig'".format(
        name = name,
        package = label.package,
        target = label.name,
    )

def module_info_test_suite(name):
    """Generate module info test suite.

    Args:
        name: The name of the test suite.
    """
    _module_specs_test(
        name = name + "_simple_diff_test",
        mod = "//zig/tests/multiple-sources-module:data",
        expected = [
            "--dep",
            _bazel_builtin_dep("//zig/tests/multiple-sources-module:data"),
            _module("//zig/tests/multiple-sources-module:data", "zig/tests/multiple-sources-module/data.zig"),
            _bazel_builtin_module("//zig/tests/multiple-sources-module:data"),
        ],
    )

    _module_specs_test(
        name = name + "_transitive_with_zigopts_diff_test",
        mod = "//zig/tests/transitive-modules-zigopts:b",
        expected = [
            "--dep",
            _dep("a", "//zig/tests/transitive-modules-zigopts:a"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/transitive-modules-zigopts:b"),
            "-DFOR_MODULE_B",
            _module("//zig/tests/transitive-modules-zigopts:b", "zig/tests/transitive-modules-zigopts/b.zig"),
            _bazel_builtin_module("//zig/tests/transitive-modules-zigopts:a"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/transitive-modules-zigopts:a"),
            "-DFOR_MODULE_A",
            _module("//zig/tests/transitive-modules-zigopts:a", "zig/tests/transitive-modules-zigopts/a.zig"),
            _bazel_builtin_module("//zig/tests/transitive-modules-zigopts:b"),
        ],
    )

    _module_specs_test(
        name = name + "_simple_with_c_diff_test",
        mod = "//zig/tests/translate-c-modules:data",
        expected = [
            "--dep",
            "'data_c_zig={}'".format(_translate_c_name("//zig/tests/translate-c-modules:data_c_zig", "data_c_zig")),
            "--dep",
            _bazel_builtin_dep("//zig/tests/translate-c-modules:data"),
            _module("//zig/tests/translate-c-modules:data", "zig/tests/translate-c-modules/data.zig"),
            _translate_c_module("//zig/tests/translate-c-modules:data_c_zig", "data_c_zig"),
            _bazel_builtin_module("//zig/tests/translate-c-modules:data"),
        ],
    )

    _global_c_module(
        name = name + "_global_c_module",
        cdeps = ["//zig/tests/translate-c-modules:data_c"],
        tags = ["manual"],
    )

    _module_specs_test(
        name = name + "_simple_with_global_c_diff_test",
        mod = "//zig/tests/translate-c-modules:data_global_c",
        cmod = ":" + name + "_global_c_module",
        expected = [
            "--dep",
            _bazel_builtin_dep("//zig/tests/translate-c-modules:data_global_c"),
            "--dep",
            "'c=c'",
            _module("//zig/tests/translate-c-modules:data_global_c", "zig/tests/translate-c-modules/data_global_c.zig"),
            _bazel_builtin_module("//zig/tests/translate-c-modules:data_global_c"),
            "'-Mc={bin_dir}/zig/tests/module_info_test_global_c_module_c.zig'",
        ],
    )

    _module_specs_test(
        name = name + "_nested_diff_test",
        mod = "//zig/tests/nested-modules:a",
        expected = [
            "--dep",
            _dep("b", "//zig/tests/nested-modules:b"),
            "--dep",
            _dep("c", "//zig/tests/nested-modules:c"),
            "--dep",
            _dep("d", "//zig/tests/nested-modules:d"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/nested-modules:a"),
            _module("//zig/tests/nested-modules:a", "zig/tests/nested-modules/a.zig"),
            _bazel_builtin_module("//zig/tests/nested-modules:e"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/nested-modules:e"),
            _module("//zig/tests/nested-modules:e", "zig/tests/nested-modules/e.zig"),
            _bazel_builtin_module("//zig/tests/nested-modules:b"),
            _bazel_builtin_module("//zig/tests/nested-modules:c"),
            _bazel_builtin_module("//zig/tests/nested-modules:f"),
            "--dep",
            _dep("e", "//zig/tests/nested-modules:e"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/nested-modules:f"),
            _module("//zig/tests/nested-modules:f", "zig/tests/nested-modules/f.zig"),
            _bazel_builtin_module("//zig/tests/nested-modules:d"),
            "--dep",
            _dep("e", "//zig/tests/nested-modules:e"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/nested-modules:b"),
            _module("//zig/tests/nested-modules:b", "zig/tests/nested-modules/b.zig"),
            "--dep",
            _dep("e", "//zig/tests/nested-modules:e"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/nested-modules:c"),
            _module("//zig/tests/nested-modules:c", "zig/tests/nested-modules/c.zig"),
            "--dep",
            _dep("f", "//zig/tests/nested-modules:f"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/nested-modules:d"),
            _module("//zig/tests/nested-modules:d", "zig/tests/nested-modules/d.zig"),
            _bazel_builtin_module("//zig/tests/nested-modules:a"),
        ],
    )

    _module_specs_test(
        name = name + "_import_name_module_diff_test",
        mod = "//zig/tests/import-name-module:main",
        expected = [
            "--dep",
            _dep("import-name-module/data", "//zig/tests/import-name-module:data"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/import-name-module:main"),
            _module("//zig/tests/import-name-module:main", "zig/tests/import-name-module/main.zig"),
            _bazel_builtin_module("//zig/tests/import-name-module:data"),
            "--dep",
            _bazel_builtin_dep("//zig/tests/import-name-module:data"),
            _module("//zig/tests/import-name-module:data", "zig/tests/import-name-module/data.zig"),
            _bazel_builtin_module("//zig/tests/import-name-module:main"),
        ],
    )

    native.test_suite(
        name = name,
        tests = [
            name + "_simple_diff_test",
            name + "_nested_diff_test",
            name + "_simple_with_c_diff_test",
            name + "_simple_with_global_c_diff_test",
            name + "_import_name_module_diff_test",
            name + "_transitive_with_zigopts_diff_test",
        ],
    )
