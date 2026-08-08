local MiniTest = require "mini.test"
local unit_helpers = require "unit_helpers"

local T = MiniTest.new_set()

local function contains(text, fragment) return text:find(fragment, 1, true) ~= nil end

T["AC-ROOT-001 normalizes home, separator, UNC, POSIX, and drive-root paths"] = function()
  unit_helpers.with_module("astrocore.rooter", {
    vim = {
      uv = {
        os_homedir = function() return "/home/astro/" end,
      },
    },
  }, function(rooter)
    MiniTest.expect.equality(rooter.normpath "~/work//astrocore/", "/home/astro/work/astrocore")
    MiniTest.expect.equality(rooter.normpath "/work///astrocore///", "/work/astrocore")
    MiniTest.expect.equality(rooter.normpath "\\\\server\\share\\folder\\", "//server/share/folder")
    MiniTest.expect.equality(rooter.normpath "/", "/")
    MiniTest.expect.equality(rooter.normpath "C:\\", "C:/")
  end)
end

T["AC-ROOT-002 uses exact filesystem and buffer path boundaries"] = function()
  local realpath_calls, stat_calls = {}, {}
  unit_helpers.with_module("astrocore.rooter", {
    vim = {
      api = {
        nvim_buf_get_name = function(bufnr)
          MiniTest.expect.equality(bufnr, 12)
          return "/link"
        end,
      },
      uv = {
        fs_realpath = function(path)
          table.insert(realpath_calls, path)
          return path == "/link" and "/real//path/" or nil
        end,
        fs_stat = function(path)
          table.insert(stat_calls, path)
          return path == "/exists" and {} or nil
        end,
      },
    },
  }, function(rooter)
    MiniTest.expect.equality(rooter.realpath(nil), nil)
    MiniTest.expect.equality(rooter.realpath "", nil)
    MiniTest.expect.equality(rooter.realpath "relative\\path\\", "relative/path")
    MiniTest.expect.equality(rooter.realpath "/link", "/real/path")
    MiniTest.expect.equality(rooter.bufpath(12), "/real/path")
    MiniTest.expect.equality(rooter.exists "/exists", true)
    MiniTest.expect.equality(rooter.exists "/missing", false)
    MiniTest.expect.equality(realpath_calls, { "relative\\path\\", "/link", "/link" })
    MiniTest.expect.equality(stat_calls, { "/exists", "/missing" })
  end)
end

T["AC-ROOT-003 scopes LSP roots, ignores configured clients, and deduplicates"] = function()
  local client_requests = {}
  local clients = {
    {
      name = "lua_ls",
      root_dir = "/repo",
      workspace_folders = { { uri = "file:///repo/" } },
    },
    {
      name = "basedpyright",
      root_dir = "\\repo\\src",
      config = { workspace_folders = { { uri = "file:///repo/src" } } },
    },
    {
      name = "ignored",
      root_dir = "/repo/ignored",
      workspace_folders = { { uri = "file:///repo/ignored" } },
    },
    {
      name = "outside",
      root_dir = "/repository",
      workspace_folders = { { uri = "file:///repository" } },
    },
  }
  unit_helpers.with_module("astrocore.rooter", {
    vim = {
      api = { nvim_buf_get_name = function() return "/repo/src/file.lua" end },
      lsp = {
        get_clients = function(options)
          table.insert(client_requests, options)
          return clients
        end,
      },
      uri_to_fname = function(uri) return (uri:gsub("^file://", "")) end,
      uv = { fs_realpath = function(path) return path end },
    },
  }, function(rooter)
    MiniTest.expect.equality(
      rooter.detectors.lsp { ignore = { servers = { "ignored" } } }(7),
      { "/repo", "\\repo\\src" }
    )
    MiniTest.expect.equality(
      rooter.detectors.lsp { ignore = { servers = function(client) return client.name == "lua_ls" end } }(7),
      { "\\repo\\src" }
    )
    MiniTest.expect.equality(client_requests, { { bufnr = 7 }, { bufnr = 7 } })
  end)
end

