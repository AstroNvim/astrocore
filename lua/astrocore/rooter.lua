---AstroNvim Rooter
---
---Utilities necessary for automatic root detectoin
---
---This module is heavily inspired by LazyVim and project.nvim
---https://github.com/ahmedkhalf/project.nvim
---https://github.com/LazyVim/LazyVim/blob/98db7ec0d287adcd8eaf6a93c4a392f588b5615a/lua/lazyvim/util/root.lua
---
---This module can be loaded with `local rooter = require "astrocore.rooter"`
---
---copyright 2023
---license GNU General Public License v3.0
---@class astrocore.rooter
local M = { detectors = {} }

---@alias AstroCoreRooterDetectorFunc fun(bufnr: integer,...): string[]
---@alias AstroCoreRooterDetector fun(config:AstroCoreRooterOpts?):AstroCoreRooterDetectorFunc

---@class AstroCoreRooterDetectors
---@type table<string, AstroCoreRooterDetector>
M.detectors = {}

local vim_autochdir

local function notify(msg, level)
  require("astrocore").notify(msg, level or vim.log.levels.INFO, { title = "AstroNvim Rooter" })
end

local function resolve_config() return require("astrocore").config.rooter or {} end

--- Create a detect workspace folders from active language servers
---@param config? AstroCoreRooterOpts a rooter configuration (defaults to global configuration)
---@return AstroCoreRooterDetectorFunc
function M.detectors.lsp(config)
  if not config then config = resolve_config() end
  ---@type (string[]|fun(client:vim.lsp.Client):boolean)?
  local server_filter = vim.tbl_get(config, "ignore", "servers")
  if server_filter and type(server_filter) ~= "function" then
    local ignore_servers = server_filter
    server_filter = function(lsp_client) return vim.tbl_contains(ignore_servers, lsp_client.name) end
  end
  return function(bufnr)
    local bufpath = M.bufpath(bufnr)
    if not bufpath then return {} end
    local roots = {} ---@type string[]
    for _, client in ipairs(vim.lsp.get_clients { buffer = bufnr }) do
      if not server_filter or not server_filter(client) then
        if client.root_dir then table.insert(roots, client.root_dir) end
        vim.tbl_map(
          function(ws) table.insert(roots, vim.uri_to_fname(ws.uri)) end,
          client.config.workspace_folders or {}
        )
      end
    end
    local found_lsp_roots = {}
    return vim.tbl_filter(function(path)
      path = M.normpath(path)
      if path and bufpath:find(path, 1, true) == 1 then
        if not found_lsp_roots[path] then
          found_lsp_roots[path] = true
          return true
        end
      end
      return false
    end, roots)
  end
end

--- Create a detect folders matching patterns
---@return AstroCoreRooterDetectorFunc
function M.detectors.pattern()
  return function(bufnr, patterns)
    if type(patterns) == "string" then patterns = { patterns } end
    local path = M.bufpath(bufnr) or vim.loop.cwd()
    if not path then return {} end
    local pattern = M.exists(path) and vim.fs.find(patterns, { path = path, upward = true })[1]
    return pattern and { vim.fs.dirname(pattern) } or {}
  end
end

---@class AstroCoreRooterRoot
---@field paths string[]
---@field spec AstroCoreRooterSpec

--- Get the real path of a buffer
---@param bufnr integer the buffer
---@return string? path the real path
function M.bufpath(bufnr) return M.realpath(vim.api.nvim_buf_get_name(bufnr)) end

--- Resolve a given path
---@param path? string the path to resolve
---@return string? the resolved path
function M.realpath(path)
  if not path or path == "" then return nil end
  return M.normpath(vim.uv.fs_realpath(path) or path)
end

--- Check if a path exists
---@param path string the path
---@return boolean exists whether or not the path exists
function M.exists(path) return vim.uv.fs_stat(path) ~= nil end

--- Normalize path
---@param path string
---@return string
function M.normpath(path)
  if path:sub(1, 1) == "~" then
    local home = assert(vim.loop.os_homedir())
    if home:sub(-1) == "\\" or home:sub(-1) == "/" then home = home:sub(1, -2) end
    path = home .. path:sub(2)
  end
  path = path:gsub("\\", "/"):gsub("/+", "/")
  return (path:sub(-1) == "/" and path ~= "/") and path:sub(1, -2) or path
end

--- Resolve the root detection function for a given spec
---@param spec AstroCoreRooterSpec the root detector specification
---@param config? AstroCoreRooterOpts the root configuration
---@return function
function M.resolve(spec, config)
  if M.detectors[spec] then
    return M.detectors[spec](config)
  elseif type(spec) == "function" then
    return spec
  end
  local pattern_detector = M.detectors.pattern(config)
  return function(bufnr) return pattern_detector(bufnr, spec) end
