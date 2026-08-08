local MiniTest = require "mini.test"
local helpers = require "unit_helpers"

local T = MiniTest.new_set()

local function with_toggles(config, options, callback)
  options = options or {}
  local notifications = options.notifications or {}
  local astrocore = {
    config = config,
    notify = options.notify or function(message, level, notify_options, force)
      table.insert(notifications, { message, level, notify_options, force })
    end,
    set_url_match = options.set_url_match or function() end,
  }
  local loaded = { astrocore = astrocore }
  for module_name, module in pairs(options.loaded or {}) do
    loaded[module_name] = module
  end
  helpers.with_module("astrocore.toggles", {
    loaded = loaded,
    vim = options.vim,
    replace_vim = vim.tbl_extend("force", {
      b = true,
      bo = true,
      go = true,
      lsp = true,
      opt = true,
      w = true,
      wo = true,
    }, options.replace_vim or {}),
  }, function(toggles) callback(toggles, notifications) end)
end

T["AC-TGL-001 toggles rooter state and forces the notification when disabling notifications"] = function()
  local config = { rooter = { autochdir = true }, features = { notifications = false } }
  with_toggles(config, nil, function(toggles, notifications)
    toggles.autochdir(true)
    MiniTest.expect.equality(config.rooter.autochdir, false)

    toggles.notifications()
    MiniTest.expect.equality(config.features.notifications, true)
    MiniTest.expect.equality(notifications[1], { "Notifications on", nil, nil, false })

    toggles.notifications()
    MiniTest.expect.equality(config.features.notifications, false)
    MiniTest.expect.equality(notifications[2], { "Notifications off", nil, nil, true })
  end)
end

T["AC-TGL-002 hands autopairs state transitions to its public dependency API"] = function()
  local config = { features = { autopairs = true } }
  local autopairs = { state = { disabled = false } }
  local calls = {}
  function autopairs.enable()
    table.insert(calls, "enable")
    autopairs.state.disabled = false
  end
  function autopairs.disable()
    table.insert(calls, "disable")
    autopairs.state.disabled = true
  end

  with_toggles(config, { loaded = { ["nvim-autopairs"] = autopairs } }, function(toggles)
    toggles.autopairs(true)
    MiniTest.expect.equality(calls, { "disable" })
    MiniTest.expect.equality(config.features.autopairs, false)

    toggles.autopairs(true)
    MiniTest.expect.equality(calls, { "disable", "enable" })
    MiniTest.expect.equality(config.features.autopairs, true)
  end)
end

T["AC-TGL-003 preserves global and buffer completion state with cmp available"] = function()
  local config = { features = { cmp = true } }
  local buffers = { [7] = {}, [8] = {} }
  with_toggles(config, {
    loaded = { cmp = {} },
    vim = {
      b = buffers,
      api = { nvim_win_get_buf = function() return 8 end },
    },
  }, function(toggles)
    toggles.cmp(true)
    MiniTest.expect.equality(config.features.cmp, false)
    toggles.cmp(true)
    MiniTest.expect.equality(config.features.cmp, true)

    toggles.buffer_cmp(7, true)
    MiniTest.expect.equality(buffers[7].completion, false)
    toggles.buffer_cmp(7, true)
    MiniTest.expect.equality(buffers[7].completion, true)

    toggles.buffer_cmp(0, true)
    MiniTest.expect.equality(buffers[8].completion, false)
  end)
end

T["AC-TGL-005A changes indent options only for valid input"] = function()
  local config = { features = { notifications = true } }
  local buffer_options = { expandtab = false, tabstop = 8, softtabstop = 8, shiftwidth = 8 }
  local input = "3"
  with_toggles(config, {
    vim = {
      bo = buffer_options,
      fn = { input = function() return input end },
    },
  }, function(toggles)
    toggles.indent(true)
    MiniTest.expect.equality(buffer_options, { expandtab = true, tabstop = 3, softtabstop = 3, shiftwidth = 3 })

    input = "-2"
    toggles.indent(true)
    MiniTest.expect.equality(buffer_options, { expandtab = false, tabstop = 2, softtabstop = 2, shiftwidth = 2 })

    input = "0"
    toggles.indent(true)
    input = "invalid"
    toggles.indent(true)
    MiniTest.expect.equality(buffer_options, { expandtab = false, tabstop = 2, softtabstop = 2, shiftwidth = 2 })
  end)
end

T["AC-TGL-005B leaves indent options unchanged when input fails"] = function()
  local config = { features = { notifications = true } }
  local buffer_options = { expandtab = false, tabstop = 8, softtabstop = 8, shiftwidth = 8 }
  with_toggles(config, {
    vim = {
      bo = buffer_options,
      fn = {
        input = function() error "input failed" end,
      },
    },
  }, function(toggles)
    toggles.indent(true)
    MiniTest.expect.equality(buffer_options, { expandtab = false, tabstop = 8, softtabstop = 8, shiftwidth = 8 })
  end)
end

