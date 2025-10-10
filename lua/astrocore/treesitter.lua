---AstroNvim Treesitter Utilities
---
---Utilities necessary for configuring treesitter in Neovim
---
---This module can be loaded with `local astrocore_treesitter = require "astrocore.treesitter"`
---
---copyright 2025
---license GNU General Public License v3.0
---@class astrocore.treesitter
local M = {}

---@type AstroCoreTreesitterOpts
local config = {}

local available
local installed = {}
local queries = {}

--- Get list of treesitter parsers installed with `nvim-treesitter`
---@param update boolean? whether or not to refresh installed parsers
---@return string[] # the list of installed parsers
function M.installed(update)
  if update then
    local treesitter_avail, treesitter = pcall(require, "nvim-treesitter")
    if treesitter_avail then
      installed, queries = {}, {}
      for _, lang in ipairs(treesitter.get_installed "parsers") do
        installed[lang] = true
      end
    end
  end
  return installed
end

-- Get list of available treesitter parers in `nvim-treesitter`
function M.available()
  if available == nil then
    available = {}
    local treesitter_avail, treesitter = pcall(require, "nvim-treesitter")
    if treesitter_avail then
      for _, parser in ipairs(treesitter.get_available()) do
        available[parser] = true
      end
    end
  end
  return available
end

--- Install the provided parsers with `nvim-treesitter`
---@param languages? "auto"|"all"|string[] a list of languages to install, automatically detect the current language to install, or install all available parsers (default: "auto")
---@param cb? function optional callback function to execute after installation finishes
function M.install(languages, cb)
  local patch_func = require("astrocore").patch_func
  cb = patch_func(cb, function() M.installed(true) end)
  local treesitter_avail, treesitter = pcall(require, "nvim-treesitter")
  if not treesitter_avail then return end
  if not languages or languages == "auto" then
    local bufnr = vim.api.nvim_get_current_buf()
    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if M.available()[lang] then
      cb = patch_func(cb, function() M.enable(bufnr) end)
      languages = { lang }
    else
      languages = {}
    end
  elseif languages == "all" then
    languages = treesitter.get_available()
  end
  if
    next(languages --[[ @as string[] ]])
  then
    treesitter.install(languages, { summary = true }):await(function()
      if cb then cb() end
      M.installed(true)
    end)
  end
end

--- Check if query is supported for given treesitter parser language
---@param lang string the parser language to check against
---@param query string the query type to check for support of
---@return boolean # whether or not a query is supported by the given parser
function M.has_query(lang, query)
  local key = lang .. ":" .. query
  if queries[key] == nil then queries[key] = vim.treesitter.query.get(lang, query) ~= nil end
  return queries[key]
end

--- Check if parser exists for filetype with optional query check
---@param filetype? string|integer the filetype to check or a buffer number to get the filetype of (defaults to current buffer)
---@param query? string the query type to check for support of
---@return boolean
function M.has_parser(filetype, query)
  if not filetype then filetype = vim.api.nvim_get_current_buf() end
  if type(filetype) == "number" then filetype = vim.bo[filetype].filetype end
  local lang = vim.treesitter.language.get_lang(filetype --[[ @as string ]])
  if not lang or not M.installed()[lang] then return false end
  if query and not M.has_query(lang, query) then return false end
  return true
end

--- Initialize treesitter configuration
---@param opts AstroCoreTreesitterOpts
function M.setup(opts)
  local astrocore = require "astrocore"
  config = astrocore.extend_tbl(config, opts) --[[ @as AstroCoreTreesitterOpts ]]
  astrocore.on_load("nvim-treesitter", function() M.installed(true) end)
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("astrocore_treesitter", { clear = true }),
    callback = function(args)
      if not M.has_parser(args.match) then
        if config.ensure_installed == "auto" then M.install() end
      else
        M.enable(args.buf)
      end
    end,
  })
end

--- Enable treesitter features in buffer
---@param bufnr integer the buffer to enable treesitter in
function M.enable(bufnr)
  local ft = vim.bo[bufnr].filetype
  local lang = vim.treesitter.language.get_lang(ft)
  if not M.has_parser(ft) or not lang then return end

  ---@param feat string
  ---@param query string
  local function is_enabled(feat, query)
    local enabled = config[feat] ---@type AstroCoreTreesitterFeature?
    if type(enabled) == "table" then
      enabled = vim.tbl_contains(enabled, lang)
    elseif type(enabled) == "function" then
      enabled = enabled(lang, bufnr)
    end
    return enabled and M.has_parser(ft, query)
  end

  -- highlighting
  if is_enabled("highlight", "highlights") then pcall(vim.treesitter.start, bufnr) end

  -- indents
  -- FIX: fix to only run if indenexpr is not set by a plugin
  if is_enabled("indent", "indents") then vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
end

return M
