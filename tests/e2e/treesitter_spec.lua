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

T["AC-TS-011 and AC-INT-005 preserve real buffer option and keymap ownership through cleanup"] = function()
  with_child(function(child)
    local result = child.lua_get [[
      (function()
        local starts, stops = {}, {}
        local original_language = vim.treesitter.language.get_lang
        local original_query = vim.treesitter.query.get
        local original_start = vim.treesitter.start
        local original_stop = vim.treesitter.stop
        local original_executable = vim.fn.executable
        vim.treesitter.language.get_lang = function(filetype) return filetype == "lua" and "lua" or nil end
        vim.treesitter.query.get = function(_, query)
          if query == "textobjects" then return { captures = { "function.outer" } } end
          return {}
        end
        vim.treesitter.start = function(bufnr) table.insert(starts, bufnr) end
        vim.treesitter.stop = function(bufnr) table.insert(stops, bufnr) end
        vim.fn.executable = function(program)
          if program == "tree-sitter" then return 1 end
          return original_executable(program)
        end
        package.loaded["nvim-treesitter"] = {
          get_installed = function() return { "lua" } end,
          get_available = function() return { "lua" } end,
          install = function() error "parser installation is outside this state test" end,
        }
        package.loaded["nvim-treesitter-textobjects"] = {}
        package.loaded["nvim-treesitter-textobjects.select"] = { select_outer = function() end }

        local treesitter = require "astrocore.treesitter"
        treesitter.setup {
          enabled = true,
          highlight = true,
          indent = true,
          textobjects = {
            select = {
              select_outer = {
                aa = { query = "@function.outer", group = "textobjects", desc = "Select function" },
              },
            },
          },
        }

        local function enable_buffer(indentexpr)
          local bufnr = vim.api.nvim_create_buf(true, false)
          vim.bo[bufnr].filetype = "lua"
          vim.bo[bufnr].indentexpr = indentexpr
          vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
          return bufnr
        end
        local function has_mapping(bufnr, mode)
          return vim.api.nvim_buf_call(bufnr, function()
            return vim.fn.maparg("aa", mode, false, true).buffer == 1
              and vim.api.nvim_buf_get_keymap(bufnr, mode)[1] ~= nil
          end)
        end

        local restored = enable_buffer "manual"
        local restored_enabled = treesitter.is_enabled(restored)
        local restored_indent = vim.bo[restored].indentexpr
        local restored_mappings = { has_mapping(restored, "x"), has_mapping(restored, "o") }
        treesitter.disable(restored)

        local foreign = enable_buffer "manual"
        vim.bo[foreign].indentexpr = "foreign"
        treesitter.disable(foreign)

        vim.treesitter.language.get_lang = original_language
        vim.treesitter.query.get = original_query
        vim.treesitter.start = original_start
        vim.treesitter.stop = original_stop
        vim.fn.executable = original_executable
        return {
          restored_enabled = restored_enabled,
          restored_indent = restored_indent,
          restored_mappings = restored_mappings,
          restored_after = {
            indentexpr = vim.bo[restored].indentexpr,
            x = vim.api.nvim_buf_call(restored, function() return vim.fn.maparg("aa", "x", false, true).buffer end),
            o = vim.api.nvim_buf_call(restored, function() return vim.fn.maparg("aa", "o", false, true).buffer end),
          },
          foreign_indent = vim.bo[foreign].indentexpr,
          foreign_after = {
            x = vim.api.nvim_buf_call(foreign, function() return vim.fn.maparg("aa", "x", false, true).buffer end),
            o = vim.api.nvim_buf_call(foreign, function() return vim.fn.maparg("aa", "o", false, true).buffer end),
          },
          starts = starts,
          stops = stops,
        }
      end)()
    ]]

    MiniTest.expect.equality(result.restored_enabled, true)
    MiniTest.expect.equality(result.restored_indent, "v:lua.require'nvim-treesitter'.indentexpr()")
    MiniTest.expect.equality(result.restored_mappings, { true, true })
    MiniTest.expect.equality(result.restored_after.indentexpr, "manual")
    MiniTest.expect.equality(result.restored_after.x, nil)
    MiniTest.expect.equality(result.restored_after.o, nil)
    MiniTest.expect.equality(result.foreign_indent, "foreign")
    MiniTest.expect.equality(result.foreign_after.x, nil)
    MiniTest.expect.equality(result.foreign_after.o, nil)
    MiniTest.expect.equality(#result.starts >= 2, true)
    MiniTest.expect.equality(#result.stops >= 2, true)
  end)
end

T["AC-TS-013 keeps exactly one active owned FileType callback after repeated setup"] = function()
  with_child(function(child)
    local result = child.lua_get [[
      (function()
        local original_language = vim.treesitter.language.get_lang
        local original_query = vim.treesitter.query.get
        local original_executable = vim.fn.executable
        vim.treesitter.language.get_lang = function(filetype) return filetype == "lua" and "lua" or nil end
        vim.treesitter.query.get = function() return {} end
        vim.fn.executable = function(program)
          if program == "tree-sitter" then return 1 end
          return original_executable(program)
        end
        package.loaded["nvim-treesitter"] = {
          get_installed = function() return { "lua" } end,
          get_available = function() return { "lua" } end,
          install = function() error "parser installation is outside this state test" end,
        }

        vim.api.nvim_create_augroup("astrocore_treesitter", { clear = true })
        local treesitter = require "astrocore.treesitter"
        treesitter.setup { enabled = true, highlight = true }
        treesitter.setup { enabled = true, highlight = true }

        local group = vim.api.nvim_create_augroup("astrocore_treesitter", { clear = false })
        local callbacks = vim.api.nvim_get_autocmds { group = group, event = "FileType" }
        local callback_count, groups = 0, {}
        for _, callback in ipairs(callbacks) do
          callback_count = callback_count + 1
          groups[callback.group] = true
        end
        local active_groups = 0
        for _ in pairs(groups) do
          active_groups = active_groups + 1
        end

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.bo[bufnr].filetype = "lua"
        vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })

        local enabled = treesitter.is_enabled(bufnr)
        vim.treesitter.language.get_lang = original_language
        vim.treesitter.query.get = original_query
        vim.fn.executable = original_executable
        return {
          callback_count = callback_count,
          active_groups = active_groups,
          group_name = callbacks[1] and callbacks[1].group_name,
          enabled = enabled,
        }
      end)()
    ]]

    MiniTest.expect.equality(result.callback_count, 1)
    MiniTest.expect.equality(result.active_groups, 1)
    MiniTest.expect.equality(result.group_name, "astrocore_treesitter")
    MiniTest.expect.equality(result.enabled, true)
  end)
