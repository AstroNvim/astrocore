local MiniTest = require "mini.test"
local helpers = require "unit_helpers"

local T = MiniTest.new_set()

local function expect_error(callback, text)
  local ok, error_message = pcall(callback)
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(error_message:find(text, 1, true) ~= nil, true)
end

local function setup_boundaries(records)
  return {
    replace_vim = { b = true, bo = true, g = true, opt = true, w = true },
    vim = {
      b = records.buffers or {},
      bo = { filetype = "" },
      opt = {},
      w = records.windows or {},
      g = {},
      api = {
        nvim_create_augroup = function(name, options)
          table.insert(records.augroups, { name, options })
          return #records.augroups
        end,
        nvim_create_autocmd = function(event, options) table.insert(records.autocmds, { event, options }) end,
        nvim_create_user_command = function(name, action, options)
          table.insert(records.commands, { name, action, options })
        end,
        nvim_create_namespace = function(name)
          table.insert(records.namespaces, name)
          return #records.namespaces
        end,
        nvim_list_wins = function() return {} end,
        nvim_set_hl = function(...) table.insert(records.highlights, { ... }) end,
      },
      filetype = { add = function(options) records.filetypes = options end },
      diagnostic = {
        config = function(options)
          if options then
            records.diagnostics = options
            records.diagnostic_config = options
          end
          return records.diagnostic_config or {}
        end,
        enable = function(value) records.diagnostic_enabled = value end,
      },
      fn = {
        sign_define = function(name, options) table.insert(records.signs, { name, options }) end,
      },
      on_key = function(callback, namespace) table.insert(records.on_keys, { callback, namespace }) end,
      keymap = { set = function(...) table.insert(records.keymaps, { ... }) end },
    },
  }
end

T["AC-CFG-001 exposes selected documented defaults"] = function()
  helpers.with_module("astrocore.config", {}, function(config)
    MiniTest.expect.equality(config.features.notifications, true)
    MiniTest.expect.equality(
      config.features.large_buf,
      { notify = true, size = 1.5 * 1024 * 1024, lines = 100000, line_length = 1000 }
    )
    MiniTest.expect.equality(config.sessions.autosave, { last = true, cwd = true })
    MiniTest.expect.equality(config.sessions.ignore.filetypes, { "gitcommit", "gitrebase" })
    MiniTest.expect.equality(config.treesitter, {
      enabled = true,
      highlight = true,
      indent = true,
      ensure_installed = {},
      textobjects = nil,
    })
  end)
end

T["AC-CFG-002 declares only the six supported lazy list extensions"] = function()
  local spec = dofile "lazy.lua"
  MiniTest.expect.equality(spec.opts_extend, {
    "rooter.ignore.servers",
    "rooter.ignore.dirs",
    "sessions.ignore.buftypes",
    "sessions.ignore.dirs",
    "sessions.ignore.filetypes",
    "git_worktrees",
  })
end

T["AC-CFG-003 merges sparse nested options without losing defaults"] = function()
  local records = {
    augroups = {},
    autocmds = {},
    commands = {},
    namespaces = {},
    highlights = {},
    signs = {},
    on_keys = {},
    keymaps = {},
  }
  local options = setup_boundaries(records)
  options.preload = { ["astrocore.treesitter"] = { setup = function() end } }
  helpers.with_module("astrocore", options, function(core)
    core.setup { features = { notifications = false }, rooter = false, treesitter = { highlight = false } }
    MiniTest.expect.equality(core.config.features.notifications, false)
    MiniTest.expect.equality(core.config.features.autopairs, true)
    MiniTest.expect.equality(core.config.sessions.ignore.filetypes, { "gitcommit", "gitrebase" })
    MiniTest.expect.equality(core.config.treesitter.enabled, true)
    MiniTest.expect.equality(core.config.treesitter.highlight, false)
  end)
end

T["AC-CFG-004 restores command and autocmd declaration fields after registration"] = function()
  local records = {
    augroups = {},
    autocmds = {},
    commands = {},
    namespaces = {},
    highlights = {},
    signs = {},
    on_keys = {},
    keymaps = {},
  }
  local options = setup_boundaries(records)
  helpers.with_module("astrocore", options, function(core)
    local autocmd_callback = function() end
    local command_action = function() end
    core.setup {
      autocmds = { TestGroup = { { event = "BufEnter", callback = autocmd_callback } } },
      commands = { TestCommand = { command_action, desc = "test command" } },
      features = { diagnostics = false },
      rooter = false,
      treesitter = false,
    }
    MiniTest.expect.equality(core.config.autocmds.TestGroup[1].event, "BufEnter")
    MiniTest.expect.equality(core.config.autocmds.TestGroup[1].callback, autocmd_callback)
    MiniTest.expect.equality(core.config.commands.TestCommand[1], command_action)
    MiniTest.expect.equality(core.config.commands.TestCommand.desc, "test command")
  end)
