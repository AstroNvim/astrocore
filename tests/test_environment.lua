local spec = require "environment_spec"

local M = { schema = spec.schema }

local function is_table(value) return type(value) == "table" end

local function entry_type(entry)
  if type(entry) == "string" then return entry end
  return is_table(entry) and entry.type or nil
end

local function exact_keys(value, expected)
  if not is_table(value) then return false end
  local count = 0
  for key in pairs(value) do
    if not expected[key] then return false end
    count = count + 1
  end
  local expected_count = 0
  for _ in pairs(expected) do
    expected_count = expected_count + 1
  end
  return count == expected_count
end

local function is_array(value)
  if not is_table(value) then return false end
  for index = 1, #value do
    if value[index] == nil then return false end
  end
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > #value then return false end
  end
  return true
end

local function is_commit(value) return type(value) == "string" and #value == 40 and value:match "^[0-9a-f]+$" ~= nil end

local function canonical_string(value)
  local escapes =
    { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
  return '"'
    .. value:gsub(
      '[%z\1-\31\\"]',
      function(character) return escapes[character] or string.format("\\u%04x", character:byte()) end
    )
    .. '"'
end

function M.canonical_json(value)
  local kind = type(value)
  if kind == "string" then return canonical_string(value) end
  if kind == "number" then
    assert(
      value == value and value ~= math.huge and value ~= -math.huge and value % 1 == 0,
      "Canonical JSON accepts finite integers"
    )
    return tostring(value)
  end
  if kind == "boolean" then return tostring(value) end
  if kind == "nil" then return "null" end
  assert(kind == "table", "Canonical JSON accepts only JSON values")

  if is_array(value) then
    local items = {}
    for _, item in ipairs(value) do
      table.insert(items, M.canonical_json(item))
    end
    return "[" .. table.concat(items, ",") .. "]"
  end

  local keys = {}
  for key in pairs(value) do
    assert(type(key) == "string", "Canonical JSON object keys must be strings")
    table.insert(keys, key)
  end
  table.sort(keys)
  local items = {}
  for _, key in ipairs(keys) do
    table.insert(items, canonical_string(key) .. ":" .. M.canonical_json(value[key]))
  end
  return "{" .. table.concat(items, ",") .. "}"
end

function M.fingerprint(environment_spec)
  local compatibility = {
    schema = environment_spec.schema,
    lazy = environment_spec.lazy,
    dependencies = environment_spec.dependencies,
    required_paths = environment_spec.required_paths,
    copied_files = environment_spec.copied_libraries,
    untracked_allowlists = environment_spec.untracked_allowlists,
  }
  return vim.fn.sha256(M.canonical_json(compatibility)):lower()
end

M.expected_fingerprint = M.fingerprint(spec)

function M.is_safe_relative_path(path)
  if type(path) ~= "string" or path == "" then return false end
  if path:sub(1, 1) == "/" or path:match "^[A-Za-z]:" or path:find("\\", 1, true) then return false end
  if path:find("//", 1, true) or path:sub(-1) == "/" then return false end
  for segment in path:gmatch "[^/]+" do
    if segment == "." or segment == ".." then return false end
  end
  return true
end

function M.find_symlink_component(root, path, lstat)
  if type(root) ~= "string" or type(path) ~= "string" or type(lstat) ~= "function" then return path end
  local prefix = root .. "/"
  if path ~= root and path:sub(1, #prefix) ~= prefix then return path end
  if entry_type(lstat(root)) == "link" then return root end

  local current = root
  for segment in path:sub(#prefix + 1):gmatch "[^/]+" do
    current = current .. "/" .. segment
    if entry_type(lstat(current)) == "link" then return current end
  end
end

function M.has_safe_path_type(root, path, expected_type, lstat)
  return M.find_symlink_component(root, path, lstat) == nil and entry_type(lstat(path)) == expected_type
end

function M.paths_for_test_root(test_root)
  return {
    root = test_root,
    lazy_path = test_root .. "/lazy.nvim",
    plugin_root = test_root .. "/data/nvim/lazy",
    test_lua_dir = test_root .. "/lua",
    lockfile = test_root .. "/lazy-lock.json",
    manifest = test_root .. "/manifest.json",
    ready = test_root .. "/.ready",
    state_dir = test_root .. "/state",
    cache_dir = test_root .. "/cache",
  }
end

function M.paths(root)
  local paths = {
    repository_root = root,
    test_root = root .. "/.tests",
    staging_root = root .. "/.tests.bootstrap",
    prepare_lock = root .. "/.tests.prepare.lock",
  }
  for key, value in pairs(M.paths_for_test_root(paths.test_root)) do
    paths[key] = value
  end
  return paths
end

function M.classify(paths, lstat)
  if not lstat(paths.test_root) then return "missing" end
  if entry_type(lstat(paths.test_root)) ~= "directory" then return "partial" end
  if not lstat(paths.ready) then return "partial" end
  return "marked"
end

function M.is_clear_target(root, target) return target == root .. "/.tests" end
function M.is_staging_target(root, target) return target == root .. "/.tests.bootstrap" end

local function dependency_by_name(name)
  for _, dependency in ipairs(spec.dependencies) do
    if dependency.name == name then return dependency end
  end
end

local function exact_array(value, expected)
  if not is_array(value) or #value ~= #expected then return false end
  for index, item in ipairs(expected) do
    if value[index] ~= item then return false end
  end
  return true
end

local function validate_copied_libraries(copied_libraries)
  if not is_table(copied_libraries) or not exact_keys(copied_libraries, { luassert = true, say = true }) then
    return false, "the copied-library manifest set is invalid"
  end
  for _, library in ipairs(spec.copied_libraries) do
    local actual = copied_libraries[library.name]
    if not exact_keys(actual, { source_root = true, destination_root = true, files = true }) then
      return false, "the copied-library manifest entry is invalid: " .. library.name
    end
    if actual.source_root ~= library.source_root or actual.destination_root ~= library.destination_root then
      return false, "the copied-library roots are invalid: " .. library.name
    end
    if not is_table(actual.files) then return false, "the copied-library file set is invalid: " .. library.name end
    local expected = {}
    for _, file in ipairs(library.files) do
      expected[file.destination] = true
    end
    if not exact_keys(actual.files, expected) then
      return false, "the copied-library files are incomplete: " .. library.name
    end
    for destination, checksum in pairs(actual.files) do
      if
        not M.is_safe_relative_path(destination)
        or type(checksum) ~= "string"
        or #checksum ~= 64
        or checksum:match "^[0-9a-f]+$" == nil
      then
        return false, "the copied-library checksum is invalid: " .. library.name
      end
    end
  end
  return true
end

function M.validate_ready(marker, manifest, lock, path_metadata)
  local expected_marker = { schema = true, fingerprint = true, manifest = true, lockfile = true }
  if
    not exact_keys(marker, expected_marker)
    or marker.schema ~= M.schema
    or marker.fingerprint ~= M.expected_fingerprint
  then
    return false, "the .ready marker schema or fingerprint is incompatible"
  end
  if marker.manifest ~= "manifest.json" or marker.lockfile ~= "lazy-lock.json" then
    return false, "the .ready marker references unexpected files"
  end

  local manifest_keys = {
    schema = true,
    fingerprint = true,
    lockfile = true,
    lazy = true,
    plugin_root = true,
    test_lua_dir = true,
    plugins = true,
    lock_plugins = true,
    copied_libraries = true,
    untracked_allowlists = true,
  }
  if
    not exact_keys(manifest, manifest_keys)
    or manifest.schema ~= M.schema
    or manifest.fingerprint ~= M.expected_fingerprint
  then
    return false, "the manifest schema or fingerprint is incompatible"
  end
  if
    manifest.lockfile ~= "lazy-lock.json"
    or manifest.plugin_root ~= "data/nvim/lazy"
    or manifest.test_lua_dir ~= "lua"
  then
    return false, "the manifest contains unexpected required paths"
  end
  if
    not exact_keys(manifest.lazy, { path = true, commit = true })
    or manifest.lazy.path ~= "lazy.nvim"
    or not is_commit(manifest.lazy.commit)
  then
    return false, "the lazy.nvim manifest entry is invalid"
  end
  if not exact_array(manifest.lock_plugins, spec.lock_plugins) then
    return false, "the managed lock plugin order is invalid"
  end

  local names = {}
  for _, name in ipairs(spec.lock_plugins) do
    names[name] = true
  end
  if
    not is_table(manifest.plugins)
    or not exact_keys(manifest.plugins, names)
    or not is_table(lock)
    or not exact_keys(lock, names)
  then
    return false, "the managed plugin set does not exactly match the lockfile"
  end
  for name in pairs(names) do
    local dependency = dependency_by_name(name)
    local plugin = manifest.plugins[name]
    local lock_entry = lock[name]
    if
      not exact_keys(plugin, { path = true, commit = true })
      or plugin.path ~= manifest.plugin_root .. "/" .. dependency.name
      or not is_commit(plugin.commit)
    then
      return false, "the managed plugin manifest entry is invalid: " .. name
    end
    if not is_table(lock_entry) or not is_commit(lock_entry.commit) or lock_entry.commit ~= plugin.commit then
      return false, "the generated lockfile does not match " .. name
    end
  end

  local copied, copied_error = validate_copied_libraries(manifest.copied_libraries)
  if not copied then return false, copied_error end
  local allowlist_names = vim.deepcopy(names)
  allowlist_names[spec.lazy.name] = true
  if not is_table(manifest.untracked_allowlists) or not exact_keys(manifest.untracked_allowlists, allowlist_names) then
    return false, "the untracked allowlist set is invalid"
  end
  for name, expected in pairs(spec.untracked_allowlists) do
    if not exact_array(manifest.untracked_allowlists[name], expected) then
      return false, "the untracked allowlist is invalid: " .. name
    end
  end

  for _, required in ipairs(spec.required_paths) do
    if not M.is_safe_relative_path(required.path) or path_metadata(required.path, required.type) ~= true then
      return false, "a required environment path is missing, unsafe, or has the wrong type: " .. required.path
    end
  end
  return true, manifest
end

function M.lock_error_is_retryable(error_value)
  return error_value == "EEXIST"
    or (
      type(error_value) == "string"
      and (error_value:match "^EEXIST" ~= nil or error_value:find("already exists", 1, true) ~= nil)
    )
end

function M.with_lifecycle_lock(filesystem, lock_path, callback, options)
  options = options or {}
  local deadline = filesystem.now() + (options.timeout_ns or 300000000000)
  while true do
    local created, lock_error = filesystem.mkdir(lock_path)
    if created then break end
    if not M.lock_error_is_retryable(lock_error) then
      error("Failed to acquire the test environment lock: " .. tostring(lock_error), 0)
    end
    local lock_entry = filesystem.lstat(lock_path)
    if entry_type(lock_entry) == "link" then error("Test environment lock is a symbolic link: " .. lock_path, 0) end
    if lock_entry and entry_type(lock_entry) ~= "directory" then
      error("Test environment lock is not a directory: " .. lock_path, 0)
    end
    if filesystem.now() >= deadline then error("Timed out waiting for the test environment lock: " .. lock_path, 0) end
    filesystem.wait(options.retry_delay_ms or 100)
  end
  local ok, result = xpcall(callback, debug.traceback)
  local released, release_error = filesystem.rmdir(lock_path)
  if not released then
    local message = "Failed to release the test environment lock: " .. tostring(release_error)
    if ok then error(message, 0) end
    result = result .. "\n" .. message
  end
  if not ok then error(result, 0) end
  return result
end

function M.remove_tree(filesystem, path)
  local function preflight(current, is_root)
    local entry = filesystem.lstat(current)
    if not entry then return true, false end
    local kind = entry_type(entry)
    if kind == "link" then return false, "refusing to remove a symbolic-link path: " .. current end
    if kind == "file" and not is_root then return true, true end
    if kind ~= "directory" then return false, "refusing to recursively remove a non-directory path: " .. current end
    local children, scan_error = filesystem.scandir(current)
    if not children then return false, "failed to scan " .. current .. ": " .. tostring(scan_error) end
    for _, name in ipairs(children) do
      local safe, error_message = preflight(current .. "/" .. name, false)
      if not safe then return false, error_message end
    end
    return true, true
  end
  local safe, exists_or_error = preflight(path, true)
  if not safe then return false, exists_or_error end
  if not exists_or_error then return true end

  local function remove(current)
    local children, scan_error = filesystem.scandir(current)
    if not children then return false, "failed to scan " .. current .. ": " .. tostring(scan_error) end
    for _, name in ipairs(children) do
      local child = current .. "/" .. name
      local entry = filesystem.lstat(child)
      local removed, remove_error
      if entry_type(entry) == "directory" then
        removed, remove_error = remove(child)
      else
        removed, remove_error = filesystem.unlink(child)
      end
      if not removed then return false, "failed to remove " .. child .. ": " .. tostring(remove_error) end
    end
    local removed, remove_error = filesystem.rmdir(current)
    if not removed then return false, "failed to remove " .. current .. ": " .. tostring(remove_error) end
    return true
  end
  return remove(path)
end

function M.clear_test_environment(filesystem, root, target)
  local paths = M.paths(root)
  target = target or paths.test_root
  if not M.is_clear_target(root, target) then
    error("Refusing to clear a non-canonical test environment path: " .. target, 0)
  end
  return M.with_lifecycle_lock(filesystem, paths.prepare_lock, function()
    if not filesystem.lstat(target) then return false end
    local removed, remove_error = M.remove_tree(filesystem, target)
    if not removed then error("Failed to clear test environment: " .. remove_error, 0) end
    return true
  end)
end

function M.can_publish_fresh(filesystem, staging_root, test_root)
  local staging = filesystem.lstat(staging_root)
  if entry_type(staging) == "link" then return false, "fresh staging environment is a symbolic link" end
  if entry_type(staging) ~= "directory" then return false, "fresh staging environment is missing" end
  local target = filesystem.lstat(test_root)
  if target then
    return false,
      entry_type(target) == "link" and "test environment target is a symbolic link"
        or "test environment target already exists"
  end
  return true
end

return M
