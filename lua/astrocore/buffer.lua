---AstroNvim Buffer Utilities
---
---Buffer management related utility functions
---
---This module can be loaded with `local buffer_utils = require "astrocore.buffer"`
---
---copyright 2023
---license GNU General Public License v3.0
---@class astrocore.buffer
local M = {}

local astro = require "astrocore"

--- Placeholders for keeping track of most recent and previous buffer
M.current_buf, M.last_buf = nil, nil

--- Check if a buffer is valid
---@param bufnr? integer The buffer to check, default to current buffer
---@return boolean # Whether the buffer is valid or not
function M.is_valid(bufnr)
  if not bufnr then bufnr = 0 end
  return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted
end

local large_buf_cache, buf_size_cache = {}, {} -- cache large buffer detection results and buffer sizes
--- Check if a buffer is a large buffer (always returns false if large buffer detection is disabled)
---@param bufnr? integer the buffer to check the size of, default to current buffer
---@param large_buf_opts? AstroCoreMaxFile large buffer parameters, default to AstroCore configuration
---@return boolean is_large whether the buffer is detected as large or not
function M.is_large(bufnr, large_buf_opts)
  if not bufnr then bufnr = vim.api.nvim_get_current_buf() end
  -- always return not large until buffer is loaded, do not cache decision
  if not vim.api.nvim_buf_is_loaded(bufnr) then return false end
  local skip_cache = large_buf_opts ~= nil -- skip cache when called manually with custom options
  if not large_buf_opts then large_buf_opts = vim.tbl_get(astro.config, "features", "large_buf") end
  if large_buf_opts then
    if skip_cache or large_buf_cache[bufnr] == nil then
      local enabled = vim.tbl_get(large_buf_opts, "enabled")
      if type(enabled) == "function" then
        large_buf_opts = vim.deepcopy(large_buf_opts)
        enabled = enabled(bufnr, large_buf_opts)
        if type(enabled) == "table" then large_buf_opts = enabled end
      end
      local large_buf = false
      if vim.F.if_nil(enabled, true) then
        if not buf_size_cache[bufnr] then
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(bufnr))
          buf_size_cache[bufnr] = ok and stats and stats.size or 0
        end
        local file_size = buf_size_cache[bufnr]
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local too_large = large_buf_opts.size and file_size > large_buf_opts.size
        local too_long = large_buf_opts.lines and line_count > large_buf_opts.lines
        local too_wide = large_buf_opts.line_length and (file_size / line_count) - 1 > large_buf_opts.line_length
        large_buf = too_large or too_long or too_wide or false
      end
      if skip_cache then return large_buf end
      large_buf_cache[bufnr] = large_buf
    end
    return large_buf_cache[bufnr]
  end
  return false
end

--- Check if a buffer has a filetype
---@param bufnr? integer The buffer to check, default to current buffer
---@return boolean # Whether the buffer has a filetype or not
function M.has_filetype(bufnr)
  if not bufnr then bufnr = 0 end
  local filetype = vim.bo[bufnr].filetype
  return filetype ~= nil and filetype ~= ""
end

--- Check if a buffer can be restored
---@param bufnr integer The buffer to check
---@return boolean # Whether the buffer is restorable or not
function M.is_restorable(bufnr)
  if not M.is_valid(bufnr) or vim.bo[bufnr].bufhidden ~= "" then return false end

  -- Check if it has a filename.
  if vim.api.nvim_buf_get_name(bufnr) == "" then return false end

  local session_ignore = vim.tbl_get(astro.config, "sessions", "ignore") or {}
  if
    vim.tbl_contains(vim.tbl_get(session_ignore, "filetypes") or {}, vim.bo[bufnr].filetype)
    or vim.tbl_contains(vim.tbl_get(session_ignore, "buftypes") or {}, vim.bo[bufnr].buftype)
  then
    return false
  end
  return vim.bo[bufnr].buflisted
end