T["AC-ROOT-004 searches upward from an existing buffer or the cwd"] = function()
  local find_calls = {}
  unit_helpers.with_module("astrocore.rooter", {
    vim = {
      api = { nvim_buf_get_name = function(bufnr) return bufnr == 3 and "/project/src/file.lua" or "" end },
      fs = {
        find = function(patterns, options)
          table.insert(find_calls, { patterns = patterns, options = options })
          if options.path == "/project/src/file.lua" then return { "/project/.git" } end
          return { "/fallback/package.json" }
        end,
      },
      uv = {
        cwd = function() return "/fallback" end,
        fs_realpath = function(path) return path end,
        fs_stat = function(path) return (path == "/project/src/file.lua" or path == "/fallback") and {} or nil end,
      },
    },
  }, function(rooter)
    local detector = rooter.detectors.pattern()
    MiniTest.expect.equality(detector(3, ".git"), { "/project" })
    MiniTest.expect.equality(detector(4, { "package.json" }), { "/fallback" })
    MiniTest.expect.equality(find_calls, {
      { patterns = { ".git" }, options = { path = "/project/src/file.lua", upward = true } },
      { patterns = { "package.json" }, options = { path = "/fallback", upward = true } },
    })
  end)
end

T["AC-ROOT-005 resolves detector forms and selects normalized deepest roots"] = function()
  local pattern_requests = {}
  unit_helpers.with_module("astrocore.rooter", {
    loaded = {
      ["astrocore.buffer"] = { is_valid = function() return true end },
    },
    vim = {
      api = { nvim_buf_get_name = function() return "/work/file.lua" end },
      uv = { fs_realpath = function(path) return path end },
    },
  }, function(rooter)
    rooter.detectors.named = function(config)
      return function(bufnr)
        MiniTest.expect.equality(config.marker, "named")
        MiniTest.expect.equality(bufnr, 4)
        return { "/named" }
      end
    end
    rooter.detectors.pattern = function()
      return function(bufnr, patterns)
        table.insert(pattern_requests, { bufnr = bufnr, patterns = patterns })
        return { "/pattern" }
      end
    end

    local function detector_function() return "/function" end
    MiniTest.expect.equality(rooter.resolve("named", { marker = "named" })(4), { "/named" })
    MiniTest.expect.equality(rooter.resolve(detector_function), detector_function)
    MiniTest.expect.equality(rooter.resolve ".git"(4), { "/pattern" })
    MiniTest.expect.equality(rooter.resolve { ".git", "lua" }(4), { "/pattern" })
    MiniTest.expect.equality(pattern_requests, {
      { bufnr = 4, patterns = ".git" },
      { bufnr = 4, patterns = { ".git", "lua" } },
    })

    rooter.detectors.none = function()
      return function() return nil end
    end
    rooter.detectors.roots = function()
      return function() return { "/work", "/work/deep/", "/work/deep" } end
    end
    rooter.detectors.later = function()
      return function() return "C:\\later\\" end
    end

    local config = { detector = { "none", "roots", "later" } }
    MiniTest.expect.equality(rooter.detect(4, false, config), {
      { spec = "roots", paths = { "/work/deep", "/work" } },
    })
    MiniTest.expect.equality(rooter.detect(4, true, config), {
      { spec = "roots", paths = { "/work/deep", "/work" } },
      { spec = "later", paths = { "C:/later" } },
    })
    MiniTest.expect.equality(rooter.is_excluded("/ignored/file.lua", { ignore = { dirs = { "^/ignored/" } } }), true)
    MiniTest.expect.equality(rooter.detect(4, true, { detector = { "roots" }, ignore = { dirs = { "^/work/" } } }), {})
  end)
end

T["AC-ROOT-006 reports root facts and disabled autochdir state"] = function()
  local notifications = {}
  unit_helpers.with_module("astrocore.rooter", {
    loaded = {
      ["astrocore"] = {
        config = { rooter = {} },
        notify = function(message, level, options) table.insert(notifications, { message, level, options }) end,
      },
    },
    vim = {
      inspect = function(value) return type(value) == "function" and "<function>" or "<table>" end,
    },
  }, function(rooter)
    local detector = function() return { "/repo" } end
    rooter.detect = function()
      return {
        { spec = detector, paths = { "/repo" } },
        { spec = { ".git", "lua" }, paths = { "/repo/lua" } },
      }
    end
    rooter.info {
      detector = { detector },
      ignore = { dirs = { "/vendor" }, servers = { "ignored" } },
      scope = "tab",
      autochdir = true,
      notify = true,
    }

    MiniTest.expect.equality(notifications[1][2], vim.log.levels.INFO)
    MiniTest.expect.equality(notifications[1][3].title, "AstroNvim Rooter")
    MiniTest.expect.equality(contains(notifications[1][1], "`/repo` *(<function>*)"), true)
    MiniTest.expect.equality(contains(notifications[1][1], "`/repo/lua`"), true)
    MiniTest.expect.equality(contains(notifications[1][1], ".git, lua"), true)
    MiniTest.expect.equality(contains(notifications[1][1], "detector = <table>"), true)
    MiniTest.expect.equality(contains(notifications[1][1], "ignore.dirs = <table>"), true)
    MiniTest.expect.equality(contains(notifications[1][1], "scope ="), true)
  end)

  local disabled_notifications = {}
  unit_helpers.with_module("astrocore.rooter", {
    loaded = {
      ["astrocore"] = {
        config = { rooter = {} },
        notify = function(message, level, options) table.insert(disabled_notifications, { message, level, options }) end,
      },
    },
    replace_vim = { opt = true },
    vim = { opt = { autochdir = { get = function() return true end } } },
  }, function(rooter)
    rooter.root(1, { detector = {} })
    rooter.info { detector = {} }
    MiniTest.expect.equality(disabled_notifications[1][2], vim.log.levels.WARN)
    MiniTest.expect.equality(contains(disabled_notifications[2][1], "Rooting disabled when `autochdir` is set"), true)
  end)
