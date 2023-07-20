local M = {}

local utils = require "astrocore.utils"

function M.setup(opts)
  M.config = opts

  -- mappings
  utils.set_mappings(M.config.mappings)

  -- autocmds
  require "astrocore.autocmds"
end

return M
