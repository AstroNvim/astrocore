-- AstroNvim Core Configuration
--
-- This module simply defines the configuration table structure for `opts` used in:
--
--    require("astrocore").setup(opts)
--
-- copyright 2023
-- GNU General Public License v3.0

---@class AstroCoreGitWorktree
---@field toplevel string the top level directory
---@field gitdir string the location of the git directory

---@class AstroCoreMaxFile
---@field size integer? the number of bytes in a file
---@field lines integer? the number of lines in a file

---@class AstroCoreSessionAutosave
---@field last boolean? whether or not to save the last session
---@field cwd boolean? whether or not to save a session for the current working directory

---@class AstroCoreSessionIgnore
---@field dirs string[]? directories to ignore
---@field filetypes string[]? filetypes to ignore
---@field buftypes string[]? buffer types to ignore

---@class AstroCoreSessionOpts
---Session autosaving options
---Example:
---
---```lua
---autosave = {
---  last = true,
---  cwd = true,
---}
---```
---@field autosave AstroCoreSessionAutosave?
---Patterns to ignore when saving sessions
---Example:
---
---```lua
---autosave = {
---  dirs = { "/path/to/ignore/sessions/dir" },
---  filetypes = { "gitcommit", "gitrebase" },
---  buftypes = { "nofile" }
---}
---```
---@field ignore AstroCoreSessionIgnore?

---@class AstroCoreFeatureOpts
---@field autopairs boolean? enable or disable autopairs on start (boolean; default = true)
---@field cmp boolean? enable or disable cmp on start (boolean; default = true)
---@field highlighturl boolean? enable or disable highlighting of urls on start (boolean; default = true)
---table for defining the size of the max file for all features, above these limits we disable features like treesitter.
---Example:
---
---```lua
---max_file = {
---  size = 1024 * 100,
---  lines = 10000
---},
---```
---@field max_file AstroCoreMaxFile?
---@field notifications boolean? enable or disable notifications on start (boolean; default = true)

---@class AstroCoreOpts
---@field autocmds table<string,table[]>?
---@field commands table<string,table>?
---Configuration of vim mappings to create.
---The first key into the table is the vim map mode (`:h map-modes`), and the value is a table of entries to be passed to `vim.keymap.set` (`:h vim.keymap.set`):
---  - The key is the first parameter or the vim mode (only a single mode supported) and the value is a table of keymaps within that mode:
---    - The first element with no key in the table is the action (the 2nd parameter) and the rest of the keys/value pairs are options for the third parameter.
---Example:
--
---```lua
---mappings = {
---  -- map mode (:h map-modes)
---  n = {
---    -- use vimscript strings for mappings
---    ["<C-s>"] = { ":w!<cr>", desc = "Save File" },
---    -- navigate buffer tabs with `H` and `L`
---    L = {
---      function()
---        require("astronvim.utils.buffer").nav(vim.v.count > 0 and vim.v.count or 1)
---      end,
---      desc = "Next buffer",
---    },
---    H = {
---      function()
---        require("astronvim.utils.buffer").nav(-(vim.v.count > 0 and vim.v.count or 1))
---      end,
---      desc = "Previous buffer",
---    },
---    -- tables with just a `desc` key will be registered with which-key if it's installed
---    -- this is useful for naming menus
---    ["<leader>b"] = { desc = "Buffers" },
---  }
---}
---```
---@field mappings table<string,table<string,(table|boolean|string)?>?>?
---@field on_keys table<string,fun(key:string)[]>?
---Configuration table of features provided by AstroCore
---Example:
--
---```lua
---features = {
---  autopairs = true,
---  cmp = true,
---  highlighturl = true,
---  notiifcations = true,
---  max_file = { size = 1024 * 100, lines = 10000 },
---}
---```
---@field features AstroCoreFeatureOpts?
---Enable git integration for detached worktrees
---Example:
--
---```lua
---git_worktrees = {
---  { toplevel = vim.env.HOME, gitdir=vim.env.HOME .. "/.dotfiles" }
---}
---```
---@field git_worktrees AstroCoreGitWorktree[]?
---Configuration table of session options for AstroNvim's session management powered by Resession
---Example:
--
---```lua
---sessions = {
---  autosave = {
---    last = true, -- auto save last session
---    cwd = true, -- auto save session for each working directory
---  },
---  ignore = {
---    dirs = {}, -- working directories to ignore sessions in
---    filetypes = { "gitcommit", "gitrebase" }, -- filetypes to ignore sessions
---    buftypes = {}, -- buffer types to ignore sessions
---  },
---}
---```
---@field sessions AstroCoreSessionOpts?

---@type AstroCoreOpts
local M = {
  autocmds = {},
  commands = {},
  mappings = {},
  on_keys = {},
  features = {
    autopairs = true,
    cmp = true,
    highlighturl = true,
    max_file = { size = 1024 * 100, lines = 10000 },
    notifications = true,
  },
  git_worktrees = nil,
  sessions = {
    autosave = { last = true, cwd = true },
    ignore = {
      dirs = {},
      filetypes = { "gitcommit", "gitrebase" },
      buftypes = {},
    },
  },
}

return M
