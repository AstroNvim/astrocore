---AstroNvim Core Utilities
---
---Various utility functions to use within AstroNvim and user configurations.
---
---This module can be loaded with `local astro = require "astrocore"`
---
---copyright 2023
---license GNU General Public License v3.0
---@class astrocore
local M = {}

--- The configuration as set by the user through the `setup()` function
M.config = require "astrocore.config"
--- A table to manage ToggleTerm terminals created by the user, indexed by the command run and then the instance number
---@type table<string,table<integer,table>>
M.user_terminals = {}

--- Merge extended options with a default table of options
---@param default? table The default table that you want to merge into
---@param opts? table The new options that should be merged with the default table
---@return table # The merged table
function M.extend_tbl(default, opts)
  opts = opts or {}
  return default and vim.tbl_deep_extend("force", default, opts) or opts
end

--- Sync Lazy and then update Mason
function M.update_packages()
  require("lazy").sync { wait = true }
  require("astrocore.mason").update_all()
end

--- Partially reload AstroNvim user settings. Includes core vim options, mappings, and highlights. This is an experimental feature and may lead to instabilities until restart.
function M.reload()
  local was_modifiable = vim.opt.modifiable:get()

  local reload_module = require("plenary.reload").reload_module
  reload_module "astronivm.options"
  if package.loaded["config.options"] then reload_module "config.options" end

  if not was_modifiable then vim.opt.modifiable = true end
  local success, fault = pcall(require, "astronvim.options")
  if not success then vim.api.nvim_err_writeln("Failed to load " .. module .. "\n\n" .. fault) end
  if not was_modifiable then vim.opt.modifiable = false end
  local lazy = require "lazy"
  lazy.reload { plugins = { M.get_plugin "astrocore" } }
  if M.is_available "astroui" then lazy.reload { plugins = { M.get_plugin "astroui" } } end
  vim.cmd.doautocmd "ColorScheme"
end

--- Insert one or more values into a list like table and maintain that you do not insert non-unique values (THIS MODIFIES `lst`)
---@param lst any[]|nil The list like table that you want to insert into
---@param ... any Values to be inserted
---@return any[] # The modified list like table
function M.list_insert_unique(lst, ...)
  if not lst then lst = {} end
  assert(vim.tbl_islist(lst), "Provided table is not a list like table")
  local added = {}
  vim.tbl_map(function(v) added[v] = true end, lst)
  for _, val in ipairs { ... } do
    if not added[val] then
      table.insert(lst, val)
      added[val] = true
    end
  end
  return lst
end

--- Call function if a condition is met
---@param func function The function to run
---@param condition boolean # Whether to run the function or not
---@return any|nil result # the result of the function running or nil
function M.conditional_func(func, condition, ...)
  -- if the condition is true or no condition is provided, evaluate the function with the rest of the parameters and return the result
  if condition and type(func) == "function" then return func(...) end
end

--- Get highlight properties for a given highlight name
---@param name string The highlight group name
---@param fallback? table The fallback highlight properties
---@return table properties # the highlight group properties
function M.get_hlgroup(name, fallback)
  if vim.fn.hlexists(name) == 1 then
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    if not hl.fg then hl.fg = "NONE" end
    if not hl.bg then hl.bg = "NONE" end
    return hl
  end
  return fallback or {}
end

--- Serve a notification with a title of AstroNvim
---@param msg string The notification body
---@param type integer|nil The type of the notification (:help vim.log.levels)
---@param opts? table The nvim-notify options to use (:help notify-options)
function M.notify(msg, type, opts)
  vim.schedule(function() vim.notify(msg, type, M.extend_tbl({ title = "AstroNvim" }, opts)) end)
end

--- Trigger an AstroNvim user event
---@param event string The event name to be appended to Astro
function M.event(event)
  vim.schedule(function() vim.api.nvim_exec_autocmds("User", { pattern = "Astro" .. event, modeline = false }) end)
end

