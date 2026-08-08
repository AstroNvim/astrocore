local MiniTest = require "mini.test"
local helpers = require "helpers"

local T = MiniTest.new_set()
local xdg_variables = { "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR" }

T["AC-ENV-013B restores all parent XDG variables, including unset values"] = function()
  local parent = helpers.parent_xdg_environment()
  local ok, error_message = xpcall(function()
    for index, name in ipairs(xdg_variables) do
      vim.env[name] = "/tmp/astrocore-parent-xdg-" .. index
    end
    local snapshot = helpers.parent_xdg_environment()
    for index, name in ipairs(xdg_variables) do
      vim.env[name] = "/tmp/astrocore-mutated-xdg-" .. index
    end
    helpers.restore_parent_xdg_environment(snapshot)
    for _, name in ipairs(xdg_variables) do
      MiniTest.expect.equality(vim.uv.os_getenv(name), snapshot[name])
    end

    vim.env.XDG_RUNTIME_DIR = nil
    local unset_snapshot = helpers.parent_xdg_environment()
    vim.env.XDG_RUNTIME_DIR = "/tmp/astrocore-mutated-runtime"
    helpers.restore_parent_xdg_environment(unset_snapshot)
    MiniTest.expect.equality(vim.uv.os_getenv "XDG_RUNTIME_DIR", nil)
  end, debug.traceback)
  helpers.restore_parent_xdg_environment(parent)
  if not ok then error(error_message, 0) end
end

T["AC-ENV-014 starts an isolated temporary XDG and Git child fixture"] = function()
  local child = helpers.start_child()
  local project = helpers.fixture_project(child)
  local root = helpers.fixture_root(child)
  local job_id = helpers.child_job_id(child)
  MiniTest.expect.equality(type(job_id), "number")
  MiniTest.expect.equality(vim.fn.jobwait({ job_id }, 0)[1], -1)
  local ok, error_message = xpcall(function()
    helpers.wait_until(child, "vim.fn.isdirectory(vim.fn.getcwd()) == 1", "child fixture startup")
    MiniTest.expect.equality(child.lua_get "vim.fn.getcwd()", project)
    MiniTest.expect.equality(
      child.lua_get [[
      {
        vim.env.XDG_CONFIG_HOME,
        vim.env.XDG_DATA_HOME,
        vim.env.XDG_STATE_HOME,
        vim.env.XDG_CACHE_HOME,
        vim.env.XDG_RUNTIME_DIR,
      }
    ]],
      {
        root .. "/config",
        root .. "/data",
        root .. "/state",
        root .. "/cache",
        root .. "/runtime",
      }
    )
    MiniTest.expect.equality(
      child.lua_get "vim.fn.system({ 'git', 'config', '--get', 'core.hooksPath' })",
      root .. "/git-hooks\n"
    )
  end, debug.traceback)
  local stopped, stop_error = pcall(helpers.stop_child, child)
  if not stopped then error(tostring(stop_error), 0) end
  if not ok then error(error_message, 0) end
  MiniTest.expect.equality(vim.fn.jobwait({ job_id }, 0)[1] ~= -1, true)
  MiniTest.expect.equality(vim.uv.fs_lstat(root), nil)
end

return T
