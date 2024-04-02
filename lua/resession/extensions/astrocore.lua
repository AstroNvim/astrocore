local M = {}

---@param opts resession.Extension.OnSaveOpts
M.on_save = function(opts)
  -- initiate astronvim data
  local data = { bufnrs = {}, tabs = {} }

  local buf_utils = require "astrocore.buffer"

  data.current_buf = buf_utils.current_buf
  data.last_buf = buf_utils.last_buf

  -- save tab scoped buffers and buffer numbers from buffer name
  for new_tabpage, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if tabpage == opts.tabpage then data.tabpage = new_tabpage end
    data.tabs[new_tabpage] = vim.t[tabpage].bufs
    for _, bufnr in ipairs(data.tabs[new_tabpage]) do
      data.bufnrs[vim.api.nvim_buf_get_name(bufnr)] = bufnr
    end
  end

  return data
end

M.on_post_load = function(data)
  -- create map from old buffer numbers to new buffer numbers
  local new_bufnrs = {}
  local new_tabpages = vim.api.nvim_list_tabpages()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local old_bufnr = data.bufnrs[vim.api.nvim_buf_get_name(bufnr)]
    if old_bufnr then new_bufnrs[old_bufnr] = bufnr end
  end
  -- build new tab scoped buffer lists
  if not data.tabpage then
    for tabpage, tabs in pairs(data.tabs) do
      local bufs = vim.tbl_map(function(bufnr) return new_bufnrs[bufnr] end, tabs)
      vim.t[new_tabpages[tabpage]].bufs = bufs
    end
  else
    vim.t.bufs = vim.tbl_map(function(bufnr) return new_bufnrs[bufnr] end, data.tabs[data.tabpage])
  end

  local buf_utils = require "astrocore.buffer"
  local current_buf, last_buf = new_bufnrs[data.current_buf], new_bufnrs[data.last_buf]
  if current_buf and last_buf then
    buf_utils.current_buf = current_buf
    buf_utils.last_buf = last_buf
  end

  require("astrocore").event "BufsUpdated"

  if current_buf and last_buf then
    if vim.opt.bufhidden:get() == "wipe" and vim.fn.bufnr() ~= buf_utils.current_buf then
      vim.cmd.b(buf_utils.current_buf)
    end
  end
end

return M
