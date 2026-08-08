local MiniTest = require "mini.test"
local config = require "config"
local environment = require "test_environment"

local M = {}
local cases = setmetatable({}, { __mode = "k" })
local xdg_variables = { "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR" }
local deterministic_environment = { LC_ALL = "C", LANG = "C", TZ = "UTC", TERM = "xterm-256color" }

local function create_directory(path)
  if vim.fn.mkdir(path, "p", 448) ~= 0 and vim.fn.isdirectory(path) ~= 1 then
    error("Failed to create fixture directory: " .. path, 0)
  end
end

local function copy_tree(source, destination)
  local scanner, scan_error = vim.uv.fs_scandir(source)
  if not scanner then error("Failed to scan fixture source: " .. tostring(scan_error), 0) end
  create_directory(destination)
  while true do
    local name = vim.uv.fs_scandir_next(scanner)
    if not name then break end
    local source_path, destination_path = source .. "/" .. name, destination .. "/" .. name
    local entry = vim.uv.fs_lstat(source_path)
    if not entry or entry.type == "link" then error("Refusing to copy an unsafe fixture path: " .. source_path, 0) end
    if entry.type == "directory" then
      copy_tree(source_path, destination_path)
    elseif entry.type == "file" then
      local copied, copy_error = vim.uv.fs_copyfile(source_path, destination_path)
      if not copied then error("Failed to copy fixture file: " .. tostring(copy_error), 0) end
    else
      error("Refusing to copy an unsupported fixture path: " .. source_path, 0)
    end
  end
end

local function run(command, message, child_environment)
  local result = vim.system(command, { text = true, env = child_environment }):wait()
  if result.code ~= 0 then error(message .. ": " .. result.stderr, 0) end
end

local function git_environment(case)
  return vim.tbl_extend("force", vim.deepcopy(deterministic_environment), {
    GIT_CONFIG_NOSYSTEM = "1",
    GIT_CONFIG_GLOBAL = case.git_global,
    GIT_TEMPLATE_DIR = case.git_template,
    GIT_CONFIG_COUNT = "1",
    GIT_CONFIG_KEY_0 = "core.hooksPath",
    GIT_CONFIG_VALUE_0 = case.git_hooks,
    GIT_AUTHOR_NAME = "AstroCore Test",
    GIT_AUTHOR_EMAIL = "test@astrocore.local",
    GIT_COMMITTER_NAME = "AstroCore Test",
    GIT_COMMITTER_EMAIL = "test@astrocore.local",
    GIT_AUTHOR_DATE = "2000-01-01T00:00:00+00:00",
    GIT_COMMITTER_DATE = "2000-01-01T00:00:00+00:00",
  })
end

local function cleanup_root(root)
  local removed, remove_error = environment.remove_tree(config.filesystem(), root)
  if not removed then return "Failed to delete fixture root: " .. tostring(remove_error) end
end

local function make_case()
  local root = assert(vim.uv.fs_mkdtemp((vim.uv.os_tmpdir() or vim.fn.stdpath "cache") .. "/astrocore.XXXXXX"))
  local case = {
    root = root,
    config = root .. "/config",
    data = root .. "/data",
    state = root .. "/state",
    cache = root .. "/cache",
    runtime = root .. "/runtime",
    project = root .. "/project",
    git_global = root .. "/gitconfig",
    git_template = root .. "/git-template",
    git_hooks = root .. "/git-hooks",
  }
  local ok, error_message = xpcall(function()
    for _, path in ipairs {
      case.config,
      case.data,
      case.state,
      case.cache,
      case.runtime,
      case.git_template,
      case.git_hooks,
    } do
      create_directory(path)
    end
    assert(io.open(case.git_global, "wb")):close()
    copy_tree(config.fixture_project, case.project)
    local child_environment = git_environment(case)
    run(
      { "git", "init", "--template=" .. case.git_template, "--initial-branch=main", case.project },
      "Failed to initialize fixture Git repository",
      child_environment
    )
    run(
      { "git", "-C", case.project, "config", "commit.gpgsign", "false" },
      "Failed to disable fixture signing",
      child_environment
    )
    run({ "git", "-C", case.project, "add", "--all" }, "Failed to stage fixture project", child_environment)
    run(
      { "git", "-C", case.project, "commit", "--no-gpg-sign", "-m", "Initialize fixture" },
      "Failed to commit fixture project",
      child_environment
    )
  end, debug.traceback)
  if not ok then
    local cleanup_error = cleanup_root(root)
    error(error_message .. (cleanup_error and "\n" .. cleanup_error or ""), 0)
  end
  return case
end

local function child_job_id(child)
  local job = child and child.job
  return type(job) == "table" and job.id or job
end

local function job_is_alive(job_id) return type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1 end

