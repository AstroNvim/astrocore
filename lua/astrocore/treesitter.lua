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
local installed_checked = false
local installed = {}
local queries = {}
local captures = {}

local enabled = {}
local highlights = {}
local indentexprs = {}
local textobject_mappings = {}
local treesitter_indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

local function normalize_key(key) return vim.fn.keytrans(vim.api.nvim_replace_termcodes(key, true, true, true)) end

local function restore_owned_indentexpr(bufnr)
  if indentexprs[bufnr] ~= nil then
    if vim.bo[bufnr].indentexpr == treesitter_indentexpr then vim.bo[bufnr].indentexpr = indentexprs[bufnr] end
    indentexprs[bufnr] = nil
  end
end

local function clear_textobject_mappings(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    for mode, mappings in pairs(textobject_mappings[bufnr] or {}) do
      for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
        if mappings[normalize_key(mapping.lhs)] == mapping.callback then
          vim.api.nvim_buf_del_keymap(bufnr, mode, mapping.lhs)
        end
      end
    end
  end
  textobject_mappings[bufnr] = nil
end

--- Configure the keymap modes for each textobject type
M.textobject_modes = {
  select = { "x", "o" },
  swap = { "n" },
  move = { "n", "x", "o" },
}

--- Get list of treesitter parsers installed with `nvim-treesitter`
---@param update boolean? whether or not to refresh installed parsers
---@return table<string,boolean> # a lookup table of installed parsers
function M.installed(update)
  if update then
    local treesitter_avail, treesitter = pcall(require, "nvim-treesitter")
    if treesitter_avail then
      installed, queries, captures = {}, {}, {}
      for _, lang in ipairs(treesitter.get_installed "parsers") do
        installed[lang] = true
      end
      installed_checked = true
    end
  end
  return installed
end

--- Get available treesitter parsers in `nvim-treesitter`
---@return table<string,boolean> # a lookup table of available parsers
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
  local treesitter_avail, treesitter = pcall(require, "nvim-treesitter")
  if not treesitter_avail then return end
  if not languages or languages == "auto" then
    local lang = vim.treesitter.language.get_lang(vim.bo[vim.api.nvim_get_current_buf()].filetype)
    languages = M.available()[lang] and { lang } or {}
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
---@return boolean # whether or not a capture is supported by the given parser
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
---@return boolean # whether or not a parser is supported
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
    available = nil
    M.installed(true)
    M.install(config.ensure_installed)
  end)

  local group = vim.api.nvim_create_augroup("astrocore_treesitter", { clear = true })
  local function reconcile_buffer(args, allow_install)
    if enabled[args.buf] == false then return end
    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
    if not lang then
      M.disable(args.buf)
      enabled[args.buf] = nil
      return
    end
    local _enabled = config.enabled
    if type(_enabled) == "function" then _enabled = _enabled(lang, args.buf) end
    if _enabled then
      if not installed_checked then M.installed(true) end
      if not M.has_parser(args.buf) then
        M.disable(args.buf)
        enabled[args.buf] = nil
        if allow_install ~= false and (config.auto_install or config.ensure_installed == "auto") then
          M.install(M.available()[lang] and { lang } or {}, function()
            if vim.api.nvim_buf_is_valid(args.buf) then reconcile_buffer(args, false) end
          end)
        end
      else
        M.enable(args.buf)
      end
    else
      M.disable(args.buf)
      enabled[args.buf] = nil
    end
  end
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    desc = "Automatically detect available treesitter parsers and enable necessary features",
    callback = reconcile_buffer,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    desc = "Clear deleted buffer treesitter state",
    callback = function(args)
      enabled[args.buf], highlights[args.buf], indentexprs[args.buf] = nil, nil, nil
      textobject_mappings[args.buf] = nil
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
  -- Check if buffer is valid (may have been deleted during async operations)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    textobject_mappings[bufnr] = nil
    return
  end
  clear_textobject_mappings(bufnr)
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
  if feature_enabled("highlight", "highlights") then
    highlights[bufnr] = pcall(vim.treesitter.start, bufnr)
  elseif highlights[bufnr] then
    pcall(vim.treesitter.stop, bufnr)
    highlights[bufnr] = nil
  end

  -- indents
  if feature_enabled("indent", "indents") then
    if vim.bo[bufnr].indentexpr ~= treesitter_indentexpr then indentexprs[bufnr] = vim.bo[bufnr].indentexpr end
    vim.bo[bufnr].indentexpr = treesitter_indentexpr
  else
    restore_owned_indentexpr(bufnr)
  end

  -- if folds are present force update of folds after loading
  if M.has_parser(ft, "folds") and vim.api.nvim_get_current_buf() == bufnr then
    vim.wo.foldmethod = vim.wo.foldmethod
  end

  -- treesitter text objects
  if config.textobjects and pcall(require, "nvim-treesitter-textobjects") then
    for type, methods in pairs(config.textobjects) do
      local mode = M.textobject_modes[type]
      for method, keys in pairs(methods) do
        for key, opts in pairs(keys) do
          local group = opts.group or "textobjects"
          if M.has_capture(lang, group, string.sub(opts.query, 2)) then
            local callback = function() require("nvim-treesitter-textobjects." .. type)[method](opts.query, group) end
            for _, map_mode in ipairs(mode) do
              vim.keymap.set(map_mode, key, callback, { buffer = bufnr, desc = opts.desc, silent = true })
              textobject_mappings[bufnr] = textobject_mappings[bufnr] or {}
              textobject_mappings[bufnr][map_mode] = textobject_mappings[bufnr][map_mode] or {}
              textobject_mappings[bufnr][map_mode][normalize_key(key)] = callback
            end
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
  if not vim.api.nvim_buf_is_valid(bufnr) then
    enabled[bufnr], highlights[bufnr], indentexprs[bufnr] = nil, nil, nil
    textobject_mappings[bufnr] = nil
    return
  end
  local was_enabled = enabled[bufnr] == true
  enabled[bufnr] = false
  pcall(vim.treesitter.stop, bufnr)
  highlights[bufnr] = nil
  restore_owned_indentexpr(bufnr)
  clear_textobject_mappings(bufnr)
  if was_enabled then
    vim.schedule(function()
      if vim.api.nvim_get_current_buf() == bufnr and vim.bo[bufnr].buftype ~= "terminal" then vim.cmd "normal! zx" end
    end)
  end
end

--- Check if treesitter features in buffer
---@param bufnr? integer the buffer to check if treesitter is enabled for
---@return boolean # whether or not treesitter is enabled in buffer
function M.is_enabled(bufnr)
  if not bufnr then bufnr = vim.api.nvim_get_current_buf() end
  return enabled[bufnr] == true
end

return M
