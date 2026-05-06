"""Public providers for Zig rule authors."""

load(
    "//zig/private/providers:zig_module_info.bzl",
    _ZigModuleInfo = "ZigModuleInfo",
    _zig_module_info = "zig_module_info",
)

ZigModuleInfo = _ZigModuleInfo
zig_module_info = _zig_module_info
