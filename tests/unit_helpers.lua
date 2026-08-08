local M = { remove = {} }

local function restore_packages(entries)
  for name, entry in pairs(entries) do
    package.loaded[name] = entry.loaded
    package.preload[name] = entry.preload
  end
end

local function close_handles(handles)
  for _, handle in ipairs(handles) do
    pcall(handle.stop, handle)
    pcall(handle.close, handle)
  end
end

local function fake_handle(handles, kind)
  local handle = { closed = false, kind = kind, started = false, stopped = false }
  function handle:start(...)
    self.started = true
    self.callback = select(select("#", ...), ...)
    return 0
  end
  function handle:stop() self.stopped = true end
  function handle:close() self.closed = true end
  table.insert(handles, handle)
  return handle
end

function M.with_module(module_name, options, callback)
  options = options or {}
  callback = assert(callback, "A module callback is required")
  assert(not (options.vim and options.vim.notify), "Use options.notify instead of options.vim.notify")
  assert(not (options.vim and options.vim.schedule), "Scheduled callbacks are isolated automatically")
  assert(not (options.vim and options.vim.defer_fn), "Deferred callbacks are isolated automatically")
  local names = { [module_name] = true }
  for name in pairs(options.loaded or {}) do
    names[name] = true
  end
  for name in pairs(options.preload or {}) do
    names[name] = true
  end
  local packages = {}
  for name in pairs(names) do
    packages[name] = { loaded = package.loaded[name], preload = package.preload[name] }
  end

  local replacements = {}
  local replace_vim = options.replace_vim or {}
  local function replace(target, values)
    for name, value in pairs(values) do
      if
        target == vim
        and name ~= "g"
        and not replace_vim[name]
        and type(value) == "table"
        and type(target[name]) == "table"
      then
        replace(target[name], value)
      else
        table.insert(replacements, { target = target, name = name, value = target[name] })
        target[name] = value
      end
    end
  end

  local scheduled, deferred, handles = {}, {}, {}
  local context = {
    handles = handles,
    scheduled_count = function() return #scheduled end,
    deferred_count = function() return #deferred end,
    drain_scheduled = function()
      while #scheduled > 0 do
        local callbacks = scheduled
        scheduled = {}
        for _, scheduled_callback in ipairs(callbacks) do
          scheduled_callback()
        end
      end
    end,
  }
  function context.drain_deferred()
    while #deferred > 0 do
      local callbacks = deferred
      deferred = {}
      for _, deferred_callback in ipairs(callbacks) do
        deferred_callback.callback()
      end
    end
  end
  function context.fire(handle)
    if not handle or handle.closed or not handle.callback then return false end
    handle.callback()
    return true
  end

  local ok, result = xpcall(function()
    for name, value in pairs(options.loaded or {}) do
      if value == M.remove then
        package.loaded[name] = nil
      else
        package.loaded[name] = value
      end
    end
    for name, value in pairs(options.preload or {}) do
      if value == M.remove then
        package.preload[name] = nil
      else
        package.preload[name] = value
      end
    end
    package.loaded[module_name] = nil
    replace(vim, options.vim or {})
    replace(vim, {
      schedule = function(scheduled_callback) table.insert(scheduled, scheduled_callback) end,
      defer_fn = function(deferred_callback, delay)
        table.insert(deferred, { callback = deferred_callback, delay = delay })
      end,
    })
    if options.fake_uv then
      replace(vim.uv, {
        new_check = function() return fake_handle(handles, "check") end,
        new_timer = function() return fake_handle(handles, "timer") end,
      })
    end
    if options.notify then replace(vim, { notify = options.notify }) end
    return callback(require(module_name), context)
  end, debug.traceback)

  close_handles(handles)
  for index = #replacements, 1, -1 do
    local replacement = replacements[index]
    replacement.target[replacement.name] = replacement.value
  end
  restore_packages(packages)
  if not ok then error(result, 0) end
  return result
end

return M
