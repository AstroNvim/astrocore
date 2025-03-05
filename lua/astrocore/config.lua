-- AstroNvim Core Configuration
--
-- This module simply defines the configuration table structure for `opts` used in:
--
--    require("astrocore").setup(opts)
--
-- copyright 2023
-- GNU General Public License v3.0

---@alias AstroCoreMappingCmd string|function

---@class AstroCoreMapping: vim.api.keyset.keymap
---@field [1] AstroCoreMappingCmd? rhs of keymap

---@alias AstroCoreMappings table<string,table<string,(AstroCoreMapping|AstroCoreMappingCmd|false)?>?>

---@class AstroCoreCommand: vim.api.keyset.user_command
---@field [1] string|function the command to execute

---@class AstroCoreAutocmd: vim.api.keyset.create_autocmd
---@field event string|string[] Event(s) that will trigger the handler

---@alias AstroCoreRooterSpec string|string[]|fun(bufnr: integer): (string|string[])

---@class AstroCoreRooterIgnore
---@field dirs string[]? a list of patterns that match directories to exclude from root detection
---@field servers string[]|fun(client:vim.lsp.Client):boolean? a list of language servers to exclude from root detection or a filter function to return if a client should be ignored or not

---@class AstroCoreRooterOpts
---@field detector AstroCoreRooterSpec[]? a list of specifications for the rooter detection
---@field ignore AstroCoreRooterIgnore? configure things to ignore from root detection
---@field scope "global"|"tab"|"win"? what scope to change the working directory
---@field autochdir boolean? whether or not to change working directory automatically
---@field enabled boolean? whether or not to enable the rooter user command and autocommands
---@field notify boolean? whether or not to notify on working directory change

---@class AstroCoreGitWorktree
---@field toplevel string the top level directory
---@field gitdir string the location of the git directory

---@class AstroCoreMaxFile
---@field notify boolean? whether or not to display a notification when a large file is detected
---@field size integer|false? the number of bytes in a file or false to disable check
---@field lines integer|false? the number of lines in a file or false to disable check
---@field line_length integer|false? the average line length in a file or false to disable check

---@class AstroCoreSessionAutosave
---@field last boolean? whether or not to save the last session
---@field cwd boolean? whether or not to save a session for the current working directory

---@class AstroCoreSessionIgnore
---@field dirs string[]? directories to ignore
---@field filetypes string[]? filetypes to ignore
---@field buftypes string[]? buffer types to ignore

-- TODO: remove note about version after dropping support for Neovim v0.10

---@class AstroCoreDiagnosticsFeature
---@field virtual_text boolean? show virtual text on startup
---@field virtual_lines boolean? show virtual lines on startup (Neovim v0.11+ only)
---
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
---@field diagnostics boolean|AstroCoreDiagnosticsFeature? diagnostic enabled on start
---@field highlighturl boolean? enable or disable highlighting of urls on start (boolean; default = true)
---table for defining the size of the max file for all features, above these limits we disable features like treesitter.
---value can also be `false` to disable large buffer detection.
---Example:
---
---```lua
---large_buf = {
---  size = 1024 * 100,
---  lines = 10000
---},
---```
---@field large_buf AstroCoreMaxFile|false?
---@field notifications boolean? enable or disable notifications on start (boolean; default = true)

