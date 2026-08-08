local environment = require "test_environment"
local spec = require "environment_spec"

local M = {}

local function normalize(path) return vim.fs.normalize(path):gsub("/$", "") end

local function canonical(path)
  local resolved = vim.uv.fs_realpath(path)
  if not resolved then error("Failed to resolve the repository root: " .. path, 0) end
  return normalize(resolved)
end

local source = debug.getinfo(1, "S").source:sub(2)
M.root = canonical(vim.fs.dirname(vim.fs.dirname(source)))
M.environment_schema = environment.schema
M.fingerprint = environment.expected_fingerprint
M.fixture_init = M.root .. "/tests/fixtures/init.lua"
M.fixture_project = M.root .. "/tests/fixtures/project"
M.wait_timeout = 15000

function M.paths_for_test_root(test_root) return environment.paths_for_test_root(normalize(test_root)) end
function M.paths_for(root) return environment.paths(normalize(root)) end

for name, value in pairs(M.paths_for(M.root)) do
  if name ~= "root" then M[name] = value end
end

local function filesystem()
  return {
    lstat = vim.uv.fs_lstat,
    mkdir = function(path) return vim.uv.fs_mkdir(path, 448) end,
    rmdir = vim.uv.fs_rmdir,
    unlink = vim.uv.fs_unlink,
    scandir = function(path)
      local scanner, scan_error = vim.uv.fs_scandir(path)
      if not scanner then return nil, scan_error end
      local names = {}
      while true do
        local name = vim.uv.fs_scandir_next(scanner)
        if not name then break end
        table.insert(names, name)
      end
      return names
    end,
    now = vim.uv.hrtime,
    wait = vim.wait,
  }
end

function M.filesystem() return filesystem() end

local function read_json(path)
  local file, open_error = io.open(path, "rb")
  if not file then return nil, open_error end
  local contents = file:read "*a"
  file:close()
  local ok, decoded = pcall(vim.json.decode, contents)
  if not ok then return nil, decoded end
  return decoded
end

local function read_file(path)
  local file, open_error = io.open(path, "rb")
  if not file then return nil, open_error end
  local contents = file:read "*a"
  file:close()
  return contents
end

local function safe_path(test_root, relative_path, expected_type)
  if not environment.is_safe_relative_path(relative_path) then return false end
  return environment.has_safe_path_type(M.root, test_root .. "/" .. relative_path, expected_type, vim.uv.fs_lstat)
end

local function git(arguments)
  return vim.system(vim.list_extend({ "env", "GIT_OPTIONAL_LOCKS=0", "git" }, arguments), { text = true }):wait()
end

local function validate_repository(test_root, relative_path, expected_commit, allowed_untracked)
  if not safe_path(test_root, relative_path, "directory") then
    return false, "repository path is missing or unsafe: " .. relative_path
  end
  local path = test_root .. "/" .. relative_path
  local revision = git { "-C", path, "rev-parse", "HEAD" }
  if revision.code ~= 0 or vim.trim(revision.stdout) ~= expected_commit then
    return false, "repository HEAD does not match: " .. relative_path
  end

  local allowed = {}
  for _, path_name in ipairs(allowed_untracked or {}) do
    allowed[path_name] = true
  end
  local status = git { "-C", path, "status", "--porcelain", "--untracked-files=all", "--ignored=matching" }
  if status.code ~= 0 then return false, "cannot read repository status: " .. relative_path end
  for line in status.stdout:gmatch "[^\n]+" do
    local status_code = line:sub(1, 2)
    if (status_code ~= "??" and status_code ~= "!!") or not allowed[line:sub(4)] then
      return false, "repository has tracked changes or disallowed untracked files: " .. relative_path
    end
  end
  return true
end

