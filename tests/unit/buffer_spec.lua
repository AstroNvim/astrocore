local MiniTest = require "mini.test"
local helpers = require "unit_helpers"

local T = MiniTest.new_set()

local function copy_list(values)
  local copy = {}
  for index, value in ipairs(values) do
    copy[index] = value
  end
  return copy
end

local function buffer_options(values)
  return setmetatable(values or {}, {
    __index = function() return { buflisted = true, filetype = "lua", buftype = "", bufhidden = "", modified = false } end,
  })
end

local function with_buffer(options, callback)
  options = options or {}
  local state = {
    buffers = options.buffers or { 10, 20, 30 },
    current = options.current or 20,
    tab_bufs = copy_list(options.tab_bufs or { 10, 20, 30 }),
    names = options.names or {},
    loaded = options.loaded or {},
    valid = options.valid or {},
    lines = options.lines or {},
    stats = options.stats or {},
    options = buffer_options(options.buffer_options),
    events = {},
    notifications = {},
    commands = {},
    redraws = 0,
    fs_stat_calls = 0,
    writes = 0,
    tabpages = options.tabpages or { 1, 2 },
    current_tabpage = options.current_tabpage or 1,
  }
  for _, bufnr in ipairs(state.buffers) do
    if state.loaded[bufnr] == nil then state.loaded[bufnr] = true end
    if state.valid[bufnr] == nil then state.valid[bufnr] = true end
    if state.lines[bufnr] == nil then state.lines[bufnr] = 1 end
  end

  local astro = {
    config = options.config or {},
    event = function(event) table.insert(state.events, event) end,
    notify = function(message, level) table.insert(state.notifications, { message = message, level = level }) end,
    is_available = options.is_available or function() return false end,
  }
  local command = setmetatable({
    redrawtabline = function() state.redraws = state.redraws + 1 end,
    tabclose = function(tabnr) table.insert(state.commands, { "tabclose", tabnr }) end,
    write = options.write or function() state.writes = state.writes + 1 end,
  }, {
    __call = function(_, value) table.insert(state.commands, value) end,
  })
  local api = {
    nvim_buf_is_valid = function(bufnr) return state.valid[bufnr == 0 and state.current or bufnr] or false end,
    nvim_buf_is_loaded = function(bufnr) return state.loaded[bufnr] or false end,
    nvim_get_current_buf = function() return state.current end,
    nvim_set_current_buf = function(bufnr) state.current = bufnr end,
    nvim_buf_get_name = function(bufnr) return state.names[bufnr] or "" end,
    nvim_buf_line_count = function(bufnr) return state.lines[bufnr] or 1 end,
    nvim_list_bufs = function() return state.buffers end,
    nvim_buf_call = function(_, func) return func() end,
    nvim_list_tabpages = function() return state.tabpages end,
    nvim_get_current_tabpage = function() return state.current_tabpage end,
    nvim_tabpage_get_number = function(tabpage) return tabpage end,
  }
  local fn = {
    getcwd = function() return options.cwd or "/workspace" end,
    expand = function(value) return (options.expand or {})[value] or value end,
    confirm = options.confirm or function() return 3 end,
  }
  local tab_variables = setmetatable({}, {
    __index = function(_, key)
      if key == "bufs" then return copy_list(state.tab_bufs) end
    end,
    __newindex = function(_, key, value)
      if key == "bufs" then state.tab_bufs = copy_list(value) end
    end,
  })

  helpers.with_module("astrocore.buffer", {
    loaded = vim.tbl_extend("force", { astrocore = astro }, options.loaded_modules or {}),
    vim = {
      api = api,
      bo = state.options,
      t = tab_variables,
      cmd = command,
      fn = fn,
      uv = {
        fs_stat = function(path)
          state.fs_stat_calls = state.fs_stat_calls + 1
          return state.stats[path]
        end,
      },
    },
    replace_vim = { bo = true, t = true, cmd = true },
  }, function(buffer) callback(buffer, state, astro) end)