local function syntax_case(native_api)
  local config = { features = { notifications = true } }
  local buffer = 7
  local buffers = {
    [buffer] = { semantic_tokens = true },
  }
  local buffer_options = {
    [buffer] = { syntax = "lua", filetype = "lua" },
  }
  local treesitter_calls, lsp_calls, semantic_filters = {}, {}, {}
  local semantic_enabled = true
  local lsp_toggle = {
    buffer_semantic_tokens = function(bufnr, silent)
      table.insert(lsp_calls, { bufnr, silent })
      if native_api then
        semantic_enabled = not semantic_enabled
      else
        buffers[bufnr].semantic_tokens = not buffers[bufnr].semantic_tokens
      end
    end,
  }
  local semantic_tokens = {}
  if native_api then
    semantic_tokens.enable = function() end
    semantic_tokens.is_enabled = function(filter)
      table.insert(semantic_filters, filter)
      return semantic_enabled
    end
  end

  with_toggles(config, {
    loaded = {
      ["astrocore.treesitter"] = {
        has_parser = function(bufnr)
          MiniTest.expect.equality(bufnr, buffer)
          return true
        end,
        disable = function(bufnr) table.insert(treesitter_calls, { "disable", bufnr }) end,
        enable = function(bufnr) table.insert(treesitter_calls, { "enable", bufnr }) end,
      },
      ["astrolsp.toggles"] = lsp_toggle,
    },
    replace_vim = { lsp = true },
    vim = {
      b = buffers,
      bo = buffer_options,
      api = { nvim_get_current_buf = function() return buffer end },
      lsp = { semantic_tokens = semantic_tokens },
    },
  }, function(toggles)
    toggles.buffer_syntax(buffer, true)
    MiniTest.expect.equality(buffer_options[buffer].syntax, "off")
    MiniTest.expect.equality(buffers[buffer].astrocore_syntax, "lua")
    MiniTest.expect.equality(buffers[buffer].astrocore_semantic_tokens_disabled, true)

    toggles.buffer_syntax(buffer, true)
    MiniTest.expect.equality(buffer_options[buffer].syntax, "lua")
    MiniTest.expect.equality(buffers[buffer].astrocore_syntax, nil)
    MiniTest.expect.equality(buffers[buffer].astrocore_semantic_tokens_disabled, nil)
    MiniTest.expect.equality(treesitter_calls, { { "disable", buffer }, { "enable", buffer } })
    MiniTest.expect.equality(lsp_calls, { { buffer, true }, { buffer, true } })
    if native_api then
      MiniTest.expect.equality(semantic_filters, { { bufnr = buffer }, { bufnr = buffer } })
    else
      MiniTest.expect.equality(buffers[buffer].semantic_tokens, true)
    end
  end)
end

T["AC-TGL-006A restores syntax, Treesitter, and semantic tokens on Neovim 0.11"] = function() syntax_case(false) end

T["AC-TGL-006B restores syntax, Treesitter, and semantic tokens on Neovim 0.12"] = function() syntax_case(true) end

T["AC-TGL-007 updates URL matching for every window"] = function()
  local config = { features = { highlighturl = true } }
  local windows = {}
  with_toggles(config, {
    set_url_match = function(win) table.insert(windows, win) end,
    vim = {
      api = { nvim_list_wins = function() return { 3, 4, 8 } end },
    },
  }, function(toggles)
    toggles.url_match(true)
    MiniTest.expect.equality(config.features.highlighturl, false)
    MiniTest.expect.equality(windows, { 3, 4, 8 })
  end)
end

T["AC-TGL-009 restores diagnostic enablement and configured virtual display values"] = function()
  local config = { features = { notifications = true } }
  local diagnostic = {
    enabled = true,
    options = {
      virtual_text = { prefix = "*" },
      virtual_lines = true,
    },
  }
  local configured = {}
  with_toggles(config, {
    vim = {
      diagnostic = {
        enable = function(enabled) diagnostic.enabled = enabled end,
        is_enabled = function() return diagnostic.enabled end,
        config = function(options)
          if options then
            table.insert(configured, options)
            for key, value in pairs(options) do
              diagnostic.options[key] = value
            end
          end
          return diagnostic.options
        end,
      },
    },
  }, function(toggles)
    toggles.diagnostics(true)
    MiniTest.expect.equality(diagnostic.enabled, false)
    toggles.diagnostics(true)
    MiniTest.expect.equality(diagnostic.enabled, true)

    toggles.virtual_text(true)
    MiniTest.expect.equality(diagnostic.options.virtual_text, false)
    toggles.virtual_text(true)
    MiniTest.expect.equality(diagnostic.options.virtual_text, { prefix = "*" })

    toggles.virtual_lines(true)
    MiniTest.expect.equality(diagnostic.options.virtual_lines, false)
    toggles.virtual_lines(true)
    MiniTest.expect.equality(diagnostic.options.virtual_lines, true)
    MiniTest.expect.equality(#configured, 4)
  end)
end

return T
