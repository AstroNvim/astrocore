local tests_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
package.path = tests_dir .. "/?.lua;" .. package.path

local config = require "config"
local environment = require "test_environment"
local spec = require "environment_spec"

local function run(command)
  local result = vim.system(command, { text = true }):wait()
  if result.code ~= 0 then
    error(("Command failed (%d): %s\n%s"):format(result.code, table.concat(command, " "), result.stderr), 0)
  end
  return result
end

local function ensure_directory(path)
  local entry = vim.uv.fs_lstat(path)
  if entry then
    if entry.type ~= "directory" then error("Refusing to use a non-directory path: " .. path, 0) end
    return
  end
  local created, create_error = vim.uv.fs_mkdir(path, 448)
  if not created then error("Failed to create directory " .. path .. ": " .. tostring(create_error), 0) end
end

local function ensure_parent(path) ensure_directory(vim.fs.dirname(path)) end

local function write_json_atomic(path, value)
  local temporary = path .. ".tmp." .. tostring(vim.uv.hrtime())
  if vim.uv.fs_lstat(temporary) then error("Temporary lifecycle path already exists: " .. temporary, 0) end
  local file = assert(io.open(temporary, "wb"))
  assert(file:write(vim.json.encode(value)))
  file:close()
  if not vim.uv.fs_rename(temporary, path) then
    vim.uv.fs_unlink(temporary)
    error("Failed to atomically publish " .. path, 0)
  end
end

local function read_json(path)
  local file = assert(io.open(path, "rb"))
  local contents = assert(file:read "*a")
  file:close()
  return vim.json.decode(contents)
end

local function remove_staging()
  config.assert_staging_path(config.staging_root)
  local removed, remove_error = environment.remove_tree(config.filesystem(), config.staging_root)
  if not removed then error("Failed to remove test staging path: " .. remove_error, 0) end
end

local function test_spec()
  local plugins = {}
  for _, dependency in ipairs(spec.dependencies) do
    table.insert(plugins, { dependency.url, name = dependency.name, branch = dependency.branch })
  end
  return plugins
end

local function setup_lazy(paths)
  vim.o.loadplugins = true
  vim.env.LAZY = paths.lazy_path
  vim.opt.rtp:prepend(paths.lazy_path)
  require("lazy").setup {
    root = paths.plugin_root,
    lockfile = paths.lockfile,
    local_spec = false,
    spec = test_spec(),
    install = { missing = false },
    checker = { enabled = false },
    change_detection = { enabled = false },
    git = { cooldown = 0 },
    pkg = { enabled = false },
    rocks = { enabled = false },
    headless = { process = true, log = true, task = true, colors = false },
    performance = { cache = { enabled = false } },
  }
end

local function inspect_repository(path)
  local entry = vim.uv.fs_lstat(path)
  if not entry or entry.type ~= "directory" then return nil, "repository is missing or is not a directory" end
  local revision = vim
    .system({ "env", "GIT_OPTIONAL_LOCKS=0", "git", "-C", path, "rev-parse", "HEAD" }, { text = true })
    :wait()
  if revision.code ~= 0 then return nil, "cannot read repository HEAD" end
  local status = vim
    .system(
      { "env", "GIT_OPTIONAL_LOCKS=0", "git", "-C", path, "status", "--porcelain", "--untracked-files=no" },
      { text = true }
    )
    :wait()
  if status.code ~= 0 or status.stdout ~= "" then return nil, "repository has tracked modifications" end
  local commit = vim.trim(revision.stdout)
  if #commit ~= 40 or commit:match "^[0-9a-f]+$" == nil then
    return nil, "repository HEAD is not a full lowercase commit"
  end
  return commit
end

local function assert_lazy_success()
  local Plugin = require "lazy.core.plugin"
  local failures = {}
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    if Plugin.has_errors(plugin) then table.insert(failures, name) end
  end
  table.sort(failures)
  if #failures > 0 then error("Lazy dependency installation failed: " .. table.concat(failures, ", "), 0) end
end