end

--- Detect roots in a given buffer
---@param bufnr? integer the buffer to detect
---@param all? boolean whether to return all roots or just one
---@param config? AstroCoreRooterOpts a rooter configuration (defaults to global configuration)
---@return AstroCoreRooterRoot[] detected roots
function M.detect(bufnr, all, config)
  if not config then config = resolve_config() end
  local ret = {}
  if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  if not require("astrocore.buffer").is_valid(bufnr) then return ret end

  local path = M.bufpath(bufnr)
  if path and M.is_excluded(path) then return ret end

  for _, spec in ipairs(config.detector or {}) do
    local paths = M.resolve(spec, config)(bufnr)
    if not paths then
      paths = {}
    elseif type(paths) ~= "table" then
      paths = { paths }
    end
    local roots = {} ---@type string[]
    for _, p in ipairs(paths) do
      local pp = M.realpath(p)
      if pp and not vim.tbl_contains(roots, pp) then roots[#roots + 1] = pp end
    end
    table.sort(roots, function(a, b) return #a > #b end)
    if #roots > 0 then
      table.insert(ret, { spec = spec, paths = roots })
      if not all then break end
    end
  end
  return ret
end

--- Get information information about the current root
---@param config? AstroCoreRooterOpts a rooter configuration (defaults to global configuration)
function M.info(config)
  if not config then config = resolve_config() end
  local lines = {}
  if vim_autochdir then
    table.insert(lines, "Rooting disabled when `autochdir` is set")
  else
    local roots = M.detect(0, true, config)
    local first = true
    for _, root in ipairs(roots) do
      for _, path in ipairs(root.paths) do
        local surround = first and "**" or ""
        table.insert(
          lines,
          ("%s`%s` *(%s*)%s"):format(
            surround,
            path,
            type(root.spec) == "table" and table.concat(root.spec --[=[@as string[]]=], ", ") or root.spec,
            surround
          )
        )
        first = false
      end
    end
    table.insert(lines, "```lua")
    if config.detector then table.insert(lines, "detector = " .. vim.inspect(config.detector)) end
    if config.ignore then
      for _, type in ipairs { "dirs", "servers" } do
        local spec = config.ignore[type]
        if spec then table.insert(lines, "ignore." .. type .. " = " .. vim.inspect(spec)) end
      end
    end
    for _, key in ipairs { "scope", "autochdir", "notify" } do
      local setting = config[key]
      if setting then table.insert(lines, key .. " = " .. vim.inspect(setting)) end
    end
    table.insert(lines, "```")
  end
  notify(table.concat(lines, "\n"))
end

--- Set the current directory to a given root
---@param root AstroCoreRooterRoot the root to set the pwd to
---@param config? AstroCoreRooterOpts a rooter configuration (defaults to global configuration)
---@return boolean success whether or not the pwd was successfully set
function M.set_pwd(root, config)
  if not config then config = resolve_config() end
  local path = root.paths[1]
  if path ~= nil then
    if vim.fn.has "win32" > 0 then path = path:gsub("\\", "/") end
    if vim.fn.getcwd() ~= path then
      if config.scope == "global" then
        vim.api.nvim_set_current_dir(path)
      elseif config.scope == "tab" then
        vim.cmd.tchdir(path)
      elseif config.scope == "win" then
        vim.cmd.lchdir(path)
      else
        vim.api.nvim_err_writeln(("Unable to parse scope: %s"):format(config.scope))
      end

      if config.notify then notify(("Set CWD to `%s`"):format(path)) end
    end
    return true
  end

  return false
end

--- Check if a path is excluded
---@param path string the path
---@param config? AstroCoreRooterOpts a rooter configuration (defaults to global configuration)
---@return boolean excluded whether or not the path is excluded
function M.is_excluded(path, config)
  if not config then config = resolve_config() end
  for _, path_pattern in ipairs(vim.tbl_get(config, "ignore", "dirs") or {}) do
    if path:match(M.normpath(path_pattern)) then return true end
  end
  return false
end

--- Run the root detection and set the current working directory if a new root is detected
---@param bufnr? integer the buffer to detect
---@param config? AstroCoreRooterOpts a rooter configuration (defaults to global configuration)
function M.root(bufnr, config)
  -- add `autochdir` protection
  local autochdir = vim.opt.autochdir:get()
  if not vim_autochdir and autochdir then
    notify("Rooting disabled, unset `autochdir` to re-enable", vim.log.levels.WARN)
    vim_autochdir = true
  elseif vim_autochdir and not autochdir then
    vim_autochdir = false
  end

  if vim_autochdir or vim.v.vim_did_enter == 0 then return end

  if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  if not config then config = resolve_config() end
  local root = M.detect(bufnr, false, config)[1]
  if root then M.set_pwd(root, config) end
end

return M
