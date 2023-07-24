return {
  autocmds = {},
  commands = {},
  mappings = {},
  on_keys = {},
  features = {
    max_file = { size = 1024 * 100, lines = 10000 }, -- set global limits for large files
    autopairs = true, -- enable autopairs at start
    cmp = true, -- enable completion at start
    highlighturl = true, -- highlight URLs by default
    notifications = true, -- disable notifications
  },
  git_worktrees = nil, -- enable git integration for detached worktrees (specify a table where each entry is of the form { toplevel = vim.env.HOME, gitdir=vim.env.HOME .. "/.dotfiles" })
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