end

T["AC-BUF-001 validates listed buffers and detects filetypes"] = function()
  with_buffer({
    buffer_options = {
      [10] = { buflisted = true, filetype = "lua", buftype = "", bufhidden = "", modified = false },
      [20] = { buflisted = false, filetype = "", buftype = "", bufhidden = "", modified = false },
    },
  }, function(buffer, state)
    MiniTest.expect.equality(buffer.is_valid(10), true)
    MiniTest.expect.equality(buffer.is_valid(20), false)
    MiniTest.expect.equality(buffer.is_valid(99), false)
    state.current = 10
    MiniTest.expect.equality(buffer.is_valid(), true)
    MiniTest.expect.equality(buffer.has_filetype(10), true)
    MiniTest.expect.equality(buffer.has_filetype(20), false)
  end)
end

T["AC-BUF-002 restores only eligible named session buffers"] = function()
  with_buffer({
    buffers = { 10, 20, 30, 40, 50 },
    names = {
      [10] = "/workspace/keep.lua",
      [20] = "",
      [30] = "/workspace/hidden.lua",
      [40] = "/workspace/ignored.lua",
      [50] = "/workspace/terminal",
    },
    buffer_options = {
      [10] = { buflisted = true, filetype = "lua", buftype = "", bufhidden = "", modified = false },
      [20] = { buflisted = true, filetype = "lua", buftype = "", bufhidden = "", modified = false },
      [30] = { buflisted = true, filetype = "lua", buftype = "", bufhidden = "hide", modified = false },
      [40] = { buflisted = true, filetype = "ignored", buftype = "", bufhidden = "", modified = false },
      [50] = { buflisted = true, filetype = "", buftype = "terminal", bufhidden = "", modified = false },
    },
    config = {
      sessions = { ignore = { dirs = { "~/blocked" }, filetypes = { "ignored" }, buftypes = { "terminal" } } },
    },
    cwd = "/workspace",
    expand = { ["~/blocked"] = "/blocked" },
  }, function(buffer, state)
    MiniTest.expect.equality(buffer.is_restorable(10), true)
    MiniTest.expect.equality(buffer.is_restorable(20), false)
    MiniTest.expect.equality(buffer.is_restorable(30), false)
    MiniTest.expect.equality(buffer.is_restorable(40), false)
    MiniTest.expect.equality(buffer.is_restorable(50), false)
    MiniTest.expect.equality(buffer.is_valid_session(), true)
    state.names[10] = ""
    MiniTest.expect.equality(buffer.is_valid_session(), false)
  end)

  with_buffer(
    { config = { sessions = { ignore = { dirs = { "/workspace" } } } } },
    function(buffer) MiniTest.expect.equality(buffer.is_valid_session(), false) end
  )
end