--- Open a URL under the cursor with the current operating system
---@param path string The path of the file to open with the system opener
function M.system_open(path)
  -- TODO: remove deprecated method check after dropping support for neovim v0.9
  if vim.ui.open then return vim.ui.open(path) end
  local cmd
  if vim.fn.has "win32" == 1 and vim.fn.executable "explorer" == 1 then
    cmd = { "cmd.exe", "/K", "explorer" }
  elseif vim.fn.has "unix" == 1 and vim.fn.executable "xdg-open" == 1 then
    cmd = { "xdg-open" }
  elseif (vim.fn.has "mac" == 1 or vim.fn.has "unix" == 1) and vim.fn.executable "open" == 1 then
    cmd = { "open" }
  end
  if not cmd then M.notify("Available system opening tool not found!", vim.log.levels.ERROR) end
  vim.fn.jobstart(vim.fn.extend(cmd, { path or vim.fn.expand "<cfile>" }), { detach = true })
end

--- Toggle a user terminal if it exists, if not then create a new one and save it
---@param opts string|table A terminal command string or a table of options for Terminal:new() (Check toggleterm.nvim documentation for table format)
function M.toggle_term_cmd(opts)
  local terms = M.user_terminals
  -- if a command string is provided, create a basic table for Terminal:new() options
  if type(opts) == "string" then opts = { cmd = opts, hidden = true } end
  local num = vim.v.count > 0 and vim.v.count or 1
  -- if terminal doesn't exist yet, create it
  if not terms[opts.cmd] then terms[opts.cmd] = {} end
  if not terms[opts.cmd][num] then
    if not opts.count then opts.count = vim.tbl_count(terms) * 100 + num end
    if not opts.on_exit then opts.on_exit = function() terms[opts.cmd][num] = nil end end
    terms[opts.cmd][num] = require("toggleterm.terminal").Terminal:new(opts)
  end
  -- toggle the terminal
  terms[opts.cmd][num]:toggle()
end

--- Get a plugin spec from lazy
---@param plugin string The plugin to search for
---@return LazyPlugin? available # The found plugin spec from Lazy
function M.get_plugin(plugin)
  local lazy_config_avail, lazy_config = pcall(require, "lazy.core.config")
  return lazy_config_avail and lazy_config.spec.plugins[plugin] or nil
end

--- Check if a plugin is defined in lazy. Useful with lazy loading when a plugin is not necessarily loaded yet
---@param plugin string The plugin to search for
---@return boolean available # Whether the plugin is available
function M.is_available(plugin) return M.get_plugin(plugin) ~= nil end

--- Resolve the options table for a given plugin with lazy
---@param plugin string The plugin to search for
---@return table opts # The plugin options
function M.plugin_opts(plugin)
  local spec = M.get_plugin(plugin)
  return spec and require("lazy.core.plugin").values(spec, "opts") or {}
end

--- A helper function to wrap a module function to require a plugin before running
---@param plugin string The plugin to call `require("lazy").load` with
---@param module table The system module where the functions live (e.g. `vim.ui`)
---@param ... string The functions to wrap in the given module (e.g. `"ui", "select"`)
function M.load_plugin_with_func(plugin, module, ...)
  for _, func in ipairs { ... } do
    local old_func = module[func]
    module[func] = function(...)
      module[func] = old_func
      require("lazy").load { plugins = { plugin } }
      module[func](...)
    end
  end
end

