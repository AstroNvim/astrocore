# Changelog

## [1.4.0](https://github.com/AstroNvim/astrocore/compare/v1.3.3...v1.4.0) (2024-05-24)


### Features

* **rooter:** allow `rooter.ignore.servers` to be an arbitrary filter function ([0283868](https://github.com/AstroNvim/astrocore/commit/028386800779b29a1cea238897d0ff4b8f45599e))
* **rooter:** allow passing rooter configurations to rooting functions for API execution ([0707cb4](https://github.com/AstroNvim/astrocore/commit/0707cb4b91d899975d79d0c57ae1feee3c684e00))

## [1.3.3](https://github.com/AstroNvim/astrocore/compare/v1.3.2...v1.3.3) (2024-05-13)


### Bug Fixes

* **rooter:** detect unique LSP roots in the case of multiple language servers ([c15cfb2](https://github.com/AstroNvim/astrocore/commit/c15cfb23352a0f09b79551286dc8c59cc5876423))

## [1.3.2](https://github.com/AstroNvim/astrocore/compare/v1.3.1...v1.3.2) (2024-05-07)


### Bug Fixes

* don't schedule functions when loading plugins ([70b9a20](https://github.com/AstroNvim/astrocore/commit/70b9a209bade26bde4256b9d8abfb2a6e67ef723))

## [1.3.1](https://github.com/AstroNvim/astrocore/compare/v1.3.0...v1.3.1) (2024-05-06)


### Bug Fixes

* don't trim content by default when reading a file ([c637f51](https://github.com/AstroNvim/astrocore/commit/c637f51cb83786fc50d0b8075175e7a3e27db2ef))

## [1.3.0](https://github.com/AstroNvim/astrocore/compare/v1.2.2...v1.3.0) (2024-05-06)


### Features

* add `read_file` utility ([d9b2a47](https://github.com/AstroNvim/astrocore/commit/d9b2a47fb358e903712e4b94e539dbcf38900629))

## [1.2.2](https://github.com/AstroNvim/astrocore/compare/v1.2.1...v1.2.2) (2024-04-29)


### Bug Fixes

* **rooter:** normalization of path "/" should be "/" ([60db5cc](https://github.com/AstroNvim/astrocore/commit/60db5cce71685330bb275a89224847d20fffd62f))


### Reverts

* use `vim.keymap.set` defaults ([cbd996e](https://github.com/AstroNvim/astrocore/commit/cbd996ef7b1c949bb1b89c3dbfe0857042ef5625))

## [1.2.1](https://github.com/AstroNvim/astrocore/compare/v1.2.0...v1.2.1) (2024-04-22)


### Bug Fixes

* add check for new `islist` function ([248e38a](https://github.com/AstroNvim/astrocore/commit/248e38a3e2e8d4316705403644dcda8ec63a31f6))

## [1.2.0](https://github.com/AstroNvim/astrocore/compare/v1.1.3...v1.2.0) (2024-04-17)


### Features

* allow specific window to be provided to `delete_url_match` and `set_url_match` ([2a77fdc](https://github.com/AstroNvim/astrocore/commit/2a77fdc69dc04afe917dd5fac68a01fab1bea806))
* store current window `highlighturl` state ([abe1ce8](https://github.com/AstroNvim/astrocore/commit/abe1ce821876a836f7576bc75c97f6f6ae8f415f))


### Bug Fixes

* **toggles:** toggle all windows when toggling url matching ([417f798](https://github.com/AstroNvim/astrocore/commit/417f79836bb6ae9ae249b7ca11258939a07f598a))

## [1.1.3](https://github.com/AstroNvim/astrocore/compare/v1.1.2...v1.1.3) (2024-04-17)


### Bug Fixes

* make sure buffers are valid before checking for filetype ([83e5425](https://github.com/AstroNvim/astrocore/commit/83e5425c89887eb616e8dc6530d97f7b9c19e942))

## [1.1.2](https://github.com/AstroNvim/astrocore/compare/v1.1.1...v1.1.2) (2024-04-09)


### Bug Fixes

* add missing function mapping type ([1d2b396](https://github.com/AstroNvim/astrocore/commit/1d2b396fcf07008b771b923aaca724d0b8dcf8f9))

## [1.1.1](https://github.com/AstroNvim/astrocore/compare/v1.1.0...v1.1.1) (2024-04-05)


### Bug Fixes

* hide `nvim_exec_autocmds` errors with `pcall` ([1736458](https://github.com/AstroNvim/astrocore/commit/1736458b321c59c6e57c456f0f39c0665b301591))

## [1.1.0](https://github.com/AstroNvim/astrocore/compare/v1.0.1...v1.1.0) (2024-04-05)


### Features

* add `exec_buffer_autocmds` to execute autocommands in each file buffer ([f2088d2](https://github.com/AstroNvim/astrocore/commit/f2088d2afc5d19e51ca363156bfbbb9f89093fa0))

## [1.0.1](https://github.com/AstroNvim/astrocore/compare/v1.0.0...v1.0.1) (2024-04-02)


### Bug Fixes

* **resession:** fix restoration of single tabpages ([8de07ce](https://github.com/AstroNvim/astrocore/commit/8de07ce5403d291be4434e7ca333b61cfc9c74f9))

## 1.0.0 (2024-03-20)


### ⚠ BREAKING CHANGES

* remove `get_hlgroup` now available in AstroUI
* **config:** rename `features.max_file` to `features.large_buf`
* **toggles:** remove indent guide toggle
* move to variable arguments for `list_insert` and `load_plugin_with_func`
* remove `alpha_button` function since alpha provides it's own
* **buffer:** modularize `astrocore.buffer.comparator`
* drop support for Neovim v0.8
* move `astrocore.utils` to root `astrocore` module
* remove astronvim updater and git utilities
* move autocmds,user commands, on_key to configuration table
* icons moved to AstroUI

### Features

* add `on_load` function to execute a function when a plugin loads ([254a94d](https://github.com/AstroNvim/astrocore/commit/254a94d3c188b1fd1a24952cbc61d2799171c6bc))
* add `silent` to default keymap options ([11af187](https://github.com/AstroNvim/astrocore/commit/11af1879701539badd654206514fd1518ec6336d))
* add `vim.fn.sign_define` and `vim.diagnostic.config` support ([184bd90](https://github.com/AstroNvim/astrocore/commit/184bd90f63c6ab87ca1f0fdef310608bff6de285))
* add `wslview` support to `system_open` ([6a79c20](https://github.com/AstroNvim/astrocore/commit/6a79c20b196aefae75ce684b051587b2585a9045))
* add ability for `on_load` to easily just load another plugin ([ca29e21](https://github.com/AstroNvim/astrocore/commit/ca29e21c1a5ffa210fa39336126f9591f9966c5c))
* add ability for multiple plugins to be supplied to `on_load` ([720bf6b](https://github.com/AstroNvim/astrocore/commit/720bf6b2a95eaa7433c155b040d0488a9f0bc43c))
* add ability to configure filetypes with `vim.filetype.add` ([51ac59f](https://github.com/AstroNvim/astrocore/commit/51ac59f6a4e1ec84bfaee07a027495a35e7beaf4))
* add buffer utilities ([2f74a61](https://github.com/AstroNvim/astrocore/commit/2f74a61db34f6193aa4cc97e6f93682ab4858527))
* add experimental rooter ([96eb638](https://github.com/AstroNvim/astrocore/commit/96eb6381f64b437d8abf5098e62695f106cd47df))
* add healthchecks ([7a5b7e7](https://github.com/AstroNvim/astrocore/commit/7a5b7e7c809dc09a0a7f324a2b1571f4a2efcb64))
* add mapping configuration and autocmds ([a45533b](https://github.com/AstroNvim/astrocore/commit/a45533b22310d2dfe603617875a98dbd7094213e))
* add Mason utility functions ([92b40bc](https://github.com/AstroNvim/astrocore/commit/92b40bc9a5c390c8323a20862fe4e489d113ad89))
* add polish function ([485b727](https://github.com/AstroNvim/astrocore/commit/485b72796b460eead192fd09eb8f546fca6a8c80))
* add resession extension for AstroCore ([5217973](https://github.com/AstroNvim/astrocore/commit/52179734242211c61dbfae0efb8268ed04b535d0))
* add types for autocompletion with `lua_ls` ([63ed189](https://github.com/AstroNvim/astrocore/commit/63ed18904ff3f0d7a761eba0f5a9da2d49bee95a))
* add UI/UX toggle utilities ([1878654](https://github.com/AstroNvim/astrocore/commit/1878654739444f81c2e1cb43a381b4975635e0d8))
* allow `false` to disable autocmds, commands, or on_key functions ([38991f9](https://github.com/AstroNvim/astrocore/commit/38991f940cb40cbd5fe0a3634129f9c7eca6a1a9))
* allow `large_buf` to be set to `false` to disable detection ([ac0f0bd](https://github.com/AstroNvim/astrocore/commit/ac0f0bddfd06c77345f367e4611461e338365dfb))
* allow vim options to be configured ([e81ff58](https://github.com/AstroNvim/astrocore/commit/e81ff580c08756f762ff029a3f4fb2bd73c42974))
* **buffer:** add `wipe` function to fully wipe a buffer ([685da23](https://github.com/AstroNvim/astrocore/commit/685da236d8649fb6c259ec8b49c5f74b84020cc9))
* **buffer:** add ability for `close_tab` to close a specific tabpage ([1b57b25](https://github.com/AstroNvim/astrocore/commit/1b57b25107be19250aeca9f4bede0764f94c32c9))
* clean up rooter and add toggle function ([f22dcfe](https://github.com/AstroNvim/astrocore/commit/f22dcfe6134a5cf31f92e1dcd6538010da4ef4b1))
* **config:** rename `features.max_file` to `features.large_buf` ([e2df9f0](https://github.com/AstroNvim/astrocore/commit/e2df9f0c037f3ccbdd65b2555761f2856ec01064))
* make `event` function more extendable ([4708247](https://github.com/AstroNvim/astrocore/commit/4708247df2a0a01672081deb48a1b8961225a97f))
* move astronvim specific features to configuration ([4b1a21a](https://github.com/AstroNvim/astrocore/commit/4b1a21ae4de92f2bf45f8cb506ee13955f382149))
* move autocmds,user commands, on_key to configuration table ([a2b0564](https://github.com/AstroNvim/astrocore/commit/a2b0564f8060f4d911cc53c1e8731b4cd944e4c4))
* move git and updater utilities ([8899cc3](https://github.com/AstroNvim/astrocore/commit/8899cc3f8cf4d2701e52c3d3ed0e6b92989964a9))
* move to variable arguments for `list_insert` and `load_plugin_with_func` ([1c7fcd5](https://github.com/AstroNvim/astrocore/commit/1c7fcd57cbdaef0ad02109e50f6748b051b8b80e))
* **toggles:** add `buffer_indent_guides` toggle ([515d5f3](https://github.com/AstroNvim/astrocore/commit/515d5f3083e4b350852a54a8581dd736a69c3691))
* **toggles:** add buffer local cmp toggle ([aa3d013](https://github.com/AstroNvim/astrocore/commit/aa3d013ca06734b1596dd2aa88e91c793bffc01e))
* use `on_load` to load which-key queue automatically ([be8c860](https://github.com/AstroNvim/astrocore/commit/be8c86010cbe178e42c9efd5f3763fec360f5559))
* **utils:** add update_packages utility to update lazy and mason ([76eb2f7](https://github.com/AstroNvim/astrocore/commit/76eb2f7d72fed4b06955e5e8a43eff64a2612666))


### Bug Fixes

* **buffer:** fix `bd` usage when `bufnr` is 0 ([ec82070](https://github.com/AstroNvim/astrocore/commit/ec82070afdce258cfb52c1e32e40edbacc67dcd9))
* don't schedule polish ([de74fa4](https://github.com/AstroNvim/astrocore/commit/de74fa40522bf416f0e5912b6e114cd4a0adaa85))
* extend `on_exit` passed to custom toggle terminal ([08f73ce](https://github.com/AstroNvim/astrocore/commit/08f73cee62e38793085c631f32036ff76e3c9c50))
* guarantee M.config always exists ([cc33dfc](https://github.com/AstroNvim/astrocore/commit/cc33dfc22ed909534282331136ae87ee0662aaa5))
* **health:** update healthcheck ([53af950](https://github.com/AstroNvim/astrocore/commit/53af950399a6bc940012613221a849e1f805f99f))
* incorrect docstring for `rooter` settings ([36aa11d](https://github.com/AstroNvim/astrocore/commit/36aa11d3923bb287ab0e90b702af16ac7c0141ef))
* localize user terminals to utilities ([4e406cc](https://github.com/AstroNvim/astrocore/commit/4e406cc95e529ddcda8e3ada043c51f288f7671d))
* protect function lazy loading against asynchronous loops ([7e125ac](https://github.com/AstroNvim/astrocore/commit/7e125acf7bddc981cbd4d0e1f8c1fa08eee50990))
* **resession:** only change buffers on load if cursor is in a wipe buffer ([1a1bff7](https://github.com/AstroNvim/astrocore/commit/1a1bff7da93497ea9751a4dc71cfadb99ddc4804))
* **resession:** rename extension to `astrocore` ([771930c](https://github.com/AstroNvim/astrocore/commit/771930c9c16035c0c77ca0dda857fdb3d2826669))
* **rooter:** allow project root detection for files that do not yet exist ([c691761](https://github.com/AstroNvim/astrocore/commit/c6917610c4065f74519c5dd64782baaa2619ac33))
* **rooter:** only check patterns for existing paths ([42a9394](https://github.com/AstroNvim/astrocore/commit/42a939433007a891449ef67bce4c0dc3048abe00))
* **toggles:** immediately refresh `mini.indentscope` ([526cbc3](https://github.com/AstroNvim/astrocore/commit/526cbc3f14b75510d7236bf73557a964fcb6fe91))
* **toggles:** update semantic_tokens_enabled to just semantic_tokens ([8f6b75f](https://github.com/AstroNvim/astrocore/commit/8f6b75fb916c8a952663112102f72485354c8140))
* unhide custom toggle terminals by default ([027e12b](https://github.com/AstroNvim/astrocore/commit/027e12b93d70cae4063f97b38d782718b0160c98))
* update `reload` function for new `options` structure ([b8e8a9b](https://github.com/AstroNvim/astrocore/commit/b8e8a9b031aa2abdb39b7d2ff624b25ca2edd0c7))
* update reload function with new structure ([7f5df22](https://github.com/AstroNvim/astrocore/commit/7f5df2200898934a2606f35b3d01cd9754a2a09f))
* use `explorer.exe` instead of `wslview` in WSL ([495f339](https://github.com/AstroNvim/astrocore/commit/495f339b30ba51c282d54fae58a2db0df684a32f))
* **utils:** reload AstroUI as well as AstroCore ([ad12e9c](https://github.com/AstroNvim/astrocore/commit/ad12e9c3683acf09544acc1cc8d414005df377bd))


### Performance Improvements

* optimize `list_insert_unique` ([58b832d](https://github.com/AstroNvim/astrocore/commit/58b832d46a439febd8e808de4731e19b332261a8))
* remove need to make deep copies ([4e677ff](https://github.com/AstroNvim/astrocore/commit/4e677ff984f099832041feb6b7d304b1388f2ff6))


### Reverts

* continue hiding custom toggle terminals by default ([c9d24ce](https://github.com/AstroNvim/astrocore/commit/c9d24ce03e16dc6b542a2fa3203eec43db2ddd5c))
* move `list_insert_unique` and `load_plugin_with_func` back to taking lists instead of variable arguments ([1f3ae05](https://github.com/AstroNvim/astrocore/commit/1f3ae05f5df572f3674e223a669f9895935c95de))


### Miscellaneous Chores

* drop support for Neovim v0.8 ([3213349](https://github.com/AstroNvim/astrocore/commit/3213349bfca03934ba4bc0c33aff6321b0c1e7f2))


### Code Refactoring

* **buffer:** modularize `astrocore.buffer.comparator` ([8651582](https://github.com/AstroNvim/astrocore/commit/8651582e7324bb84118444613366829723d0725c))
* icons moved to AstroUI ([18e9189](https://github.com/AstroNvim/astrocore/commit/18e9189574ecae363074c7d23f9729cdf7f3818f))
* move `astrocore.utils` to root `astrocore` module ([60d9aaf](https://github.com/AstroNvim/astrocore/commit/60d9aaff0306aab978f31ffb55fc326c724ad254))
* remove `alpha_button` function since alpha provides it's own ([484de60](https://github.com/AstroNvim/astrocore/commit/484de6051cfd9ffdb53fd967397d80836fcb846e))
* remove `get_hlgroup` now available in AstroUI ([3ff32fb](https://github.com/AstroNvim/astrocore/commit/3ff32fb1137dd4425713626738ad9ca11a53f0b3))
* remove astronvim updater and git utilities ([a26729d](https://github.com/AstroNvim/astrocore/commit/a26729d082123c65d4dff4fbe895a1e8cf719d3a))
* **toggles:** remove indent guide toggle ([a063322](https://github.com/AstroNvim/astrocore/commit/a06332290c833810fd22cacf37837dce5b0a39c3))
