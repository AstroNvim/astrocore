---AstroNvim Buffer Comparators
---
---Buffer comparator functions for sorting buffers
---
---This module can be loaded with `local buffer_comparators = require "astrocore.buffer.comparator"`
---
---copyright 2023
---license GNU General Public License v3.0
---@class astrocore.buffer.comparator
local M = {}

local fnamemodify = vim.fn.fnamemodify
local function bufinfo(bufnr) return vim.fn.getbufinfo(bufnr)[1] end
local function unique_path(bufnr)
  local status_avail, provider = pcall(require, "astroui.status.provider")
  if not status_avail then
    vim.notify("AstroUI required for unique path calculation", vim.log.levels.ERROR, { title = "AstroNvim" })
    return ""
  end
  return provider.unique_path() { bufnr = bufnr } .. fnamemodify(bufinfo(bufnr).name, ":t")
end

--- Comparator of two buffer numbers
---@param bufnr_a integer buffer number A
---@param bufnr_b integer buffer number B
---@return boolean comparison true if A is sorted before B, false if B should be sorted before A
function M.bufnr(bufnr_a, bufnr_b) return bufnr_a < bufnr_b end

--- Comparator of two buffer numbers based on the file extensions
---@param bufnr_a integer buffer number A
---@param bufnr_b integer buffer number B
---@return boolean comparison true if A is sorted before B, false if B should be sorted before A
function M.extension(bufnr_a, bufnr_b)
  return fnamemodify(bufinfo(bufnr_a).name, ":e") < fnamemodify(bufinfo(bufnr_b).name, ":e")
end

--- Comparator of two buffer numbers based on the full path
---@param bufnr_a integer buffer number A
---@param bufnr_b integer buffer number B
---@return boolean comparison true if A is sorted before B, false if B should be sorted before A
function M.full_path(bufnr_a, bufnr_b)
  return fnamemodify(bufinfo(bufnr_a).name, ":p") < fnamemodify(bufinfo(bufnr_b).name, ":p")
end

--- Comparator of two buffers based on their unique path
---@param bufnr_a integer buffer number A
---@param bufnr_b integer buffer number B
---@return boolean comparison true if A is sorted before B, false if B should be sorted before A
function M.unique_path(bufnr_a, bufnr_b) return unique_path(bufnr_a) < unique_path(bufnr_b) end

--- Comparator of two buffers based on modification date
---@param bufnr_a integer buffer number A
---@param bufnr_b integer buffer number B
---@return boolean comparison true if A is sorted before B, false if B should be sorted before A
function M.modified(bufnr_a, bufnr_b) return bufinfo(bufnr_a).lastused > bufinfo(bufnr_b).lastused end

return M