---@class AstroCoreOpts
---Configuration of auto commands
---The key into the table is the group name for the auto commands (`:h augroup`) and the value
---is a list of autocmd tables where `event` key is the event(s) that trigger the auto command
---and the rest are auto command options (`:h nvim_create_autocmd`)
---Example:
---
---```lua
---autocmds = {
---  -- first key is the `augroup` (:h augroup)
---  highlighturl = {
---    -- list of auto commands to set
---    {
---      -- events to trigger
---      event = { "VimEnter", "FileType", "BufEnter", "WinEnter" },
---      -- the rest of the autocmd options (:h nvim_create_autocmd)
---      desc = "URL Highlighting",
---      callback = function() require("astrocore").set_url_match() end
---    }
---  }
---}
---```
---@field autocmds table<string,AstroCoreAutocmd[]|false>?
---Configuration of user commands
---The key into the table is the name of the user command and the value is a table of command options
---Example:
---
---```lua
---commands = {
---  -- key is the command name
---  AstroReload = {
---    -- first element with no key is the command (string or function)
---    function() require("astrocore").reload() end,
---    -- the rest are options for creating user commands (:h nvim_create_user_command)
---    desc = "Reload AstroNvim (Experimental)",
---  }
---}
---```
---@field commands table<string,AstroCoreCommand|false>?
---Configure diagnostics options (`:h vim.diagnostic.config()`)
---Example:
--
---```lua
---diagnostics = { update_in_insert = false },
---```
---@field diagnostics vim.diagnostic.Opts?
---Configuration of filetypes, simply runs `vim.filetype.add`
---
---See `:h vim.filetype.add` for details on usage
---
---Example:
---
---```lua
---filetypes = { -- parameter to `vim.filetype.add`
---  extension = {
---    foo = "fooscript"
---  },
---  filename = {
---    [".foorc"] = "fooscript"
---  },
---  pattern = {
---    [".*/etc/foo/.*"] = "fooscript",
---  }
---}
---```
---@field filetypes vim.filetype.add.filetypes?
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
---      function() require("astrocore.buffer").nav(vim.v.count1) end,
---      desc = "Next buffer",
---    },
---    H = {
---      function() require("astrocore.buffer").nav(-vim.v.count1) end,
---      desc = "Previous buffer",
---    },
---    -- tables with just a `desc` key will be registered with which-key if it's installed
---    -- this is useful for naming menus
---    ["<leader>b"] = { desc = "Buffers" },
---  }
---}
---```
---@field mappings AstroCoreMappings?
---@field _map_sections table<string,{ desc: string?, name: string? }>?
---Configuration of vim `on_key` functions.
---The key into the table is the namespace of the function and the value is a list like table of `on_key` functions
---Example:
---
---```lua
---on_keys = {
---  -- first key is the namespace
---  auto_hlsearch = {
---    -- list of functions to execute on key press (:h vim.on_key)
---    function(char) -- example automatically disables `hlsearch` when not actively searching
---      if vim.fn.mode() == "n" then
---        local new_hlsearch = vim.tbl_contains({ "<CR>", "n", "N", "*", "#", "?", "/" }, vim.fn.keytrans(char))
---        if vim.opt.hlsearch:get() ~= new_hlsearch then vim.opt.hlsearch = new_hlsearch end
---      end
---    end,
---  },
---},
---```
---@field on_keys table<string,fun(key:string)[]|false>?
---Configuration of `vim` options (`vim.<first_key>.<second_key> = value`)
---The first key into the table is the type of option and the second key is the setting
---Example:
---
---```lua
---options = {
---  -- first key is the type of option
---  opt = { -- (`vim.opt`)
---    relativenumber = true, -- sets `vim.opt.relativenumber`
---    signcolumn = "auto", -- sets `vim.opt.signcolumn`
---  },
---  g = { -- (`vim.g`)
---    -- set global `vim.g.<key>` settings here
---  }
---}
---```
---@field options table<string,table<string,any>>?
---Configure signs (`:h sign_define()`)
---Example:
--
---```lua
---signs = {
---  DapBreakPoint" = { text = "", texthl = "DiagnosticInfo" },
---},
---```
---@field signs table<string,vim.fn.sign_define.dict|false>?
---Configuration table of features provided by AstroCore
---Example:
--
---```lua
---features = {
---  autopairs = true,
---  cmp = true,
---  diagnostics = true,
---  highlighturl = true,
---  notiifcations = true,
---  large_buf = { size = 1024 * 100, lines = 10000 },
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
---Enable and configure project root detection
---Example:
--
---```lua
---rooter = {
---  detector = {
---    "lsp", -- highest priority is getting workspace from running language servers
---    { ".git", "_darcs", ".hg", ".bzr", ".svn" }, -- next check for a version controlled parent directory
---    { "lua", "MakeFile", "package.json" }, -- lastly check for known project root files
---  },
---  ignore = {
---    servers = {}, -- list of language server names to ignore (Ex. { "efm" })
---    dirs = {}, -- list of directory patterns (Ex. { "~/.cargo/*" })
---  },
---  autochdir = false, -- automatically update working directory
---  scope = "global", -- scope of working directory to change ("global"|"tab"|"win")
---  notify = false, -- show notification on every working directory change
---}
---```
---@field rooter AstroCoreRooterOpts|false?
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
  diagnostics = {},
  filetypes = {},
  mappings = {},
  on_keys = {},
  options = {},
  signs = {},
  features = {
    autopairs = true,
    cmp = true,
    diagnostics = true,
    highlighturl = true,
    large_buf = { notify = true, size = 1.5 * 1024 * 1024, lines = 100000, line_length = 1000 },
    notifications = true,
  },
  git_worktrees = nil,
  rooter = { enabled = true },
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
