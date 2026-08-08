local MiniTest = require "mini.test"
local helpers = require "helpers"

local T = MiniTest.new_set()

local function with_child(callback)
  local child = helpers.start_child()
  local ok, error_message = xpcall(function() callback(child) end, debug.traceback)
  local stopped, stop_error = pcall(helpers.stop_child, child)
  if not stopped then error(tostring(stop_error), 0) end
  if not ok then error(error_message, 0) end
end

T["AC-TGL-004 and AC-INT-003 change global, window, and buffer options in a child Neovim"] = function()
  with_child(function(child)
    local result = child.lua_get [[
      (function()
        local toggles = require "astrocore.toggles"
        local first = vim.api.nvim_get_current_win()
        vim.cmd "vsplit"
        local second = vim.api.nvim_get_current_win()
        vim.api.nvim_win_call(second, function() vim.cmd.enew() end)

        vim.go.background = "dark"
        local backgrounds = {}
        for _ = 1, 2 do
          toggles.background(true)
          table.insert(backgrounds, vim.go.background)
        end

        vim.go.showtabline = 0
        local tablines = {}
        for _ = 1, 2 do
          toggles.tabline(true)
          table.insert(tablines, vim.go.showtabline)
        end

        vim.go.conceallevel = 0
        local conceallevels = {}
        for _ = 1, 2 do
          toggles.conceal(true)
          table.insert(conceallevels, vim.go.conceallevel)
        end

        vim.go.laststatus = 0
        local statuses = {}
        for _ = 1, 3 do
          toggles.statusline(true)
          table.insert(statuses, vim.go.laststatus)
        end

        vim.api.nvim_win_call(first, function()
          vim.wo.signcolumn = "auto"
          vim.wo.number = false
          vim.wo.relativenumber = false
          vim.wo.spell = false
          vim.wo.wrap = false
        end)
        vim.api.nvim_win_call(second, function()
          vim.wo.signcolumn = "yes"
          vim.wo.number = true
          vim.wo.relativenumber = false
          vim.wo.spell = false
          vim.wo.wrap = false
        end)

        local signcolumns, numbers = {}, {}
        vim.api.nvim_win_call(first, function()
          for _ = 1, 3 do
            toggles.signcolumn(true)
            table.insert(signcolumns, vim.wo.signcolumn)
          end
          for _ = 1, 4 do
            toggles.number(true)
            table.insert(numbers, { vim.wo.number, vim.wo.relativenumber })
          end
          toggles.spell(true)
          toggles.wrap(true)
        end)

        vim.go.paste = false
        toggles.paste(true)

        local original_input = vim.fn.input
        vim.fn.input = function() return "3" end
        vim.api.nvim_win_call(first, function() toggles.indent(true) end)
        vim.fn.input = original_input

        local first_window = vim.api.nvim_win_call(first, function()
          return {
            signcolumn = vim.wo.signcolumn,
            number = vim.wo.number,
            relativenumber = vim.wo.relativenumber,
            spell = vim.wo.spell,
            wrap = vim.wo.wrap,
            expandtab = vim.bo.expandtab,
            tabstop = vim.bo.tabstop,
            softtabstop = vim.bo.softtabstop,
            shiftwidth = vim.bo.shiftwidth,
          }
        end)
        local second_window = vim.api.nvim_win_call(second, function()
          return {
            signcolumn = vim.wo.signcolumn,
            number = vim.wo.number,
            relativenumber = vim.wo.relativenumber,
            spell = vim.wo.spell,
            wrap = vim.wo.wrap,
          }
        end)

        return {
          backgrounds = backgrounds,
          tablines = tablines,
          conceallevels = conceallevels,
          statuses = statuses,
          signcolumns = signcolumns,
          numbers = numbers,
          paste = vim.go.paste,
          first_window = first_window,
          second_window = second_window,
        }
      end)()
    ]]

    MiniTest.expect.equality(result.backgrounds, { "light", "dark" })
    MiniTest.expect.equality(result.tablines, { 2, 0 })
    MiniTest.expect.equality(result.conceallevels, { 2, 0 })
    MiniTest.expect.equality(result.statuses, { 2, 3, 0 })
    MiniTest.expect.equality(result.signcolumns, { "no", "yes", "auto" })
    MiniTest.expect.equality(result.numbers, { { true, false }, { true, true }, { false, true }, { false, false } })
    MiniTest.expect.equality(result.paste, true)
    MiniTest.expect.equality(result.first_window, {
      signcolumn = "auto",
      number = false,
      relativenumber = false,
      spell = true,
      wrap = true,
      expandtab = true,
      tabstop = 3,
      softtabstop = 3,
      shiftwidth = 3,
    })
    MiniTest.expect.equality(result.second_window, {
      signcolumn = "yes",
      number = true,
      relativenumber = false,
      spell = false,
      wrap = false,
    })
  end)
end

T["AC-TGL-008 and AC-INT-003 restore foldcolumns per window and preserve a foreign value"] = function()
  with_child(function(child)
    local result = child.lua_get [[
      (function()
        local toggles = require "astrocore.toggles"
        local first = vim.api.nvim_get_current_win()
        vim.cmd "vsplit"
        local second = vim.api.nvim_get_current_win()

        vim.api.nvim_win_call(first, function()
          vim.wo.foldcolumn = "2"
          toggles.foldcolumn(true)
        end)
        vim.api.nvim_win_call(second, function()
          vim.wo.foldcolumn = "4"
          toggles.foldcolumn(true)
        end)

        vim.api.nvim_win_call(first, function() vim.wo.foldcolumn = "6" end)
        vim.api.nvim_win_call(first, function() toggles.foldcolumn(true) end)
        vim.api.nvim_win_call(first, function() toggles.foldcolumn(true) end)
        vim.api.nvim_win_call(second, function() toggles.foldcolumn(true) end)

        return {
          first = vim.api.nvim_win_call(first, function() return vim.wo.foldcolumn end),
          second = vim.api.nvim_win_call(second, function() return vim.wo.foldcolumn end),
        }
      end)()
    ]]

    MiniTest.expect.equality(result, { first = "6", second = "4" })
  end)
end

return T
