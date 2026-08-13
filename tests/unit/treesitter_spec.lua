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
    preload = options.preload,
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

T["AC-TS-004 delays Task await completion and refreshes before normalized callbacks"] = function()
  local events, parsers, requests, task_callbacks = {}, { "vim" }, {}, {}
  with_treesitter({
    available = { "lua", "vim", "query" },
    nvim_treesitter = {
      get_installed = function()
        table.insert(events, "refresh")
        return parsers
      end,
      get_available = function() return { "lua", "vim", "query" } end,
      install = function(languages, options)
        table.insert(requests, { languages = languages, options = options })
        table.insert(events, "install")
        return {
          await = function(_, callback)
            table.insert(task_callbacks, callback)
            vim.schedule(function() table.insert(events, "await barrier") end)
          end,
        }
      end,
    },
  }, function(treesitter, _, context)
    local callbacks = 0
    treesitter.installed(true)
    treesitter.install("auto", function()
      callbacks = callbacks + 1
      table.insert(events, "auto callback")
    end)
    context.drain_scheduled()

    MiniTest.expect.equality(requests, { { languages = { "lua" }, options = { summary = true } } })
    MiniTest.expect.equality(events, { "refresh", "install", "await barrier" })
    MiniTest.expect.equality(callbacks, 0)

    table.insert(parsers, "lua")
    local complete_auto = assert(task_callbacks[1], "Expected a delayed automatic parser installation")
    complete_auto()
    MiniTest.expect.equality(events, { "refresh", "install", "await barrier", "refresh", "auto callback" })
    MiniTest.expect.equality(callbacks, 1)

    treesitter.install("all", function()
      callbacks = callbacks + 1
      table.insert(events, "all callback")
    end)
    context.drain_scheduled()
    MiniTest.expect.equality(requests, {
      { languages = { "lua" }, options = { summary = true } },
      { languages = { "query" }, options = { summary = true } },
    })
    MiniTest.expect.equality(callbacks, 1)

    table.insert(parsers, "query")
    local complete_all = assert(task_callbacks[2], "Expected a delayed all-parser installation")
    complete_all()
    MiniTest.expect.equality(events, {
      "refresh",
      "install",
      "await barrier",
      "refresh",
      "auto callback",
      "install",
      "await barrier",
      "refresh",
      "all callback",
    })
    MiniTest.expect.equality(callbacks, 2)
  end)
end

