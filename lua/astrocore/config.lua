--- ### AstroNvim Core Configuration
--
-- This module simply defines the configuration table structure for `opts` used in:
--
--    require("astrocore").setup(opts)
--
-- @module astrocore.config
-- @copyright 2023
-- @license GNU General Public License v3.0

---@type AstroCoreConfig
return {
  autocmds = {},
  commands = {},
  --- Configuration of vim mappings to create
  --
  -- @field mode The key, `mode` is the vim map mode (`:h map-modes`), and the value is a table of entries to be passed to `vim.keymap.set` (`:h vim.keymap.set`):
  --
  --   The key is the first parameter or the vim mode (only a single mode supported) and the value is a table of keymaps within that mode:
  --
  --   The first element with no key in the table is the action (the 2nd parameter) and the rest of the keys/value pairs are options for the third parameter.
  -- @usage mappings = {
  --   -- map mode (:h map-modes)
  --   n = {
  --     -- use vimscript strings for mappings
  --     ["<C-s>"] = { ":w!<cr>", desc = "Save File" },
  --     -- navigate buffer tabs with `H` and `L`
  --     L = {
  --       function()
  --         require("astronvim.utils.buffer").nav(vim.v.count > 0 and vim.v.count or 1)
  --       end,
  --       desc = "Next buffer",
  --     },
  --     H = {
  --       function()
  --         require("astronvim.utils.buffer").nav(-(vim.v.count > 0 and vim.v.count or 1))
  --       end,
  --       desc = "Previous buffer",
  --     },
  --     -- tables with just a `desc` key will be registered with which-key if it's installed
  --     -- this is useful for naming menus
  --     ["<leader>b"] = { desc = "Buffers" },
  --   }
  -- }
  mappings = {},
  on_keys = {},
  --- Configuration table of features provided by AstroCore
  -- @field autopairs enable or disable autopairs on start (boolean; default = true)
  -- @field cmp enable or disable cmp on start (boolean; default = true)
  -- @field highlighturl enable or disable highlighting of urls on start (boolean; default = true)
  -- @field max_file table for defining the size of the max file for all features, above these limites we disable features like treesitter. This table has the fields: `size` (the number of bytes of a file) and `lines` (the number of lines of a file)
  -- @field notifications enable or disable notifications on start (boolean; default = true)
  -- @usage features = {
  --   autopairs = true,
  --   cmp = true,
  --   highlighturl = true,
  --   notiifcations = true,
  --   max_file = { size = 1024 * 100, lines = 10000 },
  -- }
  features = {
    autopairs = true,
    cmp = true, -- enable completion at start
    highlighturl = true, -- highlight URLs by default
    max_file = { size = 1024 * 100, lines = 10000 },
    notifications = true, -- disable notifications
  },
  --- Enable git integration for detached worktrees (specify a list-like table where each entry is of the form `{ toplevel = vim.env.HOME, gitdir=vim.env.HOME .. "/.dotfiles" }`)
  -- @table git_worktrees
  -- @usage git_worktrees = {
  --   { toplevel = vim.env.HOME, gitdir=vim.env.HOME .. "/.dotfiles" }
  -- }
  git_worktrees = nil,
  --- Configuration table of session options for AstroNvim's session management powered by Resession
  -- @field autosave a table with fields `last` and `cwd` to control if they should autosave sessions
  -- @field ignore a table of lists for `dirs`, `filetypes`, and `buftypes` which should be ignored when autosaving sessions
  -- @usage sessions = {
  --   autosave = {
  --     last = true, -- auto save last session
  --     cwd = true, -- auto save session for each working directory
  --   },
  --   ignore = {
  --     dirs = {}, -- working directories to ignore sessions in
  --     filetypes = { "gitcommit", "gitrebase" }, -- filetypes to ignore sessions
  --     buftypes = {}, -- buffer types to ignore sessions
  --   },
  -- }
  sessions = {
    autosave = {
      last = true, -- auto save last session
      cwd = true, -- auto save session for each working directory
    },
    ignore = {
      dirs = {}, -- working directories to ignore sessions in
      filetypes = { "gitcommit", "gitrebase" }, -- filetypes to ignore sessions
      buftypes = {}, -- buffer types to ignore sessions
    },
  },
}
