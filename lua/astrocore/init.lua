local M = {}

local utils = require "astrocore.utils"

M.config = require "astrocore.config"

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- mappings
  utils.set_mappings(M.config.mappings)

  -- autocmds
  for augroup, autocmds in pairs(M.config.autocmds) do
    local augroup_id = vim.api.nvim_create_augroup(augroup, { clear = true })
    for _, autocmd in ipairs(autocmds) do
      local event = autocmd.event
      autocmd.event = nil
      autocmd.group = augroup_id
      vim.api.nvim_create_autocmd(event, autocmd)
    end
  end

  -- user commands
  for cmd, spec in pairs(M.config.commands) do
    local action = spec[1]
    spec[1] = nil
    vim.api.nvim_create_user_command(cmd, action, spec)
  end

  -- on_key hooks
  for namespace, funcs in pairs(M.config.on_keys) do
    local ns = vim.api.nvim_create_namespace(namespace)
    for _, func in ipairs(funcs) do
      vim.on_key(func, ns)
    end
  end
end

return M