--- Check if the current buffers form a valid session
---@return boolean # Whether the current session of buffers is a valid session
function M.is_valid_session()
  local cwd = vim.fn.getcwd()
  for _, dir in ipairs(vim.tbl_get(astro.config, "sessions", "ignore", "dirs") or {}) do
    if vim.fn.expand(dir) == cwd then return false end
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if M.is_restorable(bufnr) then return true end
  end
  return false
end

--- Move the current buffer tab n places in the bufferline
---@param n integer The number of tabs to move the current buffer over by (positive = right, negative = left)
function M.move(n)
  if n == 0 then return end -- if n = 0 then no shifts are needed
  local bufs = vim.t.bufs -- make temp variable
  for i, bufnr in ipairs(bufs) do -- loop to find current buffer
    if bufnr == vim.api.nvim_get_current_buf() then -- found index of current buffer
      for _ = 0, (n % #bufs) - 1 do -- calculate number of right shifts
        local new_i = i + 1 -- get next i
        if i == #bufs then -- if at end, cycle to beginning
          new_i = 1 -- next i is actually 1 if at the end
          local val = bufs[i] -- save value
          table.remove(bufs, i) -- remove from end
          table.insert(bufs, new_i, val) -- insert at beginning
        else -- if not at the end,then just do an in place swap
          bufs[i], bufs[new_i] = bufs[new_i], bufs[i]
        end
        i = new_i -- iterate i to next value
      end
      break
    end
  end
  vim.t.bufs = bufs -- set buffers
  astro.event "BufsUpdated"
  vim.cmd.redrawtabline() -- redraw tabline
end

--- Navigate left and right by n places in the bufferline
---@param n integer The number of tabs to navigate to (positive = right, negative = left)
function M.nav(n)
  local current = vim.api.nvim_get_current_buf()
  for i, v in ipairs(vim.t.bufs) do
    if current == v then
      local new_buf = vim.t.bufs[(i + n - 1) % #vim.t.bufs + 1]
      if new_buf ~= current then vim.api.nvim_set_current_buf(new_buf) end
      return
    end
  end
end

--- Navigate to a specific buffer by its position in the bufferline
---@param tabnr integer The position of the buffer to navigate to
function M.nav_to(tabnr)
  if tabnr > #vim.t.bufs or tabnr < 1 then
    astro.notify(("No tab #%d"):format(tabnr), vim.log.levels.WARN)
  else
    local new_buf = vim.t.bufs[tabnr]
    if vim.api.nvim_get_current_buf() ~= new_buf then vim.api.nvim_set_current_buf(new_buf) end
  end
end

--- Navigate to the previously used buffer
function M.prev()
  if vim.api.nvim_get_current_buf() == M.current_buf then
    if M.last_buf and M.is_valid(M.last_buf) then
      vim.api.nvim_set_current_buf(M.last_buf)
    else
      astro.notify("Previous buffer not found", vim.log.levels.WARN)
    end
  else
    astro.notify("Must be in a main editor window to switch the window buffer", vim.log.levels.ERROR)
  end
end

--- Helper function to power a save confirmation prompt before `mini.bufremove`
---@param func fun(bufnr:integer,force:boolean?) The function to execute if confirmation is passed
---@param bufnr integer The buffer to close or the current buffer if not provided
---@param force? boolean Whether or not to foce close the buffers or confirm changes (default: false)
local function mini_confirm(func, bufnr, force)
  if not force and vim.bo[bufnr].modified then
    local bufname = vim.fn.expand "%"
    local empty = bufname == ""
    if empty then bufname = "Untitled" end
    local confirm = vim.fn.confirm(('Save changes to "%s"?'):format(bufname), "&Yes\n&No\n&Cancel", 1, "Question")
    if confirm == 1 then
      if empty then return end
      vim.cmd.write()
    elseif confirm == 2 then
      force = true
    else
      return
    end
  end
  func(bufnr, force)
end

--- Close a given buffer
---@param bufnr? integer The buffer to close or the current buffer if not provided
---@param force? boolean Whether or not to foce close the buffers or confirm changes (default: false)
function M.close(bufnr, force)
  if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  if M.is_valid(bufnr) and #vim.t.bufs > 1 then
    if astro.is_available "snacks.nvim" then
      require("snacks").bufdelete { buf = bufnr, force = force }
      return
    end
    if astro.is_available "mini.bufremove" then
      mini_confirm(require("mini.bufremove").delete, bufnr, force)
      return
    end
  end
  -- fallback
  local buftype = vim.bo[bufnr].buftype
  vim.cmd(("silent! %s %d"):format((force or buftype == "terminal") and "bdelete!" or "confirm bdelete", bufnr))
end

--- Fully wipeout a given buffer
---@param bufnr? integer The buffer to wipe or the current buffer if not provided
---@param force? boolean Whether or not to foce close the buffers or confirm changes (default: false)
function M.wipe(bufnr, force)
  if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  if M.is_valid(bufnr) and #vim.t.bufs > 1 then
    if astro.is_available "snacks.nvim" then
      return require("snacks").bufdelete { buf = bufnr, force = force, wipe = true }
    end
    if astro.is_available "mini.bufremove" then return mini_confirm(require("mini.bufremove").wipeout, bufnr, force) end
  end
  -- fallback
  local buftype = vim.bo[bufnr].buftype
  vim.cmd(("silent! %s %d"):format((force or buftype == "terminal") and "bwipeout!" or "confirm bwipeout", bufnr))
end

--- Close all buffers
---@param keep_current? boolean Whether or not to keep the current buffer (default: false)
---@param force? boolean Whether or not to foce close the buffers or confirm changes (default: false)
function M.close_all(keep_current, force)
  if keep_current == nil then keep_current = false end
  local current = vim.api.nvim_get_current_buf()
  for _, bufnr in ipairs(vim.t.bufs) do
    if not keep_current or bufnr ~= current then M.close(bufnr, force) end
  end
end

--- Close buffers to the left of the current buffer
---@param force? boolean Whether or not to foce close the buffers or confirm changes (default: false)
function M.close_left(force)
  local current = vim.api.nvim_get_current_buf()
  for _, bufnr in ipairs(vim.t.bufs) do
    if bufnr == current then break end
    M.close(bufnr, force)
  end
end

--- Close buffers to the right of the current buffer
---@param force? boolean Whether or not to foce close the buffers or confirm changes (default: false)
function M.close_right(force)
  local current = vim.api.nvim_get_current_buf()
  local after_current = false
  for _, bufnr in ipairs(vim.t.bufs) do
    if after_current then M.close(bufnr, force) end
    if bufnr == current then after_current = true end
  end
end

--- Sort a the buffers in the current tab based on some comparator
---@param compare_func string|function a string of a comparator defined in require("astrocore.buffer.comparator") or a custom comparator function
---@param skip_autocmd boolean|nil whether or not to skip triggering AstroBufsUpdated autocmd event
---@return boolean # Whether or not the buffers were sorted
function M.sort(compare_func, skip_autocmd)
  if type(compare_func) == "string" then compare_func = require("astrocore.buffer.comparator")[compare_func] end
  if type(compare_func) == "function" then
    local bufs = vim.t.bufs
    table.sort(bufs, compare_func)
    vim.t.bufs = bufs
    if not skip_autocmd then astro.event "BufsUpdated" end
    vim.cmd.redrawtabline()
    return true
  end
  return false
end

--- Close a given tab
---@param tabpage? integer The tabpage to close or the current tab if not provided
function M.close_tab(tabpage)
  if #vim.api.nvim_list_tabpages() > 1 then
    tabpage = tabpage or vim.api.nvim_get_current_tabpage()
    vim.t[tabpage].bufs = nil
    astro.event "BufsUpdated"
    vim.cmd.tabclose(vim.api.nvim_tabpage_get_number(tabpage))
  end
end

return M
