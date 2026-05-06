# Translate-C Toolchain Refactor

- [x] Keep `//zig/settings:translate_c`, make it a public `bool_flag` defaulting to `False`.
- [x] Remove `translate_c` from Zig compiler toolchain APIs and generated repositories.
- [x] Add `//zig/translate-c:toolchain_type`, provider, and `translate_c_toolchain` rule.
- [x] Make `translate_c_toolchain` transition dependencies back to `translate_c = False`.
- [x] Make Zig build/doc/C-library rules request `//zig/translate-c:toolchain_type` optionally.
- [x] Split translate-c action into external-toolchain path and legacy `zig translate-c` fallback.
- [x] Add e2e workspace-local external translate-c implementation and toolchain registration.
- [x] Add dedicated e2e test coverage for fallback and registered external translate-c.
- [x] Run formatting/build/tests; note blockers.

## Notes

- Keep existing build-setting label `//zig/settings:translate_c`.
- `rules_zig` must not ship an implementation target for the external translate-c binary.
- Custom transition attrs are exposed as a one-element list here, so `translate_c_toolchain` normalizes before reading `DefaultInfo`.
- Per feedback, `TranslateCToolchainInfo` carries the executable file and runfiles, not the configured target.
- External translate-c runtime Zig modules are explicit `runtime_modules` on `translate_c_toolchain`, not inferred from executable runfiles.
- Dedicated e2e coverage lives in `e2e/workspace/translate-c/transitive-cc-library-zig-binary`: default `output_test` and transitioned `output_test_external_translate_c`.
