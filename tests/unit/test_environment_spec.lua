local MiniTest = require "mini.test"
local config = require "config"
local environment = require "test_environment"
local spec = require "environment_spec"

local T = MiniTest.new_set()

local function ready_values()
  local paths = {}
  for _, required in ipairs(spec.required_paths) do
    paths[required.path] = required.type
  end
  local plugins, lock = {}, {}
  for index, dependency in ipairs(spec.dependencies) do
    local commit = ("%040x"):format(index)
    plugins[dependency.name] = { path = "data/nvim/lazy/" .. dependency.name, commit = commit }
    lock[dependency.name] = { commit = commit }
  end
  local copied = {}
  for _, library in ipairs(spec.copied_libraries) do
    local files = {}
    for _, file in ipairs(library.files) do
      files[file.destination] = string.rep("a", 64)
    end
    copied[library.name] =
      { source_root = library.source_root, destination_root = library.destination_root, files = files }
  end
  local manifest = {
    schema = environment.schema,
    fingerprint = environment.expected_fingerprint,
    lockfile = "lazy-lock.json",
    lazy = { path = "lazy.nvim", commit = string.rep("b", 40) },
    plugin_root = "data/nvim/lazy",
    test_lua_dir = "lua",
    plugins = plugins,
    lock_plugins = vim.deepcopy(spec.lock_plugins),
    copied_libraries = copied,
    untracked_allowlists = vim.deepcopy(spec.untracked_allowlists),
  }
  local marker = {
    schema = environment.schema,
    fingerprint = environment.expected_fingerprint,
    manifest = "manifest.json",
    lockfile = "lazy-lock.json",
  }
  return marker, manifest, lock, paths
end

T["AC-ENV-001 rejects unsafe lifecycle relative paths"] = function()
  for _, path in ipairs { "", "/tmp/x", "C:/x", "a\\b", "a//b", "a/./b", "a/../b", "a/" } do
    MiniTest.expect.equality(environment.is_safe_relative_path(path), false)
  end
  MiniTest.expect.equality(environment.is_safe_relative_path "data/nvim/lazy/mini.test", true)
end

T["AC-ENV-002 fingerprints only canonical schema specification"] = function()
  MiniTest.expect.equality(environment.canonical_json { z = 1, a = { "x", true } }, '{"a":["x",true],"z":1}')
  MiniTest.expect.equality(environment.fingerprint(spec), environment.expected_fingerprint)
  MiniTest.expect.equality(
    #environment.expected_fingerprint == 64 and environment.expected_fingerprint:match "^[0-9a-f]+$" ~= nil,
    true
  )
end

T["AC-ENV-003 requires full commits and the exact managed lock set"] = function()
  local marker, manifest, lock, paths = ready_values()
  MiniTest.expect.equality(
    environment.validate_ready(marker, manifest, lock, function(path, kind) return paths[path] == kind end),
    true
  )
  manifest.plugins.say.commit = "abc"
  MiniTest.expect.equality(
    environment.validate_ready(marker, manifest, lock, function(path, kind) return paths[path] == kind end),
    false
  )
end

T["AC-ENV-004 requires every explicit copied-library checksum"] = function()
  local marker, manifest, lock, paths = ready_values()
  manifest.copied_libraries.say.files.extra = string.rep("a", 64)
  MiniTest.expect.equality(
    environment.validate_ready(marker, manifest, lock, function(path, kind) return paths[path] == kind end),
    false
  )
end

T["AC-ENV-005 validates prepared repository heads and allowlisted generated files"] = function()
  local valid, validation_error = config.validate_ready_environment()
  MiniTest.expect.equality(valid, true)
  MiniTest.expect.equality(validation_error, nil)
end

T["AC-ENV-006 retries only lock contention and releases after failure"] = function()
  local attempts, now, removed = 0, 0, false
  local filesystem = {
    mkdir = function()
      attempts = attempts + 1
      return attempts == 1 and nil or true, attempts == 1 and "EEXIST" or nil
    end,
    lstat = function() return attempts == 1 and { type = "directory" } or nil end,
    rmdir = function()
      removed = true
      return true
    end,
    now = function()
      now = now + 1
      return now
    end,
    wait = function() end,
  }
  MiniTest.expect.no_error(function()
    environment.with_lifecycle_lock(filesystem, "/lock", function() return "done" end, { timeout_ns = 10 })
  end)
  MiniTest.expect.equality(removed, true)
  MiniTest.expect.equality(environment.lock_error_is_retryable "EPERM", false)

  local ok, error_message = pcall(function()
    environment.with_lifecycle_lock({
      mkdir = function() return true end,
      lstat = function() end,
      rmdir = function() return nil, "release failed" end,
      now = function() return 0 end,
      wait = function() end,
    }, "/lock", function() error("primary failure", 0) end)
  end)
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(error_message:find("primary failure", 1, true) ~= nil, true)
  MiniTest.expect.equality(error_message:find("release failed", 1, true) ~= nil, true)
end

T["AC-ENV-007 rejects partial environments instead of legacy adoption"] = function()
  local paths = environment.paths "/repository"
  MiniTest.expect.equality(environment.classify(paths, function() end), "missing")
  MiniTest.expect.equality(
    environment.classify(paths, function(path) return path == paths.test_root and { type = "directory" } end),
    "partial"
  )
end

T["AC-ENV-008 requires complete staging and a missing publication target"] = function()
  local entries = { ["/staging"] = { type = "directory" } }
  MiniTest.expect.equality(
    environment.can_publish_fresh({ lstat = function(path) return entries[path] end }, "/staging", "/target"),
    true
  )
  entries["/target"] = { type = "directory" }
  MiniTest.expect.equality(
    environment.can_publish_fresh({ lstat = function(path) return entries[path] end }, "/staging", "/target"),
    false
  )
end

T["AC-ENV-009 preflights symbolic links before cleanup"] = function()
  local filesystem = {
    lstat = function(path)
      if path == "/tree" then return { type = "directory" } end
      if path == "/tree/link" then return { type = "link" } end
    end,
    scandir = function() return { "link" } end,
    unlink = function() error "must not unlink" end,
    rmdir = function() error "must not rmdir" end,
  }
  local removed, error_message = environment.remove_tree(filesystem, "/tree")
  MiniTest.expect.equality(removed, false)
  MiniTest.expect.equality(error_message:find "symbolic%-link" ~= nil, true)
  MiniTest.expect.error(
    function() environment.clear_test_environment(filesystem, "/repository", "/repository/not-tests") end
  )
end

T["AC-ENV-010 reuses a marked environment offline without lifecycle mutation"] = function()
  local files = { config.ready, config.manifest, config.lockfile }
  local before = {}
  for _, path in ipairs(files) do
    local stat = assert(vim.uv.fs_stat(path))
    local file = assert(io.open(path, "rb"))
    local contents = assert(file:read "*a")
    file:close()
    before[path] = { size = stat.size, mtime = stat.mtime, hash = vim.fn.sha256(contents) }
  end
  local result = vim.system({ "make", "test-prepare" }, { text = true }):wait()
  MiniTest.expect.equality(result.code, 0)
  for _, path in ipairs(files) do
    local stat = assert(vim.uv.fs_stat(path))
    local file = assert(io.open(path, "rb"))
    local contents = assert(file:read "*a")
    file:close()
    MiniTest.expect.equality({ size = stat.size, mtime = stat.mtime, hash = vim.fn.sha256(contents) }, before[path])
  end
end

return T