end

T["AC-ROOT-007 dispatches cwd changes by scope and rejects invalid scopes"] = function()
  local calls, notifications, echoes = {}, {}, {}
  local cwd = { global = "C:/old", tab = "C:/repo", win = "C:/repo" }
  local local_dir = { tab = false, win = false }
  unit_helpers.with_module("astrocore.rooter", {
    loaded = {
      ["astrocore"] = {
        config = { rooter = {} },
        notify = function(message) table.insert(notifications, message) end,
      },
    },
    vim = {
      api = {
        nvim_echo = function(chunks) table.insert(echoes, chunks) end,
        nvim_set_current_dir = function(path)
          cwd.global = path
          table.insert(calls, { "global", path })
        end,
      },
      cmd = {
        tchdir = function(path)
          cwd.tab = path
          local_dir.tab = true
          table.insert(calls, { "tab", path })
        end,
        lchdir = function(path)
          cwd.win = path
          local_dir.win = true
          table.insert(calls, { "win", path })
        end,
      },
      fn = {
        getcwd = function(window, tabpage)
          if window == -1 and tabpage == -1 then return cwd.global end
          if window == -1 and tabpage == 0 then return cwd.tab end
          return cwd.win
        end,
        has = function() return 1 end,
        haslocaldir = function(window) return window == -1 and local_dir.tab and 1 or local_dir.win and 1 or 0 end,
      },
    },
  }, function(rooter)
    MiniTest.expect.equality(rooter.set_pwd({ paths = { "C:\\repo" } }, { scope = "global", notify = true }), true)
    MiniTest.expect.equality(rooter.set_pwd({ paths = { "C:/repo" } }, { scope = "global", notify = true }), true)
    MiniTest.expect.equality(rooter.set_pwd({ paths = { "C:/repo" } }, { scope = "tab", notify = false }), true)
    MiniTest.expect.equality(rooter.set_pwd({ paths = { "C:/repo" } }, { scope = "win", notify = false }), true)
    MiniTest.expect.equality(rooter.set_pwd({ paths = { "C:/repo" } }, { scope = "invalid", notify = false }), false)
    MiniTest.expect.equality(calls, { { "global", "C:/repo" }, { "tab", "C:/repo" }, { "win", "C:/repo" } })
    MiniTest.expect.equality(notifications, { "Set CWD to `C:/repo`" })
    MiniTest.expect.equality(echoes[1][1][1], "Unable to parse scope: invalid")
  end)
end

T["AC-ROOT-009 skips before VimEnter and retries after native autochdir clears"] = function()
  local autochdir, detect_calls, set_pwd_calls, notifications = false, 0, 0, {}
  local vim_variables = { vim_did_enter = 0 }
  unit_helpers.with_module("astrocore.rooter", {
    loaded = {
      ["astrocore"] = {
        config = { rooter = {} },
        notify = function(message, level) table.insert(notifications, { message, level }) end,
      },
    },
    replace_vim = { opt = true, v = true },
    vim = {
      opt = { autochdir = { get = function() return autochdir end } },
      v = vim_variables,
    },
  }, function(rooter)
    rooter.detect = function()
      detect_calls = detect_calls + 1
      return { { paths = { "/repo" } } }
    end
    rooter.set_pwd = function()
      set_pwd_calls = set_pwd_calls + 1
      return true
    end

    rooter.root(2, { detector = {} })
    vim_variables.vim_did_enter = 1
    autochdir = true
    rooter.root(2, { detector = {} })
    autochdir = false
    rooter.root(2, { detector = {} })

    MiniTest.expect.equality(detect_calls, 1)
    MiniTest.expect.equality(set_pwd_calls, 1)
    MiniTest.expect.equality(notifications, {
      { "Rooting disabled, unset `autochdir` to re-enable", vim.log.levels.WARN },
    })
  end)
end

return T
