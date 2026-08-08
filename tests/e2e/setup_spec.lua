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

T["AC-CORE-028 and AC-INT-001 keep one owned setup lifecycle with working commands, mappings, and on-key callbacks"] = function()
  with_child(function(child)
    local result = child.lua_get [[
      (function()
        local core = require "astrocore"
        local autocmds, commands, mappings, keys = 0, 0, 0, 0
        local options = {
          autocmds = {
            AstroCoreRepeatedSetupCoverage = {
              {
                event = "User",
                pattern = "AstroCoreRepeatedSetupCoverage",
                callback = function() autocmds = autocmds + 1 end,
              },
            },
          },
          commands = {
            AstroCoreRepeatedSetupCoverage = {
              function() commands = commands + 1 end,
              desc = "AstroCore repeated setup coverage",
            },
          },
          mappings = {
            n = {
              ["<F24>"] = { function() mappings = mappings + 1 end, desc = "AstroCore setup mapping" },
            },
          },
          on_keys = {
            astrocore_repeated_setup_coverage = {
              function(key)
                if key == vim.keycode "<F25>" then keys = keys + 1 end
              end,
            },
          },
          features = { diagnostics = false },
          rooter = false,
          treesitter = false,
        }

        core.setup(options)
        core.setup(options)
        vim.api.nvim_exec_autocmds("User", { pattern = "AstroCoreRepeatedSetupCoverage", modeline = false })
        vim.cmd.AstroCoreRepeatedSetupCoverage()
        vim.api.nvim_feedkeys(vim.keycode "<F24>", "xt", false)
        vim.api.nvim_feedkeys(vim.keycode "<F25>", "xt", false)
        assert(vim.wait(1000, function() return mappings == 1 and keys == 1 end))

        return {
          autocmds = autocmds,
          commands = commands,
          mappings = mappings,
          keys = keys,
          mapping_exists = vim.fn.maparg("<F24>", "n") ~= "",
        }
      end)()
    ]]

    MiniTest.expect.equality(result.autocmds, 1)
    MiniTest.expect.equality(result.commands, 1)
    MiniTest.expect.equality(result.mappings, 1)
    MiniTest.expect.equality(result.keys, 1)
    MiniTest.expect.equality(result.mapping_exists, true)
  end)
end

return T
