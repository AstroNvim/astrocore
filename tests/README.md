# AstroCore test harness

Requirements: `make`, Git, and Neovim 0.11 or newer. Neovim 0.12.4 is the exact maintainer-aligned stable baseline; `make test-semantic` is the full compatibility target and also runs on the minimum supported Neovim 0.11.0.

```sh
make test
```

Every test target first runs `make test-prepare`. Preparation creates a generated `.tests/` environment from stable `lazy.nvim` and the ordered locked plugins: `echasnovski/mini.test`, `lunarmodules/luassert`, `Olivine-Labs/say`, `stevearc/resession.nvim`, and `nvim-treesitter/nvim-treesitter`. AstroCore always loads from the local checkout.

The schema 3 manifest records full dependency commits, the generated lockfile, copied luassert and say checksums, and allowed generated untracked files. The compatibility fingerprint contains only the canonical schema specification: dependency declarations, required paths, copied-library file lists, and untracked allowlists. It never contains local paths, resolved commits, or timestamps.

A valid marked environment is reused offline without writes. Missing environments are prepared from a complete staging directory and published atomically with `.ready` written last. An incomplete, unmarked, incompatible, or unsafe environment is never repaired or adopted. Run `make test-clear` and retry instead.

`make test-clear` removes only this repository's canonical `.tests/` directory. It rejects non-canonical paths and symbolic links before mutation. The lifecycle lock is `.tests.prepare.lock`; remove a stale lock only after confirming that no test preparation process owns it.

Run `make test-unit` for all parent unit and contract cases or `make test-e2e` for all child-Neovim semantic cases. Focused unit targets are `make test-unit-core`, `make test-unit-buffer`, `make test-unit-rooter`, `make test-unit-toggles`, `make test-unit-treesitter`, and `make test-unit-health-resession`. Focused child targets are `make test-setup`, `make test-files`, `make test-buffer`, `make test-rooter`, `make test-toggles`, and `make test-treesitter`. Harness targets are `make test-unit-environment`, `make test-unit-unit-helpers`, and `make test-unit-helpers`.

Unit specs use `tests/unit_helpers.lua` to restore package entries, selected nested `vim` replacements, notifications, scheduled and deferred callbacks, and test handles. Child specs use `tests/helpers.lua`, which creates isolated temporary XDG and deterministic Git fixtures, uses bounded waits, tracks child cleanup, and rejects unsafe fixture paths.

The suite has no visual helpers or visual goldens because AstroCore's owned contracts are fully expressible through semantic values, events, options, mappings, buffers, windows, filesystem state, and forwarded boundary arguments. Semantic assertions must precede any future visual snapshot, and a new exact visual baseline requires maintainer approval.