--- Execute a function when a specified plugin is loaded with Lazy.nvim, or immediately if already loaded
---@param plugins string|string[] the name of the plugin or a list of plugins to defer the function execution on. If a list is provided, only one needs to be loaded to execute the provided function
---@param load_op fun()|string|string[] the function to execute when the plugin is loaded, a plugin name to load, or a list of plugin names to load
function M.on_load(plugins, load_op)
  local lazy_config_avail, lazy_config = pcall(require, "lazy.core.config")
  if lazy_config_avail then
    if type(plugins) == "string" then plugins = { plugins } end
    if type(load_op) ~= "function" then
      local to_load = type(load_op) == "string" and { load_op } or load_op --[=[@as string[]]=]
      load_op = function() require("lazy").load { plugins = to_load } end
    end

    for _, plugin in ipairs(plugins) do
      if vim.tbl_get(lazy_config.plugins, plugin, "_", "loaded") then
        vim.schedule(load_op)
        return
      end
    end
    local autocmd
    autocmd = vim.api.nvim_create_autocmd("User", {
      pattern = "LazyLoad",
      desc = ("A function to be ran when one of these plugins runs: %s"):format(vim.inspect(plugins)),
      callback = function(args)
        if vim.tbl_contains(plugins, args.data) then
          load_op()
          if autocmd then vim.api.nvim_del_autocmd(autocmd) end
        end
      end,
    })
  end
end

--- A placeholder variable used to queue section names to be registered by which-key
---@type table?
M.which_key_queue = nil

--- Register queued which-key mappings
function M.which_key_register()
  if M.which_key_queue then
    local wk_avail, wk = pcall(require, "which-key")
    if wk_avail then
      for mode, registration in pairs(M.which_key_queue) do
        wk.register(registration, { mode = mode })
      end
      M.which_key_queue = nil
    end
  end
end

--- Get an empty table of mappings with a key for each map mode
---@return table<string,table> # a table with entries for each map mode
function M.empty_map_table()
  local maps = {}
  for _, mode in ipairs { "", "n", "v", "x", "s", "o", "!", "i", "l", "c", "t" } do
    maps[mode] = {}
  end
  if vim.fn.has "nvim-0.10.0" == 1 then
    for _, abbr_mode in ipairs { "ia", "ca", "!a" } do
      maps[abbr_mode] = {}
    end
  end
  return maps
end

--- Table based API for setting keybindings
---@param map_table AstroCoreMappings A nested table where the first key is the vim mode, the second key is the key to map, and the value is the function to set the mapping to
---@param base? vim.api.keyset.keymap A base set of options to set on every keybinding
function M.set_mappings(map_table, base)
  local was_no_which_key_queue = not M.which_key_queue
  -- iterate over the first keys for each mode
  base = vim.tbl_deep_extend("force", { silent = true }, base or {})
  for mode, maps in pairs(map_table) do
    -- iterate over each keybinding set in the current mode
    for keymap, options in pairs(maps) do
      -- build the options for the command accordingly
      if options then
        local cmd
        local keymap_opts = base
        if type(options) == "string" then
          cmd = options
        else
          cmd = options[1]
          keymap_opts = vim.tbl_deep_extend("force", keymap_opts, options)
          keymap_opts[1] = nil
        end
        if not cmd or keymap_opts.name then -- if which-key mapping, queue it
          if not keymap_opts.name then keymap_opts.name = keymap_opts.desc end
          if not M.which_key_queue then M.which_key_queue = {} end
          if not M.which_key_queue[mode] then M.which_key_queue[mode] = {} end
          M.which_key_queue[mode][keymap] = keymap_opts
        else -- if not which-key mapping, set it
          vim.keymap.set(mode, keymap, cmd, keymap_opts)
        end
      end
    end
  end
  if was_no_which_key_queue and M.which_key_queue then M.on_load("which-key.nvim", M.which_key_register) end
end

--- regex used for matching a valid URL/URI string
M.url_matcher =
  "\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*})\\})+"

--- Delete the syntax matching rules for URLs/URIs if set
function M.delete_url_match()
  for _, match in ipairs(vim.fn.getmatches()) do
    if match.group == "HighlightURL" then vim.fn.matchdelete(match.id) end
  end
end

--- Add syntax matching rules for highlighting URLs/URIs
function M.set_url_match()
  M.delete_url_match()
  if require("astrocore").config.features.highlighturl then vim.fn.matchadd("HighlightURL", M.url_matcher, 15) end
end