T["AC-BUF-003 detects configured large-buffer thresholds and callbacks"] = function()
  with_buffer({
    names = { [10] = "/workspace/large.lua" },
    lines = { [10] = 4 },
    stats = { ["/workspace/large.lua"] = { size = 100 } },
    config = { features = { large_buf = { size = 99 } } },
  }, function(buffer) MiniTest.expect.equality(buffer.is_large(10), true) end)

  with_buffer({
    names = { [10] = "/workspace/large.lua" },
    lines = { [10] = 4 },
    stats = { ["/workspace/large.lua"] = { size = 100 } },
    config = { features = { large_buf = { lines = 3 } } },
  }, function(buffer) MiniTest.expect.equality(buffer.is_large(10), true) end)

  with_buffer({
    names = { [10] = "/workspace/large.lua" },
    lines = { [10] = 4 },
    stats = { ["/workspace/large.lua"] = { size = 100 } },
    config = { features = { large_buf = { line_length = 23 } } },
  }, function(buffer) MiniTest.expect.equality(buffer.is_large(10), true) end)

  with_buffer({
    names = { [10] = "/workspace/large.lua" },
    loaded = { [10] = false },
    config = { features = { large_buf = { size = 1 } } },
  }, function(buffer) MiniTest.expect.equality(buffer.is_large(10), false) end)

  with_buffer({
    names = { [10] = "/workspace/large.lua" },
    stats = { ["/workspace/large.lua"] = { size = 100 } },
    config = { features = { large_buf = false } },
  }, function(buffer) MiniTest.expect.equality(buffer.is_large(10), false) end)

  with_buffer({
    names = { [10] = "/workspace/large.lua" },
    stats = { ["/workspace/large.lua"] = { size = 100 } },
    config = { features = { large_buf = { enabled = false, size = 1 } } },
  }, function(buffer) MiniTest.expect.equality(buffer.is_large(10), false) end)

  local callback_options = {
    enabled = function(_, values)
      values.size = 10
      return values
    end,
    size = 1000,
  }
  with_buffer({
    names = { [10] = "/workspace/large.lua" },
    stats = { ["/workspace/large.lua"] = { size = 100 } },
    config = { features = { large_buf = callback_options } },
  }, function(buffer)
    MiniTest.expect.equality(buffer.is_large(10), true)
    MiniTest.expect.equality(callback_options.size, 1000)
  end)
end

T["AC-BUF-004 caches default large-buffer decisions without caching explicit options"] = function()
  with_buffer({
    names = { [10] = "/workspace/cache.lua", [20] = "/workspace/other.lua" },
    stats = { ["/workspace/cache.lua"] = { size = 100 }, ["/workspace/other.lua"] = { size = 75 } },
    config = { features = { large_buf = { size = 50 } } },
  }, function(buffer, state)
    MiniTest.expect.equality(buffer.is_large(10), true)
    MiniTest.expect.equality(buffer.is_large(20), true)
    state.stats["/workspace/cache.lua"] = { size = 0 }
    MiniTest.expect.equality(buffer.is_large(10), true)
    MiniTest.expect.equality(state.fs_stat_calls, 2)

    local explicit = { size = 200 }
    MiniTest.expect.equality(buffer.is_large(10, explicit), false)
    MiniTest.expect.equality(explicit, { size = 200 })
  end)
end

T["AC-BUF-006 moves tab buffers with wrapped offsets and stable no-op lists"] = function()
  with_buffer({ current = 20, tab_bufs = { 10, 20, 30 } }, function(buffer, state)
    buffer.move(4)
    MiniTest.expect.equality(vim.t.bufs, { 10, 30, 20 })
    MiniTest.expect.equality(state.events, { "BufsUpdated" })
    MiniTest.expect.equality(state.redraws, 1)

    state.events, state.redraws = {}, 0
    state.current = 20
    buffer.move(-1)
    MiniTest.expect.equality(vim.t.bufs, { 10, 20, 30 })

    state.events, state.redraws = {}, 0
    buffer.move(0)
    MiniTest.expect.equality(state.events, {})
    MiniTest.expect.equality(state.redraws, 0)
  end)

  with_buffer({ current = 99, tab_bufs = { 10, 20 } }, function(buffer)
    buffer.move(1)
    MiniTest.expect.equality(vim.t.bufs, { 10, 20 })
  end)

  with_buffer({ current = 99, tab_bufs = {} }, function(buffer)
    buffer.move(1)
    MiniTest.expect.equality(vim.t.bufs, {})
  end)
end

T["AC-BUF-007 navigates wrapped tab members and reports invalid absolute positions"] = function()
  with_buffer({ current = 20, tab_bufs = { 10, 20, 30 } }, function(buffer, state)
    buffer.nav(2)
    MiniTest.expect.equality(state.current, 10)
    buffer.nav_to(3)
    MiniTest.expect.equality(state.current, 30)
    buffer.nav_to(4)
    MiniTest.expect.equality(state.notifications[1].message, "No tab #4")
    MiniTest.expect.equality(state.notifications[1].level, vim.log.levels.WARN)
  end)
