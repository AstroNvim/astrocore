---@meta

---@class AstroCoreMaxFile
---@field size integer?
---@field lines integer?

---@class AstroCoreFeatureOpts
---@field autopairs boolean?
---@field cmp boolean?
---@field highlighturl boolean?
---@field max_file AstroCoreMaxFile?
---@field notifications boolean?

---@class AstroCoreSessionAutosave
---@field last boolean?
---@field cwd boolean?

---@class AstroCoreSessionIgnore
---@field dirs string[]?
---@field filetypes string[]?
---@field buftypes string[]?

---@class AstroCoreSessionOpts
---@field autosave AstroCoreSessionAutosave?
---@field ignore AstroCoreSessionIgnore?

---@class GitWorktree
---@field toplevel string
---@field gitdir string

---@class AstroCoreConfig
---@field autocmds table<string,table[]>?
---@field commands table<string,table>?
---@field mappings table<string,table<string,table|boolean>>?
---@field on_keys table<string,fun(key:string)[]>?
---@field features AstroCoreFeatureOpts?
---@field git_worktrees GitWorktree[]?
---@field sessions AstroCoreSessionOpts?