end

T["AC-CORE-001 force-merges tables and returns opts without defaults"] = function()
  helpers.with_module("astrocore", {}, function(core)
    MiniTest.expect.equality(
      core.extend_tbl({ nested = { left = true, value = 1 } }, { nested = { value = 2, right = true } }),
      {
        nested = { left = true, value = 2, right = true },
      }
    )
    local opts = { supplied = true }
    MiniTest.expect.equality(core.extend_tbl(nil, opts), opts)
  end)
end

T["AC-CORE-002 preserves list helper order, ownership, and validation"] = function()
  helpers.with_module("astrocore", {}, function(core)
    local destination = { "a", "b" }
    MiniTest.expect.equality(core.list_insert_unique(destination, { "b", "c", "a", "d" }), { "a", "b", "c", "d" })
    local source = { "a", "b", "a", "c" }
    MiniTest.expect.equality(core.unique_list(source), { "a", "b", "c" })
    MiniTest.expect.equality(source, { "a", "b", "a", "c" })
    MiniTest.expect.error(function() core.list_insert_unique({ key = "value" }, {}) end)
    MiniTest.expect.error(function() core.unique_list { key = "value" } end)
  end)
end

T["AC-CORE-003 calls only callable true conditions with forwarded arguments"] = function()
  helpers.with_module("astrocore", {}, function(core)
    local received
    local function callback(...)
      received = { ... }
      return "result"
    end
    MiniTest.expect.equality(core.conditional_func(callback, true, "one", 2), "result")
    MiniTest.expect.equality(received, { "one", 2 })
    MiniTest.expect.equality(core.conditional_func(callback, false, "ignored"), nil)
    MiniTest.expect.equality(core.conditional_func("not callable", true), nil)
  end)
end

T["AC-CORE-004 checks notification enablement before scheduling and delivery"] = function()
  local notifications = {}
  helpers.with_module(
    "astrocore",
    { notify = function(...) table.insert(notifications, { ... }) end },
    function(core, context)
      core.config.features.notifications = false
      core.notify "disabled"
      MiniTest.expect.equality(context.scheduled_count(), 0)

      core.config.features.notifications = true
      core.notify "scheduled"
      MiniTest.expect.equality(context.scheduled_count(), 1)
      core.config.features.notifications = false
      context.drain_scheduled()
      MiniTest.expect.equality(notifications, {})
    end
  )
end

T["AC-CORE-005 forces notifications and preserves caller options"] = function()
  local notifications = {}
  helpers.with_module(
    "astrocore",
    { notify = function(...) table.insert(notifications, { ... }) end },
    function(core, context)
      core.config.features.notifications = false
      core.notify("forced", vim.log.levels.INFO, { title = "caller", timeout = 50 }, true)
      context.drain_scheduled()
      MiniTest.expect.equality(notifications, { { "forced", vim.log.levels.INFO, { title = "caller", timeout = 50 } } })
    end
  )
end

T["AC-CORE-006 prefixes user events, defaults modelines, and schedules only when requested"] = function()
  local events = {}
  helpers.with_module("astrocore", {
    vim = { api = { nvim_exec_autocmds = function(...) table.insert(events, { ... }) end } },
  }, function(core, context)
    core.event("Ready", true)
    core.event { pattern = { "One", "Two" }, modeline = true, data = { source = "test" } }
    MiniTest.expect.equality(events[1], { "User", { pattern = "AstroReady", modeline = false } })
    MiniTest.expect.equality(context.scheduled_count(), 1)
    context.drain_scheduled()
    MiniTest.expect.equality(events[2], {
      "User",
      { pattern = { "AstroOne", "AstroTwo" }, modeline = true, data = { source = "test" } },
    })
  end)
end