end

T["AC-BUF-008 switches to a valid previous buffer only from the tracked main buffer"] = function()
  with_buffer({ current = 20 }, function(buffer, state)
    buffer.current_buf, buffer.last_buf = 20, 10
    buffer.prev()
    MiniTest.expect.equality(state.current, 10)

    state.current = 20
    state.valid[10] = false
    buffer.prev()
    MiniTest.expect.equality(state.notifications[1].message, "Previous buffer not found")

    state.current = 30
    buffer.prev()
    MiniTest.expect.equality(
      state.notifications[2].message,
      "Must be in a main editor window to switch the window buffer"
    )
  end)
end

T["AC-BUF-009 delegates close and wipe through Snacks, mini.bufremove, or Neovim"] = function()
  local snacks_calls = {}
  with_buffer({
    is_available = function(name) return name == "snacks.nvim" end,
    loaded_modules = { snacks = { bufdelete = function(values) table.insert(snacks_calls, values) end } },
  }, function(buffer)
    buffer.close(10, true)
    buffer.wipe(20, false)
    MiniTest.expect.equality(snacks_calls, { { buf = 10, force = true }, { buf = 20, force = false, wipe = true } })
  end)

  local mini_calls = {}
  with_buffer({
    is_available = function(name) return name == "mini.bufremove" end,
    loaded_modules = {
      ["mini.bufremove"] = {
        delete = function(bufnr, force) table.insert(mini_calls, { "delete", bufnr, force }) end,
        wipeout = function(bufnr, force) table.insert(mini_calls, { "wipeout", bufnr, force }) end,
      },
    },
  }, function(buffer)
    buffer.close(10, true)
    buffer.wipe(20, true)
    MiniTest.expect.equality(mini_calls, { { "delete", 10, true }, { "wipeout", 20, true } })
  end)

  with_buffer({
    buffer_options = {
      [10] = { buflisted = true, filetype = "", buftype = "terminal", bufhidden = "", modified = false },
    },
  }, function(buffer, state)
    buffer.close(10, false)
    buffer.wipe(10, false)
    MiniTest.expect.equality(state.commands, { "silent! bdelete! 10", "silent! bwipeout! 10" })
  end)
end

T["AC-BUF-010 confirms modified mini.bufremove operations at the public boundary"] = function()
  local calls = {}
  local function mini_module()
    return {
      delete = function(bufnr, force) table.insert(calls, { bufnr, force }) end,
      wipeout = function(bufnr, force) table.insert(calls, { "wipeout", bufnr, force }) end,
    }
  end
  local function modified_options(name)
    return { [10] = { buflisted = true, filetype = "", buftype = "", bufhidden = "", modified = true } }, { [10] = name }
  end

  local options, names = modified_options "/workspace/save.lua"
  with_buffer({
    buffer_options = options,
    names = names,
    is_available = function(name) return name == "mini.bufremove" end,
    loaded_modules = { ["mini.bufremove"] = mini_module() },
    confirm = function() return 1 end,
  }, function(buffer, state)
    buffer.close(10, false)
    MiniTest.expect.equality(state.writes, 1)
    MiniTest.expect.equality(calls, { { 10, false } })
  end)

  calls = {}
  options, names = modified_options ""
  with_buffer({
    buffer_options = options,
    names = names,
    is_available = function(name) return name == "mini.bufremove" end,
    loaded_modules = { ["mini.bufremove"] = mini_module() },
    confirm = function() return 1 end,
  }, function(buffer)
    buffer.close(10, false)
    MiniTest.expect.equality(calls, {})
  end)

  calls = {}
  options, names = modified_options "/workspace/discard.lua"
  with_buffer({
    buffer_options = options,
    names = names,
    is_available = function(name) return name == "mini.bufremove" end,
    loaded_modules = { ["mini.bufremove"] = mini_module() },
    confirm = function() return 2 end,
  }, function(buffer)
    buffer.wipe(10, false)
    MiniTest.expect.equality(calls, { { "wipeout", 10, true } })
  end)

  calls = {}
  with_buffer({
    buffer_options = options,
    names = names,
    is_available = function(name) return name == "mini.bufremove" end,
    loaded_modules = { ["mini.bufremove"] = mini_module() },
    confirm = function() return 3 end,
  }, function(buffer)
    buffer.close(10, false)
    MiniTest.expect.equality(calls, {})
  end)

  calls = {}
  options, names = modified_options "/workspace/write-error.lua"
  with_buffer({
    buffer_options = options,
    names = names,
    is_available = function(name) return name == "mini.bufremove" end,
    loaded_modules = { ["mini.bufremove"] = mini_module() },
    confirm = function() return 1 end,
    write = function() error "write failed" end,
  }, function(buffer)
    MiniTest.expect.equality(pcall(buffer.close, 10, false), false)
    MiniTest.expect.equality(calls, {})
  end)