local function copy_libraries(paths)
  local copied = {}
  for _, library in ipairs(spec.copied_libraries) do
    local files = {}
    for _, item in ipairs(library.files) do
      local source = paths.root .. "/" .. library.source_root .. "/" .. item.source
      local destination = paths.root .. "/" .. library.destination_root .. "/" .. item.destination
      ensure_parent(destination)
      if vim.uv.fs_lstat(destination) then error("Copied-library destination already exists: " .. destination, 0) end
      local source_file = assert(io.open(source, "rb"))
      local source_contents = assert(source_file:read "*a")
      source_file:close()
      local copied_file, copy_error = vim.uv.fs_copyfile(source, destination)
      if not copied_file then error("Failed to copy " .. source .. ": " .. tostring(copy_error), 0) end
      local destination_file = assert(io.open(destination, "rb"))
      local destination_contents = assert(destination_file:read "*a")
      destination_file:close()
      if source_contents ~= destination_contents then
        error("Copied-library bytes differ after copy: " .. item.destination, 0)
      end
      files[item.destination] = vim.fn.sha256(destination_contents):lower()
    end
    copied[library.name] = {
      source_root = library.source_root,
      destination_root = library.destination_root,
      files = files,
    }
  end
  return copied
end

local function manifest_for(paths, lock, copied_libraries)
  local lazy_commit, lazy_error = inspect_repository(paths.lazy_path)
  if not lazy_commit then error("lazy.nvim validation failed: " .. lazy_error, 0) end
  local plugins = {}
  for _, dependency in ipairs(spec.dependencies) do
    local path = paths.plugin_root .. "/" .. dependency.name
    local commit, commit_error = inspect_repository(path)
    if not commit then error(dependency.name .. " validation failed: " .. commit_error, 0) end
    plugins[dependency.name] = { path = "data/nvim/lazy/" .. dependency.name, commit = commit }
  end
  return {
    schema = environment.schema,
    fingerprint = environment.expected_fingerprint,
    lockfile = "lazy-lock.json",
    lazy = { path = "lazy.nvim", commit = lazy_commit },
    plugin_root = "data/nvim/lazy",
    test_lua_dir = "lua",
    plugins = plugins,
    lock_plugins = vim.deepcopy(spec.lock_plugins),
    copied_libraries = copied_libraries,
    untracked_allowlists = vim.deepcopy(spec.untracked_allowlists),
  },
    lock
end

local function create_fresh_environment()
  remove_staging()
  if vim.uv.fs_lstat(config.test_root) then
    error("Test environment target already exists. Run `make test-clear` then retry.", 0)
  end

  local paths = config.paths_for_test_root(config.staging_root)
  ensure_directory(paths.root)
  ensure_directory(paths.root .. "/data")
  ensure_directory(paths.root .. "/data/nvim")
  ensure_directory(paths.plugin_root)
  ensure_directory(paths.test_lua_dir)
  ensure_directory(paths.state_dir)
  ensure_directory(paths.cache_dir)

  vim.env.LAZY_OFFLINE = nil
  run {
    "git",
    "clone",
    "--depth=1",
    "--filter=blob:none",
    "--branch=" .. spec.lazy.branch,
    spec.lazy.url,
    paths.lazy_path,
  }
  setup_lazy(paths)
  require("lazy").sync { wait = true, show = false }
  assert_lazy_success()

  local lock = read_json(paths.lockfile)
  local copied_libraries = copy_libraries(paths)
  local manifest = manifest_for(paths, lock, copied_libraries)
  write_json_atomic(paths.manifest, manifest)
  write_json_atomic(paths.ready, {
    schema = environment.schema,
    fingerprint = environment.expected_fingerprint,
    manifest = "manifest.json",
    lockfile = "lazy-lock.json",
  })

  local valid, validation_error = config.validate_ready_at(paths.root)
  if not valid then error("Generated test environment is invalid: " .. validation_error, 0) end
  local publishable, publish_error = environment.can_publish_fresh(config.filesystem(), paths.root, config.test_root)
  if not publishable then error("Failed to atomically publish test environment: " .. publish_error, 0) end
  if not vim.uv.fs_rename(paths.root, config.test_root) then
    error("Failed to atomically publish test environment", 0)
  end
end

environment.with_lifecycle_lock(config.filesystem(), config.prepare_lock, function()
  local state = config.classify_environment()
  if state == "marked" then
    vim.env.LAZY_OFFLINE = "1"
    local valid, validation_error = config.validate_ready_environment()
    if not valid then
      error("Test environment is incomplete or incompatible. Run `make test-clear` then retry: " .. validation_error, 0)
    end
    return
  end
  if state ~= "missing" then
    error("Test environment is incomplete or incompatible. Run `make test-clear` then retry.", 0)
  end

  local ok, error_message = xpcall(create_fresh_environment, debug.traceback)
  if not ok then
    local cleanup_ok, cleanup_error = pcall(remove_staging)
    if not cleanup_ok then error_message = error_message .. "\nFailed staging cleanup: " .. tostring(cleanup_error) end
    error(error_message, 0)
  end
end)