local function parent_job_channels()
  local channels = {}
  for _, channel in ipairs(vim.api.nvim_list_chans()) do
    if job_is_alive(channel.id) then channels[channel.id] = true end
  end
  return channels
end

local function is_fixture_invocation(channel)
  for _, argument in ipairs(channel.argv or {}) do
    if argument == config.fixture_init then return true end
  end
  return false
end

local function stop_job(job_id)
  if not job_is_alive(job_id) then return end
  pcall(vim.fn.jobstop, job_id)
  pcall(vim.fn.jobwait, { job_id }, 1000)
  if job_is_alive(job_id) then return "Child Neovim process survived shutdown: " .. job_id end
end

local function with_environment(values, callback)
  local previous = {}
  for name, value in pairs(values) do
    previous[name] = { value = vim.uv.os_getenv(name) }
    vim.env[name] = value
  end
  local ok, result = xpcall(callback, debug.traceback)
  for name, snapshot in pairs(previous) do
    vim.env[name] = snapshot.value
  end
  if not ok then error(result, 0) end
  return result
end

function M.start_child(overrides)
  local case = make_case()
  local child = MiniTest.new_child_neovim()
  local existing_channels = parent_job_channels()
  cases[child] = case
  local child_environment = vim.tbl_extend("force", {}, deterministic_environment, git_environment(case), {
    XDG_CONFIG_HOME = case.config,
    XDG_DATA_HOME = case.data,
    XDG_STATE_HOME = case.state,
    XDG_CACHE_HOME = case.cache,
    XDG_RUNTIME_DIR = case.runtime,
    ASTROCORE_TEST_ROOT = config.root,
    ASTROCORE_TEST_LAZY_PATH = config.lazy_path,
    ASTROCORE_TEST_PLUGIN_ROOT = config.plugin_root,
    ASTROCORE_TEST_LOCKFILE = config.lockfile,
    ASTROCORE_TEST_LUA_DIR = config.test_lua_dir,
  }, overrides or {})
  local ok, error_message = xpcall(function()
    with_environment(
      child_environment,
      function() child.start { "--cmd", "cd " .. vim.fn.fnameescape(case.project), "-u", config.fixture_init } end
    )
  end, debug.traceback)
  if not ok then
    local cleanup_errors = {}
    local stopped, stop_error = pcall(child.stop, child)
    if not stopped then table.insert(cleanup_errors, tostring(stop_error)) end
    local jobs = {}
    local child_job = child_job_id(child)
    if child_job then jobs[child_job] = true end
    for _, channel in ipairs(vim.api.nvim_list_chans()) do
      if not existing_channels[channel.id] and is_fixture_invocation(channel) then jobs[channel.id] = true end
    end
    for job_id in pairs(jobs) do
      local job_error = stop_job(job_id)
      if job_error then table.insert(cleanup_errors, job_error) end
    end
    cases[child] = nil
    local cleanup_error = cleanup_root(case.root)
    if cleanup_error then table.insert(cleanup_errors, cleanup_error) end
    error(error_message .. (#cleanup_errors > 0 and "\n" .. table.concat(cleanup_errors, "\n") or ""), 0)
  end
  return child
end

function M.wait_until(child, expression, description, timeout)
  local ready = vim.wait(timeout or config.wait_timeout, function()
    local ok, value = pcall(child.lua_get, expression)
    return ok and value == true
  end, 20)
  assert(ready, "Timed out waiting for " .. description)
end

function M.stop_child(child)
  if not child then return end
  local case = cases[child]
  local failures = {}
  local job_id = child_job_id(child)
  local running_ok, running = pcall(child.is_running, child)
  if running_ok and running then
    local stopped, stop_error = pcall(child.stop, child)
    if not stopped then table.insert(failures, tostring(stop_error)) end
  end
  local job_error = stop_job(job_id)
  if job_error then table.insert(failures, job_error) end
  cases[child] = nil
  if case then
    local cleanup_error = cleanup_root(case.root)
    if cleanup_error then table.insert(failures, cleanup_error) end
  end
  if #failures > 0 then error(table.concat(failures, "\n"), 0) end
end

function M.fixture_project(child)
  local case = assert(cases[child], "Child fixture is unavailable")
  return case.project
end

function M.fixture_root(child)
  local case = assert(cases[child], "Child fixture is unavailable")
  return case.root
end

function M.child_job_id(child) return child_job_id(child) end

function M.parent_xdg_environment()
  local snapshot = {}
  for _, name in ipairs(xdg_variables) do
    snapshot[name] = vim.uv.os_getenv(name)
  end
  return snapshot
end

function M.restore_parent_xdg_environment(snapshot)
  for _, name in ipairs(xdg_variables) do
    vim.env[name] = snapshot[name]
  end
end

return M