T["AC-TS-005 resolves CLI installation outcomes before setup and parser installation"] = function()
  with_treesitter(nil, function(treesitter, state)
    treesitter.setup { enabled = true }
    MiniTest.expect.equality(#state.groups, 1)
    MiniTest.expect.equality(state.notifications, {})
  end)

  local function mason_case(installed, success)
    local cli_available, events, refresh_callback, install_callback = false, {}, nil, nil
    local package = {
      is_installed = function() return installed end,
      install = function(_, _, callback)
        install_callback = callback
        vim.schedule(function() table.insert(events, "install barrier") end)
      end,
    }
    with_treesitter({
      executable = function() return cli_available and 1 or 0 end,
      loaded = {
        mason = {},
        ["mason-registry"] = {
          refresh = function(callback)
            refresh_callback = callback
            vim.schedule(function() table.insert(events, "refresh barrier") end)
          end,
          get_package = function() return package end,
        },
      },
    }, function(treesitter, state, context)
      treesitter.setup { enabled = true, auto_install_cli = true, ensure_installed = { "vim" } }
      context.drain_scheduled()
      MiniTest.expect.equality(events, { "refresh barrier" })
      MiniTest.expect.equality(#state.groups, 0)
      MiniTest.expect.equality(state.notifications, {})

      local pending_callbacks = 0
      treesitter.install({ "vim" }, function() pending_callbacks = pending_callbacks + 1 end)
      MiniTest.expect.equality(state.install_calls, {})
      MiniTest.expect.equality(pending_callbacks, 0)

      local complete_refresh = assert(refresh_callback, "Expected Mason to finish refreshing")
      complete_refresh()
      if installed then
        MiniTest.expect.equality(#state.groups, 1)
        MiniTest.expect.equality(state.notifications, {})
      else
        context.drain_scheduled()
        MiniTest.expect.equality(#state.groups, 0)
        MiniTest.expect.equality(events, { "refresh barrier", "install barrier" })
        MiniTest.expect.equality(state.notifications, { { "Installing `tree-sitter-cli` with `mason.nvim`...", nil } })

        local complete_install = assert(install_callback, "Expected Mason to finish installing")
        cli_available = success
        complete_install(success)
      end

      MiniTest.expect.equality(#state.groups, 1)
      if not installed and success then
        MiniTest.expect.equality(state.notifications, {
          { "Installing `tree-sitter-cli` with `mason.nvim`...", nil },
          { "Installed `tree-sitter-cli` with `mason.nvim`.", nil },
        })
      elseif not installed then
        MiniTest.expect.equality(state.notifications[1], { "Installing `tree-sitter-cli` with `mason.nvim`...", nil })
        MiniTest.expect.equality(
          state.notifications[2][1],
          "Failed to install `tree-sitter-cli` with `mason.nvim\n\nCheck `:Mason` UI for details."
        )
        MiniTest.expect.equality(type(state.notifications[2][2]), "number")
      end

      state.on_load()
      if not installed and success then
        MiniTest.expect.equality(state.install_calls, {
          { languages = { "vim" }, options = { summary = true } },
        })
      else
        MiniTest.expect.equality(state.install_calls, {})
      end
    end)
  end

  mason_case(true, true)
  mason_case(false, true)
  mason_case(false, false)

  local function unavailable_mason_case(auto_install_cli, expected_attempts)
    local mason_attempts, callbacks = 0, 0
    with_treesitter({
      executable = function() return 0 end,
      loaded = { mason = helpers.remove },
      preload = {
        mason = function()
          mason_attempts = mason_attempts + 1
          error "Mason is unavailable"
        end,
      },
    }, function(treesitter, state)
      treesitter.setup {
        enabled = true,
        auto_install_cli = auto_install_cli,
        ensure_installed = { "vim" },
      }
      MiniTest.expect.equality(mason_attempts, expected_attempts)
      MiniTest.expect.equality(#state.groups, 1)
      MiniTest.expect.equality(state.notifications, {})

      state.on_load()
      treesitter.install({ "vim" }, function() callbacks = callbacks + 1 end)
      MiniTest.expect.equality(state.install_calls, {})
      MiniTest.expect.equality(callbacks, 0)
    end)
  end

  unavailable_mason_case(true, 1)
  unavailable_mason_case(false, 0)
end

T["AC-TS-006 configures the owned FileType and cleanup autocmds"] = function()
  with_treesitter(nil, function(treesitter, state)
    treesitter.setup { enabled = true }

    MiniTest.expect.equality(state.groups, {
      { "astrocore_treesitter", { clear = true } },
    })
    MiniTest.expect.equality(#state.autocmds, 2)
    MiniTest.expect.equality(state.autocmds[1].event, "FileType")
    MiniTest.expect.equality(state.autocmds[2].event, { "BufDelete", "BufWipeout" })
    state.autocmd "FileType" { buf = 7 }
    MiniTest.expect.equality(treesitter.is_enabled(7), true)
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

T["AC-TS-012 skips enablement and mappings when a delayed parser install finishes after buffer invalidation"] = function()
  local parsers, task_callback = {}, nil
  with_treesitter({
    available = { "lua" },
    nvim_treesitter = {
      get_installed = function() return parsers end,
      get_available = function() return { "lua" } end,
      install = function(languages)
        return {
          await = function(_, callback)
            task_callback = function()
              for _, language in ipairs(languages) do
                table.insert(parsers, language)
              end
              vim.schedule(callback)
            end
            vim.schedule(function() end)
          end,
        }
      end,
    },
    loaded = {
      ["nvim-treesitter-textobjects"] = {},
      ["nvim-treesitter-textobjects.select"] = { select_outer = function() end },
    },
  }, function(treesitter, state, context)
    treesitter.setup {
      enabled = true,
      auto_install = true,
      highlight = true,
      textobjects = {
        select = {
          select_outer = {
            aa = { query = "@function.outer", group = "textobjects", desc = "Select function" },
          },
        },
      },
    }
    state.autocmd "FileType" { buf = 7 }
    context.drain_scheduled()

    MiniTest.expect.equality(task_callback ~= nil, true)
    local complete_install = assert(task_callback, "Expected a delayed parser installation")
    MiniTest.expect.equality(treesitter.is_enabled(7), false)
    MiniTest.expect.equality(state.starts, {})
    MiniTest.expect.equality(state.maps, {})

    state.valid[7] = false
    complete_install()
    context.drain_scheduled()
    MiniTest.expect.equality(treesitter.is_enabled(7), false)
    MiniTest.expect.equality(state.starts, {})
    MiniTest.expect.equality(state.maps, {})
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

    local foreign_rhs = "<Plug>(AstroCoreForeign)"
    for _, mode in ipairs { "x", "o" } do
      table.insert(state.maps[7][mode], { lhs = "bb", rhs = foreign_rhs })
    end
    local function find_mapping(mode, lhs)
      for _, mapping in ipairs(state.maps[7][mode]) do
        if mapping.lhs == lhs then return mapping end
      end
    end
    MiniTest.expect.equality(find_mapping("x", "bb").callback, nil)
    MiniTest.expect.equality(find_mapping("o", "bb").callback, nil)

    treesitter.disable(7)
    context.drain_scheduled()
    MiniTest.expect.equality(treesitter.is_enabled(7), false)
    MiniTest.expect.equality(state.stops, { 7 })
    MiniTest.expect.equality(state.buffer_options[7].indentexpr, "manual")
    MiniTest.expect.equality(find_mapping("x", "aa"), nil)
    MiniTest.expect.equality(find_mapping("o", "aa"), nil)
    MiniTest.expect.equality(find_mapping("x", "bb"), { lhs = "bb", rhs = foreign_rhs })
    MiniTest.expect.equality(find_mapping("o", "bb"), { lhs = "bb", rhs = foreign_rhs })
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