T["AC-CORE-007 dispatches valid filetype buffers with per-buffer options"] = function()
  local dispatched = {}
  helpers.with_module("astrocore", {
    replace_vim = { t = true, bo = true },
    vim = {
      t = { [1] = { bufs = { 2, 3 } }, [2] = { bufs = { 4 } } },
      bo = { [2] = { filetype = "lua" }, [3] = { filetype = "" }, [4] = { filetype = "python" } },
      api = {
        nvim_list_tabpages = function() return { 1, 2 } end,
        nvim_buf_is_valid = function(buffer) return buffer ~= 4 end,
        nvim_exec_autocmds = function(event, options) table.insert(dispatched, { event, vim.deepcopy(options) }) end,
      },
    },
  }, function(core)
    core.exec_buffer_autocmds("BufEnter", { nested = true })
    MiniTest.expect.equality(dispatched, {
      { "BufEnter", { nested = true, modeline = false, buffer = 2 } },
      { "BufEnter", { nested = true, modeline = false, buffer = 3 } },
    })
  end)
end

T["AC-CORE-008 reads bytes and closes handles on success and failure"] = function()
  local calls = {}
  helpers.with_module("astrocore", {
    replace_vim = { uv = true },
    vim = {
      uv = {
        fs_open = function(path, mode, permissions)
          table.insert(calls, { "open", path, mode, permissions })
          return 7
        end,
        fs_fstat = function() return { size = 3 } end,
        fs_read = function() return "abc" end,
        fs_close = function(handle)
          table.insert(calls, { "close", handle })
          return true
        end,
      },
    },
  }, function(core)
    MiniTest.expect.equality(core.read_file "/tmp/value", "abc")
    MiniTest.expect.equality(calls, { { "open", "/tmp/value", "r", 420 }, { "close", 7 } })
  end)

  local closed = false
  helpers.with_module("astrocore", {
    replace_vim = { uv = true },
    vim = {
      uv = {
        fs_open = function() return 8 end,
        fs_fstat = function() error "read failed" end,
        fs_close = function()
          closed = true
          return true
        end,
      },
    },
  }, function(core)
    expect_error(function() core.read_file "/tmp/failure" end, "read failed")
    MiniTest.expect.equality(closed, true)
  end)

  helpers.with_module("astrocore", {
    replace_vim = { uv = true },
    vim = {
      uv = {
        fs_open = function() return 9 end,
        fs_fstat = function() return { size = 1 } end,
        fs_read = function() return "x" end,
        fs_close = function() return false, "close failed" end,
      },
    },
  }, function(core)
    expect_error(function() core.read_file "/tmp/close-failure" end, "close failed")
  end)
end

