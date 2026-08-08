local MiniTest = require "mini.test"
local helpers = require "helpers"

local T = MiniTest.new_set()

T["AC-ENV-013B snapshots and restores parent XDG variables"] = function()
  local snapshot = helpers.parent_xdg_environment()
  vim.env.XDG_CACHE_HOME = "/tmp/astrocore-parent-xdg-test"
  helpers.restore_parent_xdg_environment(snapshot)
  MiniTest.expect.equality(vim.uv.os_getenv "XDG_CACHE_HOME", snapshot.XDG_CACHE_HOME)
end

T["AC-ENV-014 starts an isolated temporary XDG and Git child fixture"] = function()
  local child = helpers.start_child()
  local project = helpers.fixture_project(child)
  local ok, error_message = xpcall(function()
    helpers.wait_until(child, "vim.fn.isdirectory(vim.fn.getcwd()) == 1", "child fixture startup")
    MiniTest.expect.equality(child.lua_get "vim.fn.getcwd()", project)
    MiniTest.expect.equality(child.lua_get "vim.env.XDG_DATA_HOME ~= nil", true)
  end, debug.traceback)
  local stopped, stop_error = pcall(helpers.stop_child, child)
  if not stopped then error(tostring(stop_error), 0) end
  if not ok then error(error_message, 0) end
end

return T
