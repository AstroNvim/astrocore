local MiniTest = require "mini.test"
local helpers = require "unit_helpers"

local T = MiniTest.new_set()

local function with_treesitter(options, callback)
  options = options or {}
  local state = {
    current = options.current or 7,
    valid = options.valid or { [7] = true, [8] = true },
    buffer_options = options.buffer_options or {
      [7] = { filetype = "lua", buftype = "", indentexpr = "manual" },
      [8] = { filetype = "lua", buftype = "", indentexpr = "manual" },
    },
    groups = {},
    autocmds = {},
    maps = {},
    starts = {},
    stops = {},
    commands = {},
    installed = options.installed or { "lua" },
    available = options.available or { "lua", "vim" },
    installed_calls = {},
    available_calls = 0,
    install_calls = {},
    notifications = {},
  }
  local function buffer_options(bufnr)
    bufnr = bufnr == 0 and state.current or bufnr
    state.buffer_options[bufnr] = state.buffer_options[bufnr] or { filetype = "", buftype = "", indentexpr = "" }
    return state.buffer_options[bufnr]
  end
  local bo = setmetatable({}, { __index = function(_, bufnr) return buffer_options(bufnr) end })
  local function maps(bufnr, mode)
    state.maps[bufnr] = state.maps[bufnr] or {}
    state.maps[bufnr][mode] = state.maps[bufnr][mode] or {}
    return state.maps[bufnr][mode]
  end
  local function autocmd(event)
    for index = #state.autocmds, 1, -1 do
      local entry = state.autocmds[index]
      if entry.event == event or vim.tbl_contains(entry.event, event) then return entry.options.callback end
    end
  end
  state.autocmd = autocmd

  local treesitter_api = options.nvim_treesitter
    or {
      get_installed = function(kind)
        table.insert(state.installed_calls, kind)
        return state.installed
      end,
      get_available = function()
        state.available_calls = state.available_calls + 1
        return state.available
      end,
      install = function(languages, install_options)
        table.insert(state.install_calls, { languages = vim.deepcopy(languages), options = install_options })
        return {
          await = function(_, done)
            state.installed = vim.list_extend(state.installed, vim.deepcopy(languages))
            done()
          end,
        }
      end,
    }
  local loaded = {
    astrocore = {
      extend_tbl = function(_, values) return values end,
      patch_func = function(original, patch)
        return function(...)
          return patch(original or function() end, ...)
        end
      end,
      on_load = function(_, on_load_callback) state.on_load = on_load_callback end,
      notify = function(message, level) table.insert(state.notifications, { message, level }) end,
    },
    ["nvim-treesitter"] = treesitter_api,
  }
  for name, module in pairs(options.loaded or {}) do
    loaded[name] = module
  end

  helpers.with_module("astrocore.treesitter", {
    loaded = loaded,
    vim = {
      api = {
        nvim_get_current_buf = function() return state.current end,
        nvim_buf_is_valid = function(bufnr) return state.valid[bufnr] == true end,
        nvim_create_augroup = function(name, group_options)
          table.insert(state.groups, { name, group_options })
          return #state.groups
        end,
        nvim_create_autocmd = function(event, autocmd_options)
          table.insert(state.autocmds, { event = event, options = autocmd_options })
        end,
        nvim_buf_get_keymap = function(bufnr, mode) return vim.deepcopy(maps(bufnr, mode)) end,
        nvim_buf_del_keymap = function(bufnr, mode, lhs)
          for index, mapping in ipairs(maps(bufnr, mode)) do
            if mapping.lhs == lhs then
              table.remove(state.maps[bufnr][mode], index)
              return
            end
          end
        end,
      },
      bo = bo,
      cmd = function(command) table.insert(state.commands, command) end,
      fn = {
        executable = options.executable or function() return 1 end,
        keytrans = function(key) return key end,
      },
      keymap = {
        set = function(mode, lhs, map_callback, map_options)
          table.insert(maps(map_options.buffer, mode), { lhs = lhs, callback = map_callback, options = map_options })
        end,
      },
      nvim_replace_termcodes = function(key) return key end,
      schedule_wrap = function(wrapped) return wrapped end,
      treesitter = {
        language = {
          get_lang = options.get_lang
            or function(filetype) return ({ lua = "lua", vim = "vim", query = "query" })[filetype] end,
        },
        query = {
          get = options.get_query or function(_, query)
            if query == "highlights" or query == "indents" or query == "folds" then return {} end
            if query == "textobjects" then return { captures = { "function.outer" } } end
          end,
        },
        start = function(bufnr) table.insert(state.starts, bufnr) end,
        stop = function(bufnr) table.insert(state.stops, bufnr) end,
      },
    },
    replace_vim = { bo = true, cmd = true, fn = true, keymap = true, treesitter = true },
  }, function(treesitter, context) callback(treesitter, state, context) end)
end