end

local function remove_tab_member(bufnr)
  local members = vim.t.bufs
  for index, member in ipairs(members) do
    if member == bufnr then
      table.remove(members, index)
      break
    end
  end
  vim.t.bufs = members
end

T["AC-BUF-011 closes every original non-current member with force forwarding"] = function()
  with_buffer({ current = 20, tab_bufs = { 10, 20, 30, 40 } }, function(buffer)
    local closed = {}
    buffer.close = function(bufnr, force)
      table.insert(closed, { bufnr, force })
      remove_tab_member(bufnr)
    end
    buffer.close_all(true, true)
    MiniTest.expect.equality(closed, { { 10, true }, { 30, true }, { 40, true } })
  end)
end

T["AC-BUF-015 closes every original member left of current with force forwarding"] = function()
  with_buffer({ current = 20, tab_bufs = { 10, 20, 30, 40 } }, function(buffer)
    local closed = {}
    buffer.close = function(bufnr, force)
      table.insert(closed, { bufnr, force })
      remove_tab_member(bufnr)
    end
    buffer.close_left(true)
    MiniTest.expect.equality(closed, { { 10, true } })
  end)
end

T["AC-BUF-016 closes every original member right of current with force forwarding"] = function()
  with_buffer({ current = 20, tab_bufs = { 10, 20, 30, 40 } }, function(buffer)
    local closed = {}
    buffer.close = function(bufnr, force)
      table.insert(closed, { bufnr, force })
      remove_tab_member(bufnr)
    end
    buffer.close_right(true)
    MiniTest.expect.equality(closed, { { 30, true }, { 40, true } })
  end)
end

T["AC-BUF-012 sorts with named and custom comparators and controls update events"] = function()
  with_buffer({
    tab_bufs = { 30, 10, 20 },
    loaded_modules = { ["astrocore.buffer.comparator"] = { by_number = function(a, b) return a < b end } },
  }, function(buffer, state)
    MiniTest.expect.equality(buffer.sort "by_number", true)
    MiniTest.expect.equality(vim.t.bufs, { 10, 20, 30 })
    MiniTest.expect.equality(state.events, { "BufsUpdated" })
    MiniTest.expect.equality(state.redraws, 1)

    MiniTest.expect.equality(buffer.sort(function(a, b) return a > b end, true), true)
    MiniTest.expect.equality(vim.t.bufs, { 30, 20, 10 })
    MiniTest.expect.equality(state.events, { "BufsUpdated" })
    MiniTest.expect.equality(state.redraws, 2)

    MiniTest.expect.equality(buffer.sort "missing", false)
  end)
end

T["AC-BUF-014 closes a tab only when another tab exists"] = function()
  with_buffer({ tabpages = { 1 } }, function(buffer, state)
    buffer.close_tab()
    MiniTest.expect.equality(state.commands, {})
    MiniTest.expect.equality(state.events, {})
  end)

  with_buffer({ tabpages = { 1, 2 }, current_tabpage = 2 }, function(buffer, state)
    buffer.close_tab()
    MiniTest.expect.equality(state.commands, { { "tabclose", 2 } })
    MiniTest.expect.equality(state.events, { "BufsUpdated" })
  end)