--- Run a shell command and capture the output and if the command succeeded or failed
---@param cmd string|string[] The terminal command to execute
---@param show_error? boolean Whether or not to show an unsuccessful command as an error to the user
---@return string|nil # The result of a successfully executed command or nil
function M.cmd(cmd, show_error)
  if type(cmd) == "string" then cmd = { cmd } end
  if vim.fn.has "win32" == 1 then cmd = vim.list_extend({ "cmd.exe", "/C" }, cmd) end
  local result = vim.fn.system(cmd)
  local success = vim.api.nvim_get_vvar "shell_error" == 0
  if not success and (show_error == nil or show_error) then
    vim.api.nvim_err_writeln(("Error running command %s\nError message:\n%s"):format(table.concat(cmd, " "), result))
  end
  return success and assert(result):gsub("[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]", "") or nil
end

--- Get the first worktree that a file belongs to
---@param file string? the file to check, defaults to the current file
---@param worktrees table<string, string>[]? an array like table of worktrees with entries `toplevel` and `gitdir`, default retrieves from `vim.g.git_worktrees`
---@return table<string, string>|nil # a table specifying the `toplevel` and `gitdir` of a worktree or nil if not found
function M.file_worktree(file, worktrees)
  worktrees = worktrees or require("astrocore").config.git_worktrees
  if not worktrees then return end
  file = file or vim.fn.expand "%" --[[@as string]]
  for _, worktree in ipairs(worktrees) do
    if
      M.cmd({
        "git",
        "--work-tree",
        worktree.toplevel,
        "--git-dir",
        worktree.gitdir,
        "ls-files",
        "--error-unmatch",
        file,
      }, false)
    then
      return worktree
    end
  end
end

--- Setup and configure AstroCore
---@param opts AstroCoreOpts
---@see astrocore.config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- mappings
  M.set_mappings(M.config.mappings)

  -- autocmds
  for augroup, autocmds in pairs(M.config.autocmds) do
    if autocmds then
      local augroup_id = vim.api.nvim_create_augroup(augroup, { clear = true })
      for _, autocmd in ipairs(autocmds) do
        local event = autocmd.event
        autocmd.event = nil
        autocmd.group = augroup_id
        vim.api.nvim_create_autocmd(event, autocmd)
        autocmd.event = event
      end
    end
  end

  -- user commands
  for cmd, spec in pairs(M.config.commands) do
    if spec then
      local action = spec[1]
      spec[1] = nil
      vim.api.nvim_create_user_command(cmd, action, spec)
      spec[1] = action
    end
  end

  -- on_key hooks
  for namespace, funcs in pairs(M.config.on_keys) do
    if funcs then
      local ns = vim.api.nvim_create_namespace(namespace)
      for _, func in ipairs(funcs) do
        vim.on_key(func, ns)
      end
    end
  end

  if M.config.rooter then
    local root_config = M.config.rooter --[[@as AstroCoreRooterOpts]]
    vim.api.nvim_create_user_command(
      "AstroRootInfo",
      function() require("astrocore.rooter").info() end,
      { desc = "Display rooter information" }
    )
    vim.api.nvim_create_user_command(
      "AstroRoot",
      function() require("astrocore.rooter").root() end,
      { desc = "Run root detection" }
    )

    local group = vim.api.nvim_create_augroup("rooter", { clear = true }) -- clear the augroup no matter what
    if root_config.autochdir then
      vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
        nested = true,
        group = group,
        desc = "Root detection when entering a buffer",
        callback = function(args) require("astrocore.rooter").root(args.buf) end,
      })
      if vim.tbl_contains(root_config.detector or {}, "lsp") then
        vim.api.nvim_create_autocmd("LspAttach", {
          nested = true,
          group = group,
          desc = "Root detection on LSP attach",
          callback = function(args)
            local server = assert(vim.lsp.get_client_by_id(args.data.client_id)).name
            if not vim.tbl_contains(vim.tbl_get(root_config, "ignore", "servers") or {}, server) then
              require("astrocore.rooter").root(args.buf)
            end
          end,
        })
      end
    end
  end
end

return M
