return {
  mappings = {},
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
  polish = nil,
}
