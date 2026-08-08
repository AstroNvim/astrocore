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

T["AC-BUF-005 clears large-buffer decisions after a real buffer lifecycle and module reload"] = function()
  with_child(function(child)
    child.lua [[
      local astro = require "astrocore"
      astro.config = { features = { large_buf = { lines = 1 } } }

      local first = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(first, 0, -1, false, { "first", "second" })
      local buffer = require "astrocore.buffer"
      vim.g.astrocore_buffer_first_large = buffer.is_large(first)
      vim.api.nvim_buf_delete(first, { force = true })

      package.loaded["astrocore.buffer"] = nil
      buffer = require "astrocore.buffer"
      local second = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(second, 0, -1, false, { "second" })
      vim.g.astrocore_buffer_second_large = buffer.is_large(second)
    ]]

    MiniTest.expect.equality(child.lua_get "vim.g.astrocore_buffer_first_large", true)
    MiniTest.expect.equality(child.lua_get "vim.g.astrocore_buffer_second_large", false)
  end)
end

T["AC-BUF-013 and AC-INT-003 keep navigation and sorting isolated across real tabs"] = function()
  with_child(function(child)
    child.lua [[
      local buffer = require "astrocore.buffer"
      local first = vim.api.nvim_create_buf(true, false)
      local second = vim.api.nvim_create_buf(true, false)
      local third = vim.api.nvim_create_buf(true, false)
      local fourth = vim.api.nvim_create_buf(true, false)

      vim.api.nvim_set_current_buf(first)
      vim.t.bufs = { first, second }
      buffer.nav(1)
      vim.g.astrocore_buffer_first_tab_current = vim.api.nvim_get_current_buf()
      buffer.sort(function(a, b) return a > b end, true)
      vim.g.astrocore_buffer_first_tab_order = table.concat(vim.t.bufs, ",")
      vim.g.astrocore_buffer_first_tabpage = vim.api.nvim_get_current_tabpage()

      vim.cmd.tabnew()
      local second_tabpage = vim.api.nvim_get_current_tabpage()
      vim.api.nvim_set_current_buf(third)
      vim.t.bufs = { fourth, third }
      buffer.nav(-1)
      vim.g.astrocore_buffer_second_tab_current = vim.api.nvim_get_current_buf()
      buffer.sort(function(a, b) return a < b end, true)
      vim.g.astrocore_buffer_second_tab_order = table.concat(vim.t.bufs, ",")
      vim.g.astrocore_buffer_second_tabpage = second_tabpage

      vim.api.nvim_set_current_tabpage(vim.g.astrocore_buffer_first_tabpage)
      vim.g.astrocore_buffer_returned_first_tab_order = table.concat(vim.t.bufs, ",")
      vim.g.astrocore_buffer_returned_first_tab_current = vim.api.nvim_get_current_buf()
    ]]

    local first = child.lua_get "vim.g.astrocore_buffer_first_tab_current"
    local second = child.lua_get "vim.g.astrocore_buffer_second_tab_current"
    MiniTest.expect.equality(first ~= second, true)
    MiniTest.expect.equality(
      child.lua_get "vim.g.astrocore_buffer_first_tab_order",
      child.lua_get "vim.g.astrocore_buffer_returned_first_tab_order"
    )
    MiniTest.expect.equality(
      child.lua_get "vim.g.astrocore_buffer_first_tab_current",
      child.lua_get "vim.g.astrocore_buffer_returned_first_tab_current"
    )
    MiniTest.expect.equality(
      child.lua_get "vim.g.astrocore_buffer_first_tabpage ~= vim.g.astrocore_buffer_second_tabpage",
      true
    )
  end)
end

return T
