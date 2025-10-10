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
local captures = {}

local enabled = {}
local indentexprs = {}

-- Configure the keymap modes for each textobject type
M.textobject_modes = {
  select = { "x", "o" },
  swap = { "n" },
  move = { "n", "x", "o" },
}

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
---@param languages? "all"|string[] a list of languages to install, automatically detect the current language to install, or install all available parsers (default: "auto")
---@param cb? function optional callback function to execute after installation finishes
function M.install(languages, cb)
  local patch_func = require("astrocore").patch_func
  local treesitter_avail, treesitter = pcall(require, "nvim-treesitter")
  if not treesitter_avail then return end
  if not languages then
    local bufnr = vim.api.nvim_get_current_buf()
    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if M.available()[lang] then
      cb = patch_func(cb, function(orig)
        M.enable(bufnr)
        orig()
      end)
      languages = { lang }
    else
      languages = {}
    end
  elseif languages == "all" then
    languages = treesitter.get_available()
  end
  languages = vim.tbl_filter(function(lang) return not M.has_parser(lang) end, languages --[[ @as string[] ]])
  if
    next(languages --[[ @as string[] ]])
  then
    cb = patch_func(cb, function(orig)
      M.installed(true)
      orig()
    end)
    treesitter.install(languages, { summary = true }):await(cb)
  end
end

--- Check if capture is supported for given treesitter parser language
---@param lang string the parser language to check against
---@param query string the query type to check for support of
---@param capture string the capture type to check for support of
---@return boolean # whether or not a query is supported by the given parser
function M.has_capture(lang, query, capture)
  local key = lang .. ":" .. query
  if captures[key] == nil then
    captures[key] = {}
    local found_captures = (vim.treesitter.query.get(lang, query) or {}).captures
    for _, found_capture in ipairs(found_captures or {}) do
      captures[key][found_capture] = true
    end
  end
  return captures[key][capture] == true
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

local function _setup()
  require("astrocore").on_load("nvim-treesitter", function()
    M.installed(true)
    M.install(config.ensure_installed)
  end)

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("astrocore_treesitter", { clear = true }),
    callback = function(args)
      local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
      if not lang then return end
      local disabled = config.disabled
      if type(disabled) == "function" then disabled = disabled(lang, args.buf) end
      if disabled then
        pcall(vim.treesitter.stop, args.buf) -- force disabling treesitter for built in languages
        return
      end
      if not M.has_parser(args.match) then
        if config.auto_install then M.install() end
      else
        M.enable(args.buf)
      end
    end,
  })
end

--- Initialize treesitter configuration
---@param opts AstroCoreTreesitterOpts
function M.setup(opts)
  local astrocore = require "astrocore"
  config = astrocore.extend_tbl(config, opts) --[[ @as AstroCoreTreesitterOpts ]]

  if vim.fn.executable "tree-sitter" ~= 1 then
    if pcall(require, "mason") and vim.fn.executable "tree-sitter" ~= 1 then
      local mr = require "mason-registry"
      mr.refresh(function()
        local p = mr.get_package "tree-sitter-cli"
        if not p:is_installed() then
          astrocore.notify "Installing `tree-sitter-cli` with `mason.nvim`..."
          p:install(
            nil,
            vim.schedule_wrap(function(success)
              if success then
                astrocore.notify "Installed `tree-sitter-cli` with `mason.nvim`."
                _setup()
              else
                astrocore.notify(
                  "Failed to install `tree-sitter-cli` with `mason.nvim\n\nCheck `:Mason` UI for details.",
                  vim.log.levels.ERROR
                )
              end
            end)
          )
        end
      end)
      return
    end
    if vim.fn.executable "tree-sitter" ~= 1 then
      astrocore.notify(
        "`tree-sitter` CLI is required for using `nvim-treesitter`\n\nInstall to enable treesitter features.",
        vim.log.levels.WARN
      )
      return
    end
  end
  _setup()
end

--- Enable treesitter features in buffer
---@param bufnr? integer the buffer to enable treesitter in
function M.enable(bufnr)
  if not bufnr then bufnr = vim.api.nvim_get_current_buf() end
  local ft = vim.bo[bufnr].filetype
  local lang = vim.treesitter.language.get_lang(ft)
  if not M.has_parser(ft) or not lang then return end
  enabled[bufnr] = true

  ---@param feat string
  ---@param query string
  local function feature_enabled(feat, query)
    local enable = config[feat] ---@type AstroCoreTreesitterFeature?
    if type(enable) == "table" then
      enable = vim.tbl_contains(enable, lang)
    elseif type(enable) == "function" then
      enable = enable(lang, bufnr)
    end
    return enable and M.has_parser(ft, query)
  end

  -- highlighting
  if feature_enabled("highlight", "highlights") then pcall(vim.treesitter.start, bufnr) end

  -- indents
  if feature_enabled("indent", "indents") then
    indentexprs[bufnr] = vim.bo[bufnr].indentexpr
    vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end

  -- treesitter text objects
  if config.textobjects and pcall(require, "nvim-treesitter-textobjects") then
    for type, methods in pairs(config.textobjects) do
      local mode = M.textobject_modes[type]
      for method, keys in pairs(methods) do
        for key, opts in pairs(keys) do
          local group = opts.group or "textobjects"
          if M.has_capture(lang, group, string.sub(opts.query, 2)) then
            vim.keymap.set(
              mode,
              key,
              function() require("nvim-treesitter-textobjects." .. type)[method](opts.query, group) end,
              { buffer = bufnr, desc = opts.desc, silent = true }
            )
          end
        end
      end
    end
  end
end

--- Disable treesitter features in buffer
---@param bufnr? integer the buffer to disable treesitter in
function M.disable(bufnr)
  if not bufnr then bufnr = vim.api.nvim_get_current_buf() end
  enabled[bufnr] = false
  pcall(vim.treesitter.stop, bufnr)
  if indentexprs[bufnr] then vim.bo[bufnr].indentexpr = indentexprs[bufnr] end
end

--- Check if treesitter features in buffer
---@param bufnr? integer the buffer to check if treesitter is enabled for
function M.is_enabled(bufnr)
  if not bufnr then bufnr = vim.api.nvim_get_current_buf() end
  return enabled[bufnr] == true
end

return M
