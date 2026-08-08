local MiniTest = require "mini.test"
local helpers = require "helpers"

local T = MiniTest.new_set()

T["AC-ROOT-008 AC-INT-004 detects a temporary Git root and changes global, tab, and window cwd"] = function()
  local child = helpers.start_child()
  local project = helpers.fixture_project(child)
  local ok, error_message = xpcall(function()
    local result = child.lua_get [[
      (function()
        local project = vim.fn.getcwd(-1, -1)
        local nested = project .. "/rooter/deep"
        assert(vim.fn.mkdir(nested, "p") == 1)
        assert(vim.fn.writefile({ "return true" }, nested .. "/fixture.lua") == 0)
        vim.cmd("edit " .. vim.fn.fnameescape(nested .. "/fixture.lua"))
        vim.opt.autochdir = false

        local rooter = require "astrocore.rooter"
        local config = { detector = { ".git" }, notify = false }
        local root = assert(rooter.detect(0, false, config)[1])

        vim.api.nvim_set_current_dir(nested)
        rooter.root(0, vim.tbl_extend("force", { scope = "global" }, config))
        local global_cwd = vim.fn.getcwd(-1, -1)

        vim.cmd("tcd " .. vim.fn.fnameescape(nested))
        assert(rooter.set_pwd(root, { scope = "tab", notify = false }))
        local tab_cwd = vim.fn.getcwd(-1, 0)
        local tab_local = vim.fn.haslocaldir(-1, 0) == 1

        vim.cmd("lcd " .. vim.fn.fnameescape(nested))
        assert(rooter.set_pwd(root, { scope = "win", notify = false }))
        local window_cwd = vim.fn.getcwd(0, 0)
        local window_local = vim.fn.haslocaldir(0, 0) == 1

        return {
          root = root.paths[1],
          global_cwd = global_cwd,
          tab_cwd = tab_cwd,
          tab_local = tab_local,
          window_cwd = window_cwd,
          window_local = window_local,
        }
      end)()
    ]]

    MiniTest.expect.equality(result.root, project)
    MiniTest.expect.equality(result.global_cwd, project)
    MiniTest.expect.equality(result.tab_cwd, project)
    MiniTest.expect.equality(result.tab_local, true)
    MiniTest.expect.equality(result.window_cwd, project)
    MiniTest.expect.equality(result.window_local, true)
  end, debug.traceback)
  local stopped, stop_error = pcall(helpers.stop_child, child)
  if not stopped then error(tostring(stop_error), 0) end
  if not ok then error(error_message, 0) end
end

return T
