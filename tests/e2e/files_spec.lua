local MiniTest = require "mini.test"
local helpers = require "helpers"

local T = MiniTest.new_set()

local function with_child(callback)
  local child = helpers.start_child()
  local ok, result = xpcall(function() return callback(child) end, debug.traceback)
  local stopped, stop_error = pcall(helpers.stop_child, child)
  if not stopped then error(tostring(stop_error), 0) end
  if not ok then error(result, 0) end
end

T["AC-CORE-022 and AC-INT-002 rename a temporary fixture file and replace visible buffer membership"] = function()
  with_child(function(child)
    local project = helpers.fixture_project(child)
    local result = child.lua_get [[
      (function()
        local project = vim.fn.getcwd()
        local source = project .. "/rename-source.lua"
        local destination = project .. "/rename-destination.lua"
        assert(vim.fn.writefile({ "return 'source'" }, source) == 0)
        vim.cmd.edit(vim.fn.fnameescape(source))
        local source_bufnr = vim.api.nvim_get_current_buf()
        vim.cmd.vsplit()
        vim.cmd.enew()
        local other_bufnr = vim.api.nvim_get_current_buf()
        vim.t.bufs = { source_bufnr, other_bufnr }

        local events = {}
        vim.api.nvim_create_autocmd("User", {
          pattern = "AstroRenameFilePre",
          callback = function(args)
            events.pre = {
              source_exists = vim.uv.fs_stat(source) ~= nil,
              destination_exists = vim.uv.fs_stat(destination) ~= nil,
              from = args.data.from,
              to = args.data.to,
            }
          end,
        })
        vim.api.nvim_create_autocmd("User", {
          pattern = "AstroRenameFilePost",
          callback = function(args)
            events.post = {
              source_exists = vim.uv.fs_stat(source) ~= nil,
              destination_exists = vim.uv.fs_stat(destination) ~= nil,
              success = args.data.success,
            }
          end,
        })

        local callback
        require("astrocore").rename_file {
          from = source,
          to = "rename-destination.lua",
          save = false,
          on_rename = function(from, to, success)
            callback = {
              from = from,
              to = to,
              success = success,
              source_exists = vim.uv.fs_stat(source) ~= nil,
              destination_exists = vim.uv.fs_stat(destination) ~= nil,
            }
          end,
        }

        local destination_bufnr = vim.fn.bufnr(destination)
        local windows = {}
        for _, winid in ipairs(vim.api.nvim_list_wins()) do
          table.insert(windows, vim.api.nvim_win_get_buf(winid))
        end
        return {
          source = source,
          destination = destination,
          source_bufnr = source_bufnr,
          destination_bufnr = destination_bufnr,
          source_exists = vim.uv.fs_stat(source) ~= nil,
          destination_exists = vim.uv.fs_stat(destination) ~= nil,
          source_valid = vim.api.nvim_buf_is_valid(source_bufnr),
          tab_buffers = vim.t.bufs,
          windows = windows,
          pre = events.pre,
          post = events.post,
          callback = callback,
        }
      end)()
    ]]

    MiniTest.expect.equality(result.source, project .. "/rename-source.lua")
    MiniTest.expect.equality(result.destination, project .. "/rename-destination.lua")
    MiniTest.expect.equality(result.source_exists, false)
    MiniTest.expect.equality(result.destination_exists, true)
    MiniTest.expect.equality(result.source_valid, false)
    MiniTest.expect.equality(result.pre.source_exists, true)
    MiniTest.expect.equality(result.pre.destination_exists, false)
    MiniTest.expect.equality(result.post.source_exists, false)
    MiniTest.expect.equality(result.post.destination_exists, true)
    MiniTest.expect.equality(result.post.success, true)
    MiniTest.expect.equality(result.callback, {
      from = result.source,
      to = result.destination,
      success = true,
      source_exists = false,
      destination_exists = true,
    })
    MiniTest.expect.equality(vim.tbl_contains(result.tab_buffers, result.source_bufnr), false)
    MiniTest.expect.equality(vim.tbl_contains(result.tab_buffers, result.destination_bufnr), true)
    MiniTest.expect.equality(vim.tbl_contains(result.windows, result.destination_bufnr), true)
  end)
end

T["AC-CORE-023 and AC-INT-002 preserve a temporary fixture source when filesystem rename fails"] = function()
  with_child(function(child)
    local project = helpers.fixture_project(child)
    local result = child.lua_get [[
      (function()
        local project = vim.fn.getcwd()
        local source = project .. "/rename-failure-source.lua"
        local destination = project .. "/rename-blocked"
        assert(vim.fn.writefile({ "return 'source'" }, source) == 0)
        assert(vim.fn.mkdir(destination, "p") == 1)
        vim.cmd.edit(vim.fn.fnameescape(source))
        local source_bufnr = vim.api.nvim_get_current_buf()
        vim.t.bufs = { source_bufnr }

        local events = {}
        vim.api.nvim_create_autocmd("User", {
          pattern = "AstroRenameFilePre",
          callback = function(args)
            events.pre = { source_exists = vim.uv.fs_stat(source) ~= nil, success = args.data.success }
          end,
        })
        vim.api.nvim_create_autocmd("User", {
          pattern = "AstroRenameFilePost",
          callback = function(args)
            events.post = { source_exists = vim.uv.fs_stat(source) ~= nil, success = args.data.success }
          end,
        })

        local callback
        require("astrocore").rename_file {
          from = source,
          to = destination,
          save = false,
          force = true,
          on_rename = function(from, to, success) callback = { from = from, to = to, success = success } end,
        }

        return {
          source = source,
          destination = destination,
          source_bufnr = source_bufnr,
          source_exists = vim.uv.fs_stat(source) ~= nil,
          destination_exists = vim.uv.fs_stat(destination) ~= nil,
          source_valid = vim.api.nvim_buf_is_valid(source_bufnr),
          tab_buffers = vim.t.bufs,
          pre = events.pre,
          post = events.post,
          callback = callback,
        }
      end)()
    ]]

    MiniTest.expect.equality(result.source, project .. "/rename-failure-source.lua")
    MiniTest.expect.equality(result.source_exists, true)
    MiniTest.expect.equality(result.destination_exists, true)
    MiniTest.expect.equality(result.source_valid, true)
    MiniTest.expect.equality(result.pre.source_exists, true)
    MiniTest.expect.equality(result.post.source_exists, true)
    MiniTest.expect.equality(result.post.success, false)
    MiniTest.expect.equality(result.callback.from, result.source)
    MiniTest.expect.equality(result.callback.to:gsub("/$", ""), result.destination)
    MiniTest.expect.equality(result.callback.success, false)
    MiniTest.expect.equality(result.tab_buffers, { result.source_bufnr })
  end)
end

return T