local function validate_copied_libraries(test_root, manifest)
  for _, library in ipairs(spec.copied_libraries) do
    local actual = manifest.copied_libraries[library.name]
    local expected_destinations = {}
    for _, file in ipairs(library.files) do
      expected_destinations[file.destination] = true
    end

    for destination, expected_hash in pairs(actual.files) do
      if not expected_destinations[destination] or not environment.is_safe_relative_path(destination) then
        return false, "copied-library manifest contains an unexpected file: " .. library.name
      end
      local path = test_root .. "/" .. actual.destination_root .. "/" .. destination
      if not environment.has_safe_path_type(M.root, path, "file", vim.uv.fs_lstat) then
        return false, "copied-library file is missing or unsafe: " .. library.name .. "/" .. destination
      end
      local contents, read_error = read_file(path)
      if not contents or vim.fn.sha256(contents):lower() ~= expected_hash then
        return false,
          "copied-library checksum does not match: " .. library.name .. "/" .. destination .. ": " .. tostring(
            read_error
          )
      end
    end

    local function scan(current, prefix)
      local scanner, scan_error = vim.uv.fs_scandir(current)
      if not scanner then return false, scan_error end
      while true do
        local name, entry_type = vim.uv.fs_scandir_next(scanner)
        if not name then break end
        local relative = prefix == "" and name or prefix .. "/" .. name
        local path = current .. "/" .. name
        if entry_type == "link" then
          return false, "copied-library path is a symbolic link: " .. library.name .. "/" .. relative
        end
        if entry_type == "directory" then
          local ok, scan_error_message = scan(path, relative)
          if not ok then return false, scan_error_message end
        elseif entry_type ~= "file" or not actual.files[relative] then
          return false, "copied-library root contains an unexpected file: " .. library.name .. "/" .. relative
        end
      end
      return true
    end
    local scanned, scan_error = scan(test_root .. "/" .. actual.destination_root, "")
    if not scanned then return false, scan_error end
  end
  return true
end

function M.validate_ready_at(test_root)
  test_root = normalize(test_root)
  local paths = environment.paths_for_test_root(test_root)
  for _, path in ipairs { paths.ready, paths.manifest, paths.lockfile } do
    if not environment.has_safe_path_type(M.root, path, "file", vim.uv.fs_lstat) then
      return false, "required lifecycle file is missing or unsafe: " .. path
    end
  end
  local marker, marker_error = read_json(paths.ready)
  if not marker then return false, "cannot read .ready: " .. tostring(marker_error) end
  local manifest, manifest_error = read_json(paths.manifest)
  if not manifest then return false, "cannot read manifest.json: " .. tostring(manifest_error) end
  local lock, lock_error = read_json(paths.lockfile)
  if not lock then return false, "cannot read lazy-lock.json: " .. tostring(lock_error) end

  local valid, result = environment.validate_ready(
    marker,
    manifest,
    lock,
    function(relative_path, expected_type) return safe_path(test_root, relative_path, expected_type) end
  )
  if not valid then return false, result end

  local lazy_valid, lazy_error =
    validate_repository(test_root, result.lazy.path, result.lazy.commit, result.untracked_allowlists[spec.lazy.name])
  if not lazy_valid then return false, lazy_error end
  for _, dependency in ipairs(spec.dependencies) do
    local plugin = result.plugins[dependency.name]
    local repository_valid, repository_error =
      validate_repository(test_root, plugin.path, plugin.commit, result.untracked_allowlists[dependency.name])
    if not repository_valid then return false, repository_error end
  end
  return validate_copied_libraries(test_root, result)
end

function M.classify_environment() return environment.classify(M, vim.uv.fs_lstat) end

function M.validate_ready_environment() return M.validate_ready_at(M.test_root) end

function M.assert_ready_environment()
  local valid, message = M.validate_ready_environment()
  if not valid then
    error("Test environment is incomplete or incompatible. Run `make test-clear` then retry: " .. message, 0)
  end
end

function M.assert_staging_path(path)
  if not environment.is_staging_target(M.root, normalize(path)) then
    error("Refusing to modify a non-canonical test staging path", 0)
  end
end

return M
