#!/usr/bin/env -S nvim -l

local tests_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
package.path = tests_dir .. "/?.lua;" .. package.path

local config = require "config"

vim.env.LAZY_OFFLINE = "1"
config.assert_ready_environment()

package.path = config.test_lua_dir
  .. "/?.lua;"
  .. config.test_lua_dir
  .. "/?/init.lua;"
  .. config.root
  .. "/lua/?.lua;"
  .. config.root
  .. "/lua/?/init.lua;"
  .. package.path
vim.env.LAZY = config.lazy_path
vim.opt.rtp:prepend(config.root)
vim.opt.rtp:prepend(config.lazy_path)

require("lazy.minit").setup {
  root = config.plugin_root,
  lockfile = config.lockfile,
  local_spec = false,
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  pkg = { enabled = false },
  rocks = { enabled = false },
  performance = { cache = { enabled = false } },
}