T["AC-CORE-009 reuses terminal registry entries and removes owned entries on exit"] = function()
  local terminals, toggles = {}, 0
  helpers.with_module("astrocore", {
    replace_vim = { v = true },
    vim = { v = { count = 2 } },
    loaded = {
      ["toggleterm.terminal"] = {
        Terminal = {
          new = function(_, options)
            local terminal = { options = options }
            function terminal:toggle() toggles = toggles + 1 end
            table.insert(terminals, terminal)
            return terminal
          end,
        },
      },
    },
  }, function(core)
    core.toggle_term_cmd { cmd = "git status", direction = "float" }
    core.toggle_term_cmd { cmd = "git status", direction = "horizontal" }
    core.toggle_term_cmd {}
    core.toggle_term_cmd {}
    MiniTest.expect.equality(#terminals, 2)
    MiniTest.expect.equality(toggles, 4)
    MiniTest.expect.equality(terminals[1].options.hidden, true)
    MiniTest.expect.equality(terminals[1].options.count, 102)
    MiniTest.expect.equality(terminals[2].options.count, 202)
    terminals[1].options.on_exit "exit"
    MiniTest.expect.equality(core.user_terminals["git status"][2], nil)
  end)
end

T["AC-CORE-010 resolves Lazy specs, availability, and option values safely"] = function()
  local spec = { name = "demo" }
  helpers.with_module("astrocore", {
    loaded = {
      ["lazy.core.config"] = { spec = { plugins = { demo = spec } } },
      ["lazy.core.plugin"] = {
        values = function(received, key) return received == spec and key == "opts" and { enabled = true } end,
      },
    },
  }, function(core)
    MiniTest.expect.equality(core.get_plugin "demo", spec)
    MiniTest.expect.equality(core.get_plugin "missing", nil)
    MiniTest.expect.equality(core.is_available "demo", true)
    MiniTest.expect.equality(core.is_available "missing", false)
    MiniTest.expect.equality(core.plugin_opts "demo", { enabled = true })
    MiniTest.expect.equality(core.plugin_opts "missing", {})
  end)
end

T["AC-CORE-011 restores lazy wrappers before loading and forwards once"] = function()
  local loads, received = {}, nil
  helpers.with_module("astrocore", {
    loaded = { lazy = { load = function(options) table.insert(loads, options) end } },
  }, function(core)
    local module = {}
    local original
    original = function(...) received = { module.run == original, ... } end
    module.run = original
    core.load_plugin_with_func("demo", module, "run")
    module.run("one", 2)
    MiniTest.expect.equality(loads, { { plugins = { "demo" } } })
    MiniTest.expect.equality(received, { true, "one", 2 })
    MiniTest.expect.equality(module.run, original)
  end)
end

T["AC-CORE-012 loads immediately when ready or once for matching LazyLoad events"] = function()
  local registrations, invoked = {}, 0
  helpers.with_module("astrocore", {
    loaded = { ["lazy.core.config"] = { plugins = { ready = { _ = { loaded = true } }, later = { _ = {} } } } },
    vim = {
      api = { nvim_create_autocmd = function(event, options) table.insert(registrations, { event, options }) end },
    },
  }, function(core, context)
    core.on_load("ready", function() invoked = invoked + 1 end)
    MiniTest.expect.equality(context.scheduled_count(), 1)
    context.drain_scheduled()
    MiniTest.expect.equality(invoked, 1)

    core.on_load({ "later", "other" }, function() invoked = invoked + 10 end)
    MiniTest.expect.equality(registrations[1][1], "User")
    MiniTest.expect.equality(registrations[1][2].pattern, "LazyLoad")
    MiniTest.expect.equality(registrations[1][2].callback { data = "unrelated" }, nil)
    MiniTest.expect.equality(invoked, 1)
    MiniTest.expect.equality(registrations[1][2].callback { data = "later" }, true)
    MiniTest.expect.equality(invoked, 11)
  end)
end

T["AC-CORE-013 queues which-key declarations and flushes only when available"] = function()
  local added = {}
  helpers.with_module(
    "astrocore",
    { loaded = { ["which-key"] = { add = function(items) added = items end } } },
    function(core)
      core.on_load = function() end
      core.set_mappings { n = { ["<leader>x"] = { desc = "Example" } } }
      MiniTest.expect.equality(
        core.which_key_queue,
        { { [1] = "<leader>x", desc = "Example", group = "Example", mode = "n" } }
      )
      core.which_key_register()
      MiniTest.expect.equality(added, { { [1] = "<leader>x", desc = "Example", group = "Example", mode = "n" } })
      MiniTest.expect.equality(core.which_key_queue, nil)
    end
  )

  helpers.with_module("astrocore", {
    loaded = { ["which-key"] = helpers.remove },
    preload = { ["which-key"] = helpers.remove },
  }, function(core)
    core.which_key_queue = { { "<leader>x", group = "Example" } }
    core.which_key_register()
    MiniTest.expect.equality(core.which_key_queue, { { "<leader>x", group = "Example" } })
  end)
end

T["AC-CORE-014 configures mappings, groups, and base options"] = function()
  local keymaps, loads = {}, {}
  helpers.with_module("astrocore", {
    vim = { keymap = { set = function(...) table.insert(keymaps, { ... }) end } },
  }, function(core)
    core.on_load = function(plugin, callback) table.insert(loads, { plugin, callback }) end
    local action = function() end
    local base = { silent = true }
    core.set_mappings({
      n = {
        a = ":Alpha<CR>",
        b = action,
        c = { ":Charlie<CR>", desc = "Charlie", noremap = true },
        d = false,
        ["<leader>g"] = { desc = "Group" },
      },
    }, base)
    local mappings = {}
    for _, mapping in ipairs(keymaps) do
      mappings[mapping[2]] = mapping
    end
    MiniTest.expect.equality(mappings.a, { "n", "a", ":Alpha<CR>", { silent = true } })
    MiniTest.expect.equality(mappings.b, { "n", "b", action, { silent = true } })
    MiniTest.expect.equality(mappings.c, {
      "n",
      "c",
      ":Charlie<CR>",
      { silent = true, desc = "Charlie", noremap = true },
    })
    MiniTest.expect.equality(core.which_key_queue, {
      { desc = "Group", [1] = "<leader>g", mode = "n", group = "Group", silent = true },
    })
    MiniTest.expect.equality(loads[1][1], "which-key.nvim")
    MiniTest.expect.equality(base, { silent = true })
  end)
end

T["AC-CORE-015 deletes only URL matches and tracks window URL state"] = function()
  local deleted, added = {}, {}
  helpers.with_module("astrocore", {
    replace_vim = { w = true },
    vim = {
      w = { [9] = {} },
      fn = {
        getmatches = function() return { { id = 1, group = "HighlightURL" }, { id = 2, group = "Other" } } end,
        matchdelete = function(id, window) table.insert(deleted, { id, window }) end,
        matchadd = function(...) table.insert(added, { ... }) end,
      },
    },
  }, function(core)
    core.config.features.highlighturl = true
    core.set_url_match(9)
    MiniTest.expect.equality(deleted, { { 1, 9 } })
    MiniTest.expect.equality(added[1][1], "HighlightURL")
    MiniTest.expect.equality(added[1][3], 15)
    MiniTest.expect.equality(added[1][5], { window = 9 })
    MiniTest.expect.equality(vim.w[9].highlighturl_enabled, true)
  end)
end

T["AC-CORE-016 forwards shell commands, adapts Windows, strips ANSI, and reports errors"] = function()
  local received, echoes = {}, {}
  helpers.with_module("astrocore", {
    vim = {
      fn = {
        has = function() return 1 end,
        system = function(command)
          table.insert(received, command)
          return "ok\27[31m"
        end,
      },
      api = {
        nvim_get_vvar = function() return 0 end,
        nvim_echo = function(...) table.insert(echoes, { ... }) end,
      },
    },
  }, function(core)
    MiniTest.expect.equality(core.cmd "echo test", "ok")
    MiniTest.expect.equality(received[1], { "cmd.exe", "/C", "echo test" })
    MiniTest.expect.equality(echoes, {})
  end)

  helpers.with_module("astrocore", {
    vim = {
      fn = {
        has = function() return 0 end,
        system = function(command) return "failure: " .. table.concat(command, " ") end,
      },
      api = { nvim_get_vvar = function() return 1 end, nvim_echo = function(...) echoes[1] = { ... } end },
    },
  }, function(core)
    MiniTest.expect.equality(core.cmd { "git", "status" }, nil)
    MiniTest.expect.equality(echoes[1][1][1][1]:find("git status", 1, true) ~= nil, true)
  end)
end

T["AC-CORE-017 returns the first matching worktree without reporting misses"] = function()
  helpers.with_module("astrocore", {}, function(core)
    local commands = {}
    core.cmd = function(command, show_error)
      table.insert(commands, { command, show_error })
      return command[3] == "/second"
    end
    local first, second =
      { toplevel = "/first", gitdir = "/git-first" }, { toplevel = "/second", gitdir = "/git-second" }
    MiniTest.expect.equality(core.file_worktree("file.lua", { first, second }), second)
    MiniTest.expect.equality(commands[1][2], false)
    MiniTest.expect.equality(core.file_worktree("file.lua", { first }), nil)
  end)
end

T["AC-CORE-018 forwards original or no-op functions through patches"] = function()
  helpers.with_module("astrocore", {}, function(core)
    local patched = core.patch_func(
      function(left, right) return left + right end,
      function(original, left, right) return original(left, right) * 2 end
    )
    MiniTest.expect.equality(patched(2, 3), 10)
    local called = false
    MiniTest.expect.equality(
      core.patch_func(nil, function(original, value)
        called = true
        return original(value)
      end) "value",
      nil
    )
    MiniTest.expect.equality(called, true)
  end)
end

T["AC-CORE-019 closes real temporary files and reports callback and open failures"] = function()
  helpers.with_module("astrocore", {}, function(core)
    local path = vim.fn.tempname()
    local file = assert(io.open(path, "w"))
    file:write "contents"
    file:close()
    local opened
    core.with_file(path, "r", function(file_handle)
      opened = file_handle
      MiniTest.expect.equality(opened:read "*a", "contents")
    end)
    MiniTest.expect.equality(pcall(opened.read, opened, "*a"), false)
    expect_error(function()
      core.with_file(path, "r", function() error "callback failed" end)
    end, "callback failed")
    local open_error
    core.with_file(path .. ".missing", "r", nil, function(message) open_error = message end)
    MiniTest.expect.equality(type(open_error), "string")
    assert(os.remove(path))
  end)
end

T["AC-CORE-020 rejects unsupported rename inputs before emitting events"] = function()
  local notifications, events, buffer_valid, source_exists = {}, {}, false, false
  helpers.with_module("astrocore", {
    loaded = { ["astrocore.buffer"] = { is_valid = function() return buffer_valid end } },
    vim = {
      api = { nvim_buf_get_name = function() return "" end },
      fn = {
        fnamemodify = function(path) return path end,
        bufnr = function() return -1 end,
        isabsolutepath = function() return 1 end,
      },
      uv = {
        fs_stat = function(path)
          if path == "/source" then return source_exists end
          return path == "/destination"
        end,
      },
    },
  }, function(core)
    core.notify = function(message) table.insert(notifications, message) end
    core.event = function(...) table.insert(events, { ... }) end
    core.rename_file()
    buffer_valid = true
    core.rename_file()
    buffer_valid = false
    core.rename_file { from = "/missing" }
    source_exists = true
    core.rename_file { from = "/source", to = "/destination" }
    MiniTest.expect.equality(notifications[1], "Only renaming real file buffers is supported")
    MiniTest.expect.equality(notifications[2], "Cannot rename unnamed buffer")
    MiniTest.expect.equality(notifications[3]:find("File does not exists", 1, true) ~= nil, true)
    MiniTest.expect.equality(notifications[4]:find("File already exists", 1, true) ~= nil, true)
    MiniTest.expect.equality(events, {})
  end)
end

T["AC-CORE-021 honors rename save yes, no, and cancellation paths"] = function()
  local writes, renames, events, notifications = 0, 0, {}, {}
  helpers.with_module("astrocore", {
    replace_vim = { bo = true, cmd = true },
    vim = {
      bo = { [7] = { modified = true } },
      api = {
        nvim_buf_is_valid = function() return true end,
        nvim_buf_call = function(_, callback) callback() end,
      },
      cmd = { write = function() writes = writes + 1 end },
      fn = {
        fnamemodify = function(path) return path end,
        bufnr = function() return 7 end,
        isabsolutepath = function() return 1 end,
        mkdir = function() end,
        rename = function()
          renames = renames + 1
          return 1
        end,
        confirm = function() return 3 end,
      },
      fs = { dirname = function(path) return path:match "(.+)/[^/]+$" end },
      uv = { fs_stat = function(path) return path == "/from" end },
    },
  }, function(core)
    core.event = function(...) table.insert(events, { ... }) end
    core.notify = function(message) table.insert(notifications, message) end
    core.rename_file { from = "/from", to = "/to-yes", save = true }
    core.rename_file { from = "/from", to = "/to-no", save = false }
    core.rename_file { from = "/from", to = "/to-cancel" }
    MiniTest.expect.equality(writes, 1)
    MiniTest.expect.equality(renames, 2)
    MiniTest.expect.equality(#events, 4)
    MiniTest.expect.equality(notifications[1]:find("Error renaming file", 1, true) ~= nil, true)
    MiniTest.expect.equality(notifications[3]:find("Renaming cancelled", 1, true) ~= nil, true)
  end)
end

T["AC-CORE-024 reuses cached raw mapping normalization across tables"] = function()
  local replace_calls, keytrans_calls = 0, 0
  helpers.with_module("astrocore", {
    vim = {
      api = {
        nvim_replace_termcodes = function(key)
          replace_calls = replace_calls + 1
          return "encoded:" .. key
        end,
      },
      fn = {
        keytrans = function(key)
          keytrans_calls = keytrans_calls + 1
          return key:gsub("encoded:<", "<"):upper()
        end,
      },
    },
  }, function(core)
    local action = function() end
    local mappings = { n = { ["<c-a>"] = action } }
    core.normalize_mappings(mappings)
    MiniTest.expect.equality(mappings, { n = { ["<C-A>"] = action } })
    MiniTest.expect.equality(replace_calls, 1)
    MiniTest.expect.equality(keytrans_calls, 1)

    local repeated = { v = { ["<c-a>"] = "visual" } }
    core.normalize_mappings(repeated)
    MiniTest.expect.equality(repeated, { v = { ["<C-A>"] = "visual" } })
    MiniTest.expect.equality(replace_calls, 1)
    MiniTest.expect.equality(keytrans_calls, 1)
  end)
end

T["AC-CORE-025 waits for package boundaries and emits completion at the supported time"] = function()
  local calls, events, mason_autocmd = {}, {}, nil
  helpers.with_module("astrocore", {
    loaded = {
      lazy = {
        sync = function(options)
          calls = calls or {}
          table.insert(calls, { "sync", options })
        end,
      },
      ["nvim-treesitter"] = {
        update = function()
          return { wait = function() table.insert(calls, { "treesitter" }) end }
        end,
      },
    },
    vim = {
      fn = { exists = function() return 0 end },
      api = { nvim_create_autocmd = function(_, options) mason_autocmd = options end },
      cmd = { MasonToolsUpdate = function() table.insert(calls, { "mason" }) end },
    },
  }, function(core)
    core.event = function(...) table.insert(events, { ... }) end
    core.update_packages()
    MiniTest.expect.equality(calls, { { "sync", { wait = true } }, { "treesitter" } })
    MiniTest.expect.equality(events, { { "UpdateCompleted", true } })
  end)

  calls, events = {}, {}
  helpers.with_module("astrocore", {
    loaded = {
      lazy = { sync = function(options) table.insert(calls, { "sync", options }) end },
      ["nvim-treesitter"] = helpers.remove,
    },
    preload = { ["nvim-treesitter"] = helpers.remove },
    vim = {
      fn = { exists = function() return 1 end },
      api = { nvim_create_autocmd = function(_, options) mason_autocmd = options end },
      cmd = { MasonToolsUpdate = function() table.insert(calls, { "mason" }) end },
    },
  }, function(core)
    core.event = function(...) table.insert(events, { ... }) end
    core.update_packages()
    MiniTest.expect.equality(calls, { { "sync", { wait = true } }, { "mason" } })
    MiniTest.expect.equality(mason_autocmd.pattern, "MasonToolsUpdateCompleted")
    MiniTest.expect.equality(mason_autocmd.once, true)
    mason_autocmd.callback()
    MiniTest.expect.equality(events, { { "UpdateCompleted", true } })
  end)
end

T["AC-CORE-026 restores modifiable state, reloads owned plugins in order, and refreshes colors"] = function()
  local reloads, assignments, commands = {}, {}, {}
  local option = { get = function() return false end }
  local fake_opt = setmetatable({}, {
    __index = function(_, key) return key == "modifiable" and option end,
    __newindex = function(_, key, value) table.insert(assignments, { key, value }) end,
  })
  helpers.with_module("astrocore", {
    replace_vim = { opt = true, cmd = true },
    vim = { opt = fake_opt, cmd = { doautocmd = function(event) table.insert(commands, event) end } },
    loaded = { lazy = { reload = function(options) table.insert(reloads, options) end } },
  }, function(core)
    core.get_plugin = function(plugin) return { name = plugin } end
    core.is_available = function(plugin) return plugin == "astroui" end
    core.reload()
    MiniTest.expect.equality(assignments, { { "modifiable", true }, { "modifiable", false } })
    MiniTest.expect.equality(
      reloads,
      { { plugins = { { name = "astrocore" } } }, { plugins = { { name = "astroui" } } } }
    )
    MiniTest.expect.equality(commands, { "ColorScheme" })
  end)
end

T["AC-CORE-027 forwards setup declarations to public Neovim and integration boundaries"] = function()
  local records = {
    augroups = {},
    autocmds = {},
    commands = {},
    namespaces = {},
    highlights = {},
    signs = {},
    on_keys = {},
    keymaps = {},
  }
  local options = setup_boundaries(records)
  options.loaded = {
    ["astrocore.treesitter"] = { setup = function(value) records.treesitter = value end },
    astroui = { set_colorscheme = function() records.astroui = true end },
  }
  helpers.with_module("astrocore", options, function(core)
    local mapping = function() end
    local on_key = function() end
    core.setup {
      options = { g = { astrocore_test_option = "set" } },
      mappings = { n = { x = { mapping, desc = "mapping" } } },
      autocmds = { TestGroup = { { event = "BufEnter", callback = function() end } } },
      commands = { TestCommand = { function() end, desc = "command" } },
      filetypes = { extension = { unit = "unittest" } },
      on_keys = { test_namespace = { on_key } },
      signs = { TestSign = { text = "!" } },
      diagnostics = { virtual_text = false },
      features = { diagnostics = false },
      rooter = { enabled = true, autochdir = true, detector = { "lsp" } },
      treesitter = { enabled = false },
    }
    MiniTest.expect.equality(vim.g.astrocore_test_option, "set")
    MiniTest.expect.equality(records.keymaps[1][1], "n")
    MiniTest.expect.equality(records.autocmds[1][1], "BufEnter")
    MiniTest.expect.equality(records.commands[1][1], "TestCommand")
    MiniTest.expect.equality(records.filetypes, { extension = { unit = "unittest" } })
    MiniTest.expect.equality(records.on_keys[1][2], 1)
    MiniTest.expect.equality(records.signs, { { "TestSign", { text = "!" } } })
    MiniTest.expect.equality(records.diagnostics, { virtual_text = false })
    MiniTest.expect.equality(records.diagnostic_enabled, false)
    MiniTest.expect.equality(records.treesitter.enabled, false)
    MiniTest.expect.equality(records.treesitter.highlight, true)
    MiniTest.expect.equality(records.treesitter.indent, true)
    MiniTest.expect.equality(records.astroui, true)
    MiniTest.expect.equality(records.highlights[1], { 0, "HighlightURL", { default = true, underline = true } })
    MiniTest.expect.equality(records.commands[2][1], "AstroRootInfo")
    MiniTest.expect.equality(records.commands[3][1], "AstroRoot")
  end)
end

T["AC-CORE-029 executes setup-owned deferred and autocmd callbacks at their public boundaries"] = function()
  local records = {
    augroups = {},
    autocmds = {},
    commands = {},
    namespaces = {},
    highlights = {},
    signs = {},
    on_keys = {},
    keymaps = {},
    buffers = { [7] = {} },
    windows = { [41] = { highlighturl_enabled = false } },
    diagnostic_config = { virtual_text = false, virtual_lines = true },
  }
  local events, notifications, roots, toggles, url_windows = {}, {}, {}, {}, {}
  local options = setup_boundaries(records)
  options.loaded = {
    ["astrocore.buffer"] = {
      is_large = function(bufnr)
        MiniTest.expect.equality(bufnr, 7)
        return true
      end,
    },
    ["astrocore.config"] = dofile "lua/astrocore/config.lua",
    ["astrocore.rooter"] = { root = function(bufnr) table.insert(roots, bufnr) end },
    ["astrocore.toggles"] = {
      virtual_text = function(silent) table.insert(toggles, { "virtual_text", silent }) end,
      virtual_lines = function(silent) table.insert(toggles, { "virtual_lines", silent }) end,
    },
    astroui = helpers.remove,
  }
  options.preload = { astroui = helpers.remove }
  options.vim.api.nvim_buf_get_name = function(bufnr)
    MiniTest.expect.equality(bufnr, 7)
    return "/workspace/large.lua"
  end
  options.vim.api.nvim_list_wins = function() return { 41 } end
  options.vim.api.nvim_win_get_buf = function(win)
    MiniTest.expect.equality(win, 41)
    return 7
  end
  options.vim.fn.fnamemodify = function(path, modifier)
    MiniTest.expect.equality({ path, modifier }, { "/workspace/large.lua", ":p:~:." })
    return "large.lua"
  end

  local function callback(description)
    for _, entry in ipairs(records.autocmds) do
      if entry[2].desc == description then return entry[2].callback end
    end
    error("Missing setup callback: " .. description, 0)
  end

  helpers.with_module("astrocore", options, function(core, context)
    core.event = function(name, immediate) table.insert(events, { name, immediate }) end
    core.notify = function(message) table.insert(notifications, message) end
    core.set_url_match = function(win) table.insert(url_windows, win) end
    core.setup {
      options = { opt = { clipboard = "unnamedplus" } },
      diagnostics = { virtual_text = false, virtual_lines = true },
      features = {
        diagnostics = { virtual_text = true, virtual_lines = false },
        highlighturl = true,
        large_buf = { notify = true },
      },
      rooter = { enabled = true, autochdir = true, detector = { "lsp" } },
      treesitter = false,
    }

    MiniTest.expect.equality(context.scheduled_count(), 1)
    MiniTest.expect.equality(vim.opt.clipboard, nil)
    context.drain_scheduled()
    MiniTest.expect.equality(vim.opt.clipboard, "unnamedplus")
    MiniTest.expect.equality(toggles, { { "virtual_text", true }, { "virtual_lines", true } })

    callback "Large buffer detection loading a file into a buffer" { buf = 7 }
    callback "Set up HighlightURL hlgroup"()
    callback "Highlight URLs" { buf = 7 }
    callback "Root detection when entering a buffer" { buf = 7 }
    callback "Root detection on LSP attach" { buf = 8 }

    MiniTest.expect.equality(records.buffers[7].large_buf, true)
    MiniTest.expect.equality(notifications[1]:find("Large file detected `large.lua`", 1, true) ~= nil, true)
    MiniTest.expect.equality(events, { { "LargeBuf", true } })
    MiniTest.expect.equality(#records.highlights, 2)
    MiniTest.expect.equality(url_windows, { 41 })
    MiniTest.expect.equality(roots, { 7, 8 })
  end)
end

return T