T["AC-TS-001 caches installed and available parser lists at their public refresh boundaries"] = function()
  with_treesitter({ installed = { "lua" }, available = { "lua", "vim" } }, function(treesitter, state)
    MiniTest.expect.equality(treesitter.installed(), {})
    MiniTest.expect.equality(treesitter.installed(true), { lua = true })
    MiniTest.expect.equality(treesitter.installed(), { lua = true })
    MiniTest.expect.equality(state.installed_calls, { "parsers" })

    MiniTest.expect.equality(treesitter.available(), { lua = true, vim = true })
    MiniTest.expect.equality(treesitter.available(), { lua = true, vim = true })
    MiniTest.expect.equality(state.available_calls, 1)

    treesitter.setup { enabled = true }
    state.available = { "lua", "query" }
    state.on_load()
    MiniTest.expect.equality(state.installed_calls, { "parsers", "parsers" })
    MiniTest.expect.equality(treesitter.available(), { lua = true, query = true })
    MiniTest.expect.equality(state.available_calls, 2)
  end)
end

T["AC-TS-002 memoizes query and capture results by language and query until installed refresh"] = function()
  local calls = {}
  with_treesitter({
    get_query = function(language, query)
      table.insert(calls, { language, query })
      if query == "highlights" then return { captures = { "function.outer" } } end
    end,
  }, function(treesitter)
    MiniTest.expect.equality(treesitter.has_query("lua", "highlights"), true)
    MiniTest.expect.equality(treesitter.has_query("lua", "highlights"), true)
    MiniTest.expect.equality(treesitter.has_query("lua", "indents"), false)
    MiniTest.expect.equality(treesitter.has_query("lua", "indents"), false)
    MiniTest.expect.equality(treesitter.has_capture("lua", "highlights", "function.outer"), true)
    MiniTest.expect.equality(treesitter.has_capture("lua", "highlights", "missing"), false)
    MiniTest.expect.equality(calls, { { "lua", "highlights" }, { "lua", "indents" }, { "lua", "highlights" } })

    treesitter.installed(true)
    MiniTest.expect.equality(treesitter.has_query("lua", "highlights"), true)
    MiniTest.expect.equality(treesitter.has_capture("lua", "highlights", "function.outer"), true)
    MiniTest.expect.equality(calls, {
      { "lua", "highlights" },
      { "lua", "indents" },
      { "lua", "highlights" },
      { "lua", "highlights" },
      { "lua", "highlights" },
    })
  end)
end

T["AC-TS-003 resolves parser support from string filetypes and buffer filetypes"] = function()
  with_treesitter({
    buffer_options = { [7] = { filetype = "lua", buftype = "", indentexpr = "" } },
  }, function(treesitter)
    treesitter.installed(true)
    MiniTest.expect.equality(treesitter.has_parser "lua", true)
    MiniTest.expect.equality(treesitter.has_parser(7, "highlights"), true)
    MiniTest.expect.equality(treesitter.has_parser "vim", false)
    MiniTest.expect.equality(treesitter.has_parser(7, "missing"), false)
  end)
end

T["AC-TS-004 installs normalized parser requests through the public async API"] = function()
  with_treesitter({ installed = { "vim" }, available = { "lua", "vim", "query" } }, function(treesitter, state)
    local callbacks = 0
    treesitter.installed(true)
    treesitter.install("auto", function() callbacks = callbacks + 1 end)
    treesitter.install("all", function() callbacks = callbacks + 1 end)
    treesitter.install({ "lua", "vim", "query" }, function() callbacks = callbacks + 1 end)

    MiniTest.expect.equality(state.install_calls, {
      { languages = { "lua" }, options = { summary = true } },
      { languages = { "query" }, options = { summary = true } },
    })
    MiniTest.expect.equality(callbacks, 2)
    MiniTest.expect.equality(state.installed_calls, { "parsers", "parsers", "parsers" })
  end)
end

