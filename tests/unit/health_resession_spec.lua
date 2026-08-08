local MiniTest = require "mini.test"
local helpers = require "unit_helpers"

local T = MiniTest.new_set()

local function contains(text, fragment) return text:find(fragment, 1, true) ~= nil end

T["AC-HLTH-001 reports ok when normalized mappings do not conflict"] = function()
  local calls = { ok = {}, warn = {} }
  helpers.with_module("astrocore.health", {
    replace_vim = { health = true },
    loaded = { astrocore = { config = { mappings = { n = { ["<Leader>a"] = "leader", ["<C-a>"] = "control" } } } } },
    vim = {
      api = { nvim_replace_termcodes = function(lhs) return lhs:lower() end },
      health = {
        start = function() end,
        ok = function(message) table.insert(calls.ok, message) end,
        warn = function(message, advice) table.insert(calls.warn, { message = message, advice = advice }) end,
      },
    },
  }, function(health) health.check() end)

  MiniTest.expect.equality(calls.warn, {})
  MiniTest.expect.equality(#calls.ok, 1)
  MiniTest.expect.equality(type(calls.ok[1]), "string")
end

T["AC-HLTH-002 warns with conflicting mode and mapping facts while ignoring false mappings"] = function()
  local calls = { warn = {} }
  helpers.with_module("astrocore.health", {
    replace_vim = { health = true },
    loaded = {
      astrocore = {
        config = {
          mappings = {
            n = {
              ["<leader>a"] = "lower leader",
              ["<Leader>a"] = "upper leader",
              ["<C-b>"] = false,
              ["<c-b>"] = "ignored counterpart",
            },
          },
        },
      },
    },
    vim = {
      api = { nvim_replace_termcodes = function(lhs) return lhs:lower() end },
      health = {
        start = function() end,
        ok = function() end,
        warn = function(message, advice) table.insert(calls.warn, { message = message, advice = advice }) end,
      },
    },
  }, function(health) health.check() end)

  MiniTest.expect.equality(#calls.warn, 1)
  MiniTest.expect.equality(contains(calls.warn[1].message, "mode `n`"), true)
  MiniTest.expect.equality(contains(calls.warn[1].message, "<leader>a: lower leader"), true)
  MiniTest.expect.equality(contains(calls.warn[1].message, "<Leader>a: upper leader"), true)
  MiniTest.expect.equality(contains(calls.warn[1].message, "<C-b>"), false)
  MiniTest.expect.equality(type(calls.warn[1].advice), "string")
end

T["AC-SES-001 saves buffer history, tab membership, names, and the Resession tabpage index"] = function()
  helpers.with_module("resession.extensions.astrocore", {
    replace_vim = { t = true },
    loaded = { ["astrocore.buffer"] = { current_buf = 7, last_buf = 3 } },
    vim = {
      api = {
        nvim_list_tabpages = function() return { 41, 99 } end,
        nvim_buf_get_name = function(bufnr)
          return ({ [3] = "/project/first.lua", [7] = "/project/second.lua", [10] = "/project/third.lua" })[bufnr]
        end,
      },
      t = {
        [41] = { bufs = { 3, 7 } },
        [99] = { bufs = { 7, 10 } },
      },
    },
  }, function(extension)
    local saved = extension.on_save { tabpage = 99 }
    MiniTest.expect.equality(saved, {
      current_buf = 7,
      last_buf = 3,
      tabpage = 2,
      tabs = { { 3, 7 }, { 7, 10 } },
      bufnrs = {
        ["/project/first.lua"] = 3,
        ["/project/second.lua"] = 7,
        ["/project/third.lua"] = 10,
      },
    })
    MiniTest.expect.equality(extension.on_save({}).tabpage, nil)
  end)
end

T["AC-SES-002 restores global tab membership and history while filtering stale buffer numbers"] = function()
  local events = {}
  local buffer_state = {}
  local tab_variables = { [101] = { bufs = {} }, [202] = { bufs = {} } }
  helpers.with_module("resession.extensions.astrocore", {
    replace_vim = { opt = true, t = true },
    loaded = {
      ["astrocore.buffer"] = buffer_state,
      astrocore = { event = function(name) table.insert(events, name) end },
    },
    vim = {
      api = {
        nvim_list_bufs = function() return { 31, 32 } end,
        nvim_buf_get_name = function(bufnr)
          return ({ [31] = "/project/first.lua", [32] = "/project/second.lua" })[bufnr]
        end,
        nvim_list_tabpages = function() return { 101, 202 } end,
      },
      opt = { bufhidden = { get = function() return "hide" end } },
      t = tab_variables,
    },
  }, function(extension)
    extension.on_post_load {
      bufnrs = { ["/project/first.lua"] = 1, ["/project/second.lua"] = 2 },
      tabs = { [1] = { 1, 99, 2 }, [2] = { 2, 98 } },
      current_buf = 1,
      last_buf = 2,
    }

    MiniTest.expect.equality(tab_variables[101].bufs, { 31, 32 })
    MiniTest.expect.equality(tab_variables[202].bufs, { 32 })
    MiniTest.expect.equality(buffer_state.current_buf, 31)
    MiniTest.expect.equality(buffer_state.last_buf, 32)
    MiniTest.expect.equality(events, { "BufsUpdated" })
  end)
end

T["AC-SES-003 restores only the current tab from a tab-scoped Resession payload"] = function()
  local buffer_state = {}
  local tab_variables = {
    bufs = { 999 },
    [101] = { bufs = { 999 } },
    [202] = { bufs = { 444 } },
  }
  helpers.with_module("resession.extensions.astrocore", {
    replace_vim = { opt = true, t = true },
    loaded = {
      ["astrocore.buffer"] = buffer_state,
      astrocore = { event = function() end },
    },
    vim = {
      api = {
        nvim_list_bufs = function() return { 31, 32 } end,
        nvim_buf_get_name = function(bufnr)
          return ({ [31] = "/project/first.lua", [32] = "/project/second.lua" })[bufnr]
        end,
        nvim_list_tabpages = function() return { 101, 202 } end,
      },
      opt = { bufhidden = { get = function() return "hide" end } },
      t = tab_variables,
    },
  }, function(extension)
    extension.on_post_load {
      bufnrs = { ["/project/first.lua"] = 1, ["/project/second.lua"] = 2 },
      tabs = { [1] = { 1 }, [2] = { 2, 99, 1 } },
      tabpage = 2,
      current_buf = 2,
      last_buf = 1,
    }

    MiniTest.expect.equality(tab_variables.bufs, { 32, 31 })
    MiniTest.expect.equality(tab_variables[202].bufs, { 444 })
    MiniTest.expect.equality(buffer_state.current_buf, 32)
    MiniTest.expect.equality(buffer_state.last_buf, 31)
  end)
end

T["AC-SES-004 selects the remapped current buffer in wipe mode only when needed"] = function()
  local selected, current = {}, 31
  helpers.with_module("resession.extensions.astrocore", {
    replace_vim = { cmd = true, fn = true, opt = true, t = true },
    loaded = {
      ["astrocore.buffer"] = {},
      astrocore = { event = function() end },
    },
    vim = {
      api = {
        nvim_list_bufs = function() return { 31 } end,
        nvim_buf_get_name = function() return "/project/first.lua" end,
        nvim_list_tabpages = function() return { 101 } end,
      },
      cmd = { b = function(bufnr) table.insert(selected, bufnr) end },
      fn = { bufnr = function() return current end },
      opt = { bufhidden = { get = function() return "wipe" end } },
      t = { [101] = { bufs = {} } },
    },
  }, function(extension)
    local data = {
      bufnrs = { ["/project/first.lua"] = 1 },
      tabs = { [1] = { 1 } },
      current_buf = 1,
    }
    extension.on_post_load(data)
    current = 99
    extension.on_post_load(data)

    MiniTest.expect.equality(selected, { 31 })
  end)
end

return T