end

T["AC-TS-014 preserves foreign string mappings while clearing owned Treesitter callbacks"] = function()
  with_child(function(child)
    local result = child.lua_get [[
      (function()
        local original_language = vim.treesitter.language.get_lang
        local original_query = vim.treesitter.query.get
        local original_executable = vim.fn.executable
        vim.treesitter.language.get_lang = function(filetype) return filetype == "lua" and "lua" or nil end
        vim.treesitter.query.get = function(_, query)
          if query == "textobjects" then return { captures = { "function.outer" } } end
          return {}
        end
        vim.fn.executable = function(program)
          if program == "tree-sitter" then return 1 end
          return original_executable(program)
        end
        package.loaded["nvim-treesitter"] = {
          get_installed = function() return { "lua" } end,
          get_available = function() return { "lua" } end,
          install = function() error "parser installation is outside this mapping ownership test" end,
        }
        package.loaded["nvim-treesitter-textobjects"] = {}
        package.loaded["nvim-treesitter-textobjects.select"] = { select_outer = function() end }

        local treesitter = require "astrocore.treesitter"
        treesitter.setup {
          enabled = true,
          highlight = false,
          indent = false,
          textobjects = {
            select = {
              select_outer = {
                aa = { query = "@function.outer", group = "textobjects", desc = "Select function" },
              },
            },
          },
        }

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.bo[bufnr].filetype = "lua"
        vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
        local foreign_rhs = "<Plug>(AstroCoreForeign)"
        vim.keymap.set("x", "bb", foreign_rhs, { buffer = bufnr, remap = true })
        vim.keymap.set("o", "bb", foreign_rhs, { buffer = bufnr, remap = true })

        local function mapping(mode, lhs)
          for _, candidate in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
            if candidate.lhs == lhs then
              return { lhs = candidate.lhs, rhs = candidate.rhs, callback_nil = candidate.callback == nil }
            end
          end
        end
        local before = {
          owned_x = mapping("x", "aa"),
          owned_o = mapping("o", "aa"),
          foreign_x = mapping("x", "bb"),
          foreign_o = mapping("o", "bb"),
        }
        treesitter.disable(bufnr)
        local after = {
          owned_x = mapping("x", "aa"),
          owned_o = mapping("o", "aa"),
          foreign_x = mapping("x", "bb"),
          foreign_o = mapping("o", "bb"),
        }

        vim.treesitter.language.get_lang = original_language
        vim.treesitter.query.get = original_query
        vim.fn.executable = original_executable
        return { before = before, after = after, foreign_rhs = foreign_rhs }
      end)()
    ]]

    MiniTest.expect.equality(result.before.owned_x.callback_nil, false)
    MiniTest.expect.equality(result.before.owned_o.callback_nil, false)
    MiniTest.expect.equality(result.before.foreign_x, { lhs = "bb", rhs = result.foreign_rhs, callback_nil = true })
    MiniTest.expect.equality(result.before.foreign_o, { lhs = "bb", rhs = result.foreign_rhs, callback_nil = true })
    MiniTest.expect.equality(result.after.owned_x, nil)
    MiniTest.expect.equality(result.after.owned_o, nil)
    MiniTest.expect.equality(result.after.foreign_x, result.before.foreign_x)
    MiniTest.expect.equality(result.after.foreign_o, result.before.foreign_o)
  end)
end

return T