T["AC-TS-005 handles existing CLI, Mason package, install outcome, and missing CLI setup branches"] = function()
  with_treesitter(nil, function(treesitter, state)
    treesitter.setup { enabled = true }
    MiniTest.expect.equality(#state.groups, 1)
    MiniTest.expect.equality(state.notifications, {})
  end)

  local function mason_case(installed, success)
    local package = {
      is_installed = function() return installed end,
      install = function(_, _, callback) callback(success) end,
    }
    with_treesitter({
      executable = function() return 0 end,
      loaded = {
        mason = {},
        ["mason-registry"] = {
          refresh = function(callback) callback() end,
          get_package = function() return package end,
        },
      },
    }, function(treesitter, state)
      treesitter.setup { enabled = true }
      if installed then
        MiniTest.expect.equality(#state.groups, 0)
        MiniTest.expect.equality(state.notifications, {})
      elseif success then
        MiniTest.expect.equality(#state.groups, 1)
        MiniTest.expect.equality(state.notifications, {
          { "Installing `tree-sitter-cli` with `mason.nvim`...", nil },
          { "Installed `tree-sitter-cli` with `mason.nvim`.", nil },
        })
      else
        MiniTest.expect.equality(#state.groups, 0)
        MiniTest.expect.equality(state.notifications, {
          { "Installing `tree-sitter-cli` with `mason.nvim`...", nil },
          {
            "Failed to install `tree-sitter-cli` with `mason.nvim\n\nCheck `:Mason` UI for details.",
            vim.log.levels.ERROR,
          },
        })
      end
    end)
  end

  mason_case(true, true)
  mason_case(false, true)
  mason_case(false, false)

  with_treesitter({
    executable = function() return 0 end,
    loaded = { mason = helpers.remove },
  }, function(treesitter, state)
    treesitter.setup { enabled = true }
    MiniTest.expect.equality(state.notifications, {
      {
        "`tree-sitter` CLI is required for using `nvim-treesitter`\n\nInstall to enable treesitter features.",
        vim.log.levels.WARN,
      },
    })
  end)
end

T["AC-TS-006 replaces the owned autocmd group across repeated successful setup"] = function()
  with_treesitter(nil, function(treesitter, state)
    treesitter.setup { enabled = true }
    treesitter.setup { enabled = false }

    MiniTest.expect.equality(state.groups, {
      { "astrocore_treesitter", { clear = true } },
      { "astrocore_treesitter", { clear = true } },
    })
    MiniTest.expect.equality(#state.autocmds, 4)
    MiniTest.expect.equality(state.autocmds[3].event, "FileType")
    MiniTest.expect.equality(state.autocmds[4].event, { "BufDelete", "BufWipeout" })
    state.autocmd "FileType" { buf = 7 }
    MiniTest.expect.equality(treesitter.is_enabled(7), false)
  end)
end

T["AC-TS-007 reconciles rejected, unsupported, installable, invalid, and re-enabled buffers"] = function()
  with_treesitter({
    installed = {},
    available = { "lua" },
    valid = { [7] = true, [8] = false, [10] = true },
    buffer_options = {
      [7] = { filetype = "lua", buftype = "", indentexpr = "" },
      [8] = { filetype = "lua", buftype = "", indentexpr = "" },
      [9] = { filetype = "unknown", buftype = "", indentexpr = "" },
      [10] = { filetype = "lua", buftype = "", indentexpr = "" },
    },
  }, function(treesitter, state)
    local enabled, installs = {}, {}
    treesitter.setup {
      enabled = function(_, bufnr) return bufnr ~= 10 end,
      auto_install = true,
    }
    local filetype = state.autocmd "FileType"
    treesitter.enable = function(bufnr) table.insert(enabled, bufnr) end
    treesitter.install = function(languages, callback)
      table.insert(installs, languages)
      callback()
    end

    filetype { buf = 9 }
    filetype { buf = 10 }
    filetype { buf = 7 }
    filetype { buf = 8 }
    MiniTest.expect.equality(treesitter.is_enabled(9), false)
    MiniTest.expect.equality(treesitter.is_enabled(10), false)
    MiniTest.expect.equality(installs, { { "lua" }, { "lua" } })
    MiniTest.expect.equality(enabled, {})

    treesitter.has_parser = function(bufnr) return bufnr == 7 end
    filetype { buf = 7 }
    MiniTest.expect.equality(enabled, { 7 })
  end)
end

T["AC-TS-008 AC-TS-009 and AC-TS-010 own enabled feature state and matching textobject mappings"] = function()
  local textobject_calls = {}
  with_treesitter({
    loaded = {
      ["nvim-treesitter-textobjects"] = {},
      ["nvim-treesitter-textobjects.select"] = {
        select_outer = function(query, group) table.insert(textobject_calls, { query, group }) end,
      },
    },
  }, function(treesitter, state, context)
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
    state.autocmd "FileType" { buf = 7 }

    MiniTest.expect.equality(treesitter.is_enabled(7), true)
    MiniTest.expect.equality(state.starts, { 7 })
    MiniTest.expect.equality(state.buffer_options[7].indentexpr, "v:lua.require'nvim-treesitter'.indentexpr()")
    MiniTest.expect.equality(#state.maps[7].x, 1)
    MiniTest.expect.equality(#state.maps[7].o, 1)
    state.maps[7].x[1].callback()
    MiniTest.expect.equality(textobject_calls, { { "@function.outer", "textobjects" } })

    treesitter.disable(7)
    context.drain_scheduled()
    MiniTest.expect.equality(treesitter.is_enabled(7), false)
    MiniTest.expect.equality(state.stops, { 7 })
    MiniTest.expect.equality(state.buffer_options[7].indentexpr, "manual")
    MiniTest.expect.equality(state.maps[7].x, {})
    MiniTest.expect.equality(state.maps[7].o, {})
    MiniTest.expect.equality(state.commands, { "normal! zx" })

    state.current = 8
    state.buffer_options[8].buftype = "terminal"
    state.autocmd "FileType" { buf = 8 }
    treesitter.disable(8)
    context.drain_scheduled()
    MiniTest.expect.equality(state.commands, { "normal! zx" })

    state.autocmd "BufDelete" { buf = 7 }
    state.autocmd "BufWipeout" { buf = 7 }
    MiniTest.expect.equality(treesitter.is_enabled(7), false)
  end)
end

return T