end

local function with_comparator(options, callback)
  local infos = options.infos or {}
  local notifications = {}
  local fnamemodify = options.fnamemodify
    or function(name, modifier)
      if modifier == ":e" then return name:match "%.([^./]+)$" or "" end
      if modifier == ":t" then return name:match "([^/]+)$" or name end
      return name
    end
  helpers.with_module("astrocore.buffer.comparator", {
    loaded = options.loaded or {},
    preload = options.preload or {},
    notify = function(...) table.insert(notifications, { ... }) end,
    vim = {
      fn = {
        getbufinfo = function(bufnr) return { infos[bufnr] } end,
        fnamemodify = fnamemodify,
      },
    },
  }, function(comparator) callback(comparator, notifications) end)
end

T["AC-CMP-001 orders buffers by number"] = function()
  with_comparator({}, function(comparator)
    MiniTest.expect.equality(comparator.bufnr(2, 10), true)
    MiniTest.expect.equality(comparator.bufnr(10, 2), false)
    MiniTest.expect.equality(comparator.bufnr(2, 2), false)
  end)
end

T["AC-CMP-002 orders extensions and full paths from resolved buffer names"] = function()
  with_comparator({
    infos = {
      [1] = { name = "/work/beta.lua" },
      [2] = { name = "/work/alpha.txt" },
      [3] = { name = "/other/one.lua" },
      [4] = { name = "/other/two.lua" },
    },
  }, function(comparator)
    MiniTest.expect.equality(comparator.extension(1, 2), true)
    MiniTest.expect.equality(comparator.full_path(2, 1), true)
    MiniTest.expect.equality(comparator.extension(3, 4), false)
    MiniTest.expect.equality(comparator.extension(4, 3), false)
    MiniTest.expect.equality(comparator.full_path(3, 3), false)
  end)
end

T["AC-CMP-003 delegates unique-path prefixes to AstroUI for both buffer numbers"] = function()
  local requested = {}
  with_comparator({
    infos = { [1] = { name = "/work/one.lua" }, [2] = { name = "/work/two.lua" } },
    loaded = {
      ["astroui.status.provider"] = {
        unique_path = function()
          return function(options)
            table.insert(requested, options.bufnr)
            return options.bufnr == 1 and "a/" or "b/"
          end
        end,
      },
    },
  }, function(comparator)
    MiniTest.expect.equality(comparator.unique_path(1, 2), true)
    MiniTest.expect.equality(requested, { 1, 2 })
  end)

  with_comparator({
    infos = { [1] = { name = "/work/one.lua" }, [2] = { name = "/work/two.lua" } },
    loaded = { ["astroui.status.provider"] = helpers.remove },
    preload = { ["astroui.status.provider"] = helpers.remove },
  }, function(comparator, notifications)
    MiniTest.expect.equality(comparator.unique_path(1, 2), false)
    MiniTest.expect.equality(#notifications, 2)
    for _, notification in ipairs(notifications) do
      MiniTest.expect.equality(notification[1], "AstroUI required for unique path calculation")
      MiniTest.expect.equality(notification[2], vim.log.levels.ERROR)
      MiniTest.expect.equality(notification[3], { title = "AstroNvim" })
    end
  end)
end

T["AC-CMP-004 orders most recently used buffers first"] = function()
  with_comparator({ infos = { [1] = { lastused = 20 }, [2] = { lastused = 10 } } }, function(comparator)
    MiniTest.expect.equality(comparator.modified(1, 2), true)
    MiniTest.expect.equality(comparator.modified(2, 1), false)
    MiniTest.expect.equality(comparator.modified(1, 1), false)
  end)
end

return T
