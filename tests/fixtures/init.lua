local root = assert(vim.env.ASTROCORE_TEST_ROOT, "ASTROCORE_TEST_ROOT is required")
local lazy_path = assert(vim.env.ASTROCORE_TEST_LAZY_PATH, "ASTROCORE_TEST_LAZY_PATH is required")
local plugin_root = assert(vim.env.ASTROCORE_TEST_PLUGIN_ROOT, "ASTROCORE_TEST_PLUGIN_ROOT is required")
local lockfile = assert(vim.env.ASTROCORE_TEST_LOCKFILE, "ASTROCORE_TEST_LOCKFILE is required")
local test_lua_dir = assert(vim.env.ASTROCORE_TEST_LUA_DIR, "ASTROCORE_TEST_LUA_DIR is required")

vim.env.LAZY_OFFLINE = "1"
package.path = test_lua_dir
  .. "/?.lua;"
  .. test_lua_dir
  .. "/?/init.lua;"
  .. root
  .. "/lua/?.lua;"
  .. root
  .. "/lua/?/init.lua;"
  .. package.path
vim.env.LAZY = lazy_path
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(lazy_path)

require("lazy.minit").setup {
  root = plugin_root,
  lockfile = lockfile,
  local_spec = false,
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  pkg = { enabled = false },
  rocks = { enabled = false },
  performance = { cache = { enabled = false } },
}
