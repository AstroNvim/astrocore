# 🧰 AstroCore

AstroCore provides the core Lua API that powers [AstroNvim](https://github.com/AstroNvim/AstroNvim). It provides an interface for configuration auto commands, user commands, on_key functions, key mappings, and more as well as a Lua API of common utility functions.

## ✨ Features

- Unified interface for configuring auto commands, user commands, key maps, on key functions
- Easy toggles of UI/UX elements and features
- Universal interface for setting up git worktrees
- Tab local buffer management for a clean `tabline`
- Project root detection with automatic `cd` features
- Session management with [resession.nvim][resession]

## ⚡️ Requirements

- Neovim >= 0.10
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- [resession.nvim][resession] (_optional_)

## 📦 Installation

Install the plugin with the lazy plugin manager:

```lua
return {
  "AstroNvim/astrocore",
  lazy = false, -- disable lazy loading
  priority = 10000, -- load AstroCore first
  opts = {
    -- set configuration options  as described below
  },
}
```

> 💡 If you want to enable session management with [resession.nvim][resession], enable it in the setup:

```lua
require("resession").setup {
  extensions = {
    astrocore = {},
  },
}
```

## ⚙️ Configuration

**AstroCore** comes with no defaults, but can be configured fully through the `opts` table in lazy. Here are descriptions of the options and some example usages:

```lua
---@type AstroCoreConfig
local opts = {
  -- easily configure auto commands
  autocmds = {
    -- first key is the `augroup` (:h augroup)
    highlighturl = {
      -- list of auto commands to set
      {
        -- events to trigger
        event = { "VimEnter", "FileType", "BufEnter", "WinEnter" },
        -- the rest of the autocmd options (:h nvim_create_autocmd)
        desc = "URL Highlighting",
        callback = function() require("astrocore").set_url_match() end,
      },
    },
  },
  -- easily configure user commands
  commands = {
    -- key is the command name
    AstroReload = {
      -- first element with no key is the command (string or function)
      function() require("astrocore").reload() end,
      -- the rest are options for creating user commands (:h nvim_create_user_command)
      desc = "Reload AstroNvim (Experimental)",
    },
  },
  -- Configure diagnostics options (`:h vim.diagnostic.config()`)
  diagnostics = {
    update_in_insert = false,
  },
  -- passed to `vim.filetype.add`
  filetypes = {
    -- see `:h vim.filetype.add` for usage
    extension = {
      foo = "fooscript",
    },
    filename = {
      [".foorc"] = "fooscript",
    },
    pattern = {
      [".*/etc/foo/.*"] = "fooscript",
    },
  },
  -- Configuration of vim mappings to create
  mappings = {
    -- map mode (:h map-modes)
    n = {
      -- use vimscript strings for mappings
      ["<C-s>"] = { ":w!<cr>", desc = "Save File" },
      -- navigate buffer tabs with `H` and `L`
      L = {
        function() require("astrocore.buffer").nav(vim.v.count1) end,
        desc = "Next buffer",
      },
      H = {
        function() require("astrocore.buffer").nav(-vim.v.count1) end,
        desc = "Previous buffer",
      },
      -- tables with just a `desc` key will be registered with which-key if it's installed
      -- this is useful for naming menus
      ["<leader>b"] = { desc = "Buffers" },
    },
  },
  -- easily configure functions on key press
  on_keys = {
    -- first key is the namespace
    auto_hlsearch = {
      -- list of functions to execute on key press (:h vim.on_key)
      function(char) -- example automatically disables `hlsearch` when not actively searching
        if vim.fn.mode() == "n" then
          local new_hlsearch = vim.tbl_contains({ "<CR>", "n", "N", "*", "#", "?", "/" }, vim.fn.keytrans(char))
          if vim.opt.hlsearch:get() ~= new_hlsearch then vim.opt.hlsearch = new_hlsearch end
        end
      end,
    },
  },
  -- easily configure vim options
  options = {
    -- first key is the type of option `vim.<first_key>`
    opt = {
      relativenumber = true, -- sets `vim.opt.relativenumber`
      signcolumn = "auto", -- sets `vim.opt.relativenumber`
    },
    g = {
      -- set global `vim.g` settings here
    },
  },
  -- configure AstroNvim features
  features = {
    autopairs = true, -- enable or disable autopairs on start
    cmp = true, -- enable or disable cmp on start
    diagnostics = { virtual_text = true, virtual_lines = false }, -- enable or disable diagnostics features on start
    highlighturl = true, -- enable or disable highlighting of urls on start
    -- table for defining the size of the max file for all features, above these limits we disable features like treesitter.
    large_buf = {
      enabled = function(bufnr) return true end, -- whether to enable large file detection for a buffer
      notify = true, -- whether or not to display a notification when a large file is detected
      size = 1024 * 100, -- max file size (or false to disable check)
      lines = 10000, -- max number of lines (or false to disable check)
      line_length = 1000, -- average line length (or false to disable check)
    },
    notifications = true, -- enable or disable notifications on start
  },
  -- Enable git integration for detached worktrees
  git_worktrees = {
    { toplevel = vim.env.HOME, gitdir = vim.env.HOME .. "/.dotfiles" },
  },
  -- Configure project root detection, check status with `:AstroRootInfo`
  rooter = {
    -- list of detectors in order of prevalence, elements can be:
    --   "lsp" : lsp detection
    --   string[] : a list of directory patterns to look for
    --   fun(bufnr: integer): string|string[] : a function that takes a buffer number and outputs detected roots
    detector = {
      "lsp", -- highest priority is getting workspace from running language servers
      { ".git", "_darcs", ".hg", ".bzr", ".svn" }, -- next check for a version controlled parent directory
      { "lua", "MakeFile", "package.json" }, -- lastly check for known project root files
    },
    -- ignore things from root detection
    ignore = {
      servers = {}, -- list of language server names to ignore (Ex. { "efm" })
      dirs = {}, -- list of directory patterns (Ex. { "~/.cargo/*" })
    },
    -- automatically update working directory (update manually with `:AstroRoot`)
    autochdir = false,
    -- scope of working directory to change ("global"|"tab"|"win")
    scope = "global",
    -- show notification on every working directory change
    notify = false,
  },
  -- Configuration table of session options for AstroNvim's session management powered by Resession
  sessions = {
    -- Configure auto saving
    autosave = {
      last = true, -- auto save last session
      cwd = true, -- auto save session for each working directory
    },
    -- Patterns to ignore when saving sessions
    ignore = {
      dirs = {}, -- working directories to ignore sessions in
      filetypes = { "gitcommit", "gitrebase" }, -- filetypes to ignore sessions
      buftypes = {}, -- buffer types to ignore sessions
    },
  },
}
```

## 📦 API

**AstroCore** provides a Lua API with utility functions. This can be viewed with `:h astrocore` or in the repository at [doc/api.md](doc/api.md)

[resession]: https://github.com/stevearc/resession.nvim/

## 🚀 Contributing

If you plan to contribute, please check the [contribution guidelines](https://github.com/AstroNvim/.github/blob/main/CONTRIBUTING.md) first.
