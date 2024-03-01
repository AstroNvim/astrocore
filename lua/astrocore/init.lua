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
  local lazy, was_modifiable = require "lazy", vim.opt.modifiable:get()
  if not was_modifiable then vim.opt.modifiable = true end
  lazy.reload { plugins = { M.get_plugin "astrocore" } }
  if not was_modifiable then vim.opt.modifiable = false end
  if M.is_available "astroui" then lazy.reload { plugins = { M.get_plugin "astroui" } } end
  vim.cmd.doautocmd "ColorScheme"
end

--- Insert one or more values into a list like table and maintain that you do not insert non-unique values (THIS MODIFIES `dst`)
---@param dst any[]|nil The list like table that you want to insert into
---@param src any[] Values to be inserted
---@return any[] # The modified list like table
function M.list_insert_unique(dst, src)
  if not dst then dst = {} end
  assert(vim.tbl_islist(dst), "Provided table is not a list like table")
  local added = {}
  for _, val in ipairs(dst) do
    added[val] = true
  end
  for _, val in ipairs(src) do
    if not added[val] then
      table.insert(dst, val)
      added[val] = true
    end
  end
  return dst
end

--- Call function if a condition is met
---@param func function The function to run
---@param condition boolean # Whether to run the function or not
---@return any|nil result # the result of the function running or nil
function M.conditional_func(func, condition, ...)
  -- if the condition is true or no condition is provided, evaluate the function with the rest of the parameters and return the result
  if condition and type(func) == "function" then return func(...) end
end

--- Serve a notification with a title of AstroNvim
---@param msg string The notification body
---@param type integer|nil The type of the notification (:help vim.log.levels)
---@param opts? table The nvim-notify options to use (:help notify-options)
function M.notify(msg, type, opts)
  vim.schedule(function() vim.notify(msg, type, M.extend_tbl({ title = "AstroNvim" }, opts)) end)
end

--- Trigger an AstroNvim user event
---@param event string|vim.api.keyset_exec_autocmds The event pattern or full autocmd options (pattern always prepended with "Astro")
---@param instant boolean? Whether or not to execute instantly or schedule
function M.event(event, instant)
  if type(event) == "string" then event = { pattern = event } end
  event = M.extend_tbl({ modeline = false }, event)
  event.pattern = "Astro" .. event.pattern
  if instant then
    vim.api.nvim_exec_autocmds("User", event)
  else
    vim.schedule(function() vim.api.nvim_exec_autocmds("User", event) end)
  end
end

--- Open a URL under the cursor with the current operating system
---@param path string The path of the file to open with the system opener
function M.system_open(path)
  -- TODO: remove deprecated method check after dropping support for neovim v0.9
  if vim.ui.open then return vim.ui.open(path) end
  local cmd
  if vim.fn.has "mac" == 1 then
    cmd = { "open" }
  elseif vim.fn.has "win32" == 1 then
    if vim.fn.executable "rundll32" then
      cmd = { "rundll32", "url.dll,FileProtocolHandler" }
    else
      cmd = { "cmd.exe", "/K", "explorer" }
    end
  elseif vim.fn.has "unix" == 1 then
    if vim.fn.executable "explorer.exe" == 1 then
      cmd = { "explorer.exe" }
    elseif vim.fn.executable "xdg-open" == 1 then
      cmd = { "xdg-open" }
    end
  end
  if not cmd then M.notify("Available system opening tool not found!", vim.log.levels.ERROR) end
  if not path then
    path = vim.fn.expand "<cfile>"
  elseif not path:match "%w+:" then
    path = vim.fn.expand(path)
  end
  vim.fn.jobstart(vim.list_extend(cmd, { path }), { detach = true })
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
---@param funcs string|string[] The functions to wrap in the given module (e.g. `"ui", "select"`)
function M.load_plugin_with_func(plugin, module, funcs)
  if type(funcs) == "string" then funcs = { funcs } end
  for _, func in ipairs(funcs) do
    local old_func = module[func]
    module[func] = function(...)
      module[func] = old_func
      local vars = vim.F.pack_len(...)
      vim.schedule(function()
        require("lazy").load { plugins = { plugin } }
        module[func](vim.F.unpack_len(vars))
      end)
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
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyLoad",
      desc = ("A function to be ran when one of these plugins runs: %s"):format(vim.inspect(plugins)),
      callback = function(args)
        if vim.tbl_contains(plugins, args.data) then
          load_op()
          return true
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

  -- options
  if vim.bo.filetype == "lazy" then vim.cmd.bw() end
  for scope, settings in pairs(M.config.options) do
    for setting, value in pairs(settings) do
      vim[scope][setting] = value
    end
  end

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

  -- vim.filetype
  if M.config.filetypes then vim.filetype.add(M.config.filetypes) end

  -- on_key hooks
  for namespace, funcs in pairs(M.config.on_keys) do
    if funcs then
      local ns = vim.api.nvim_create_namespace(namespace)
      for _, func in ipairs(funcs) do
        vim.on_key(func, ns)
      end
    end
  end

  local large_buf = M.config.features.large_buf
  if large_buf then
    vim.api.nvim_create_autocmd("BufRead", {
      group = vim.api.nvim_create_augroup("large_buf_detector", { clear = true }),
      desc = "Root detection when entering a buffer",
      callback = function(args)
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(args.buf))
        if
          (ok and stats and stats.size > large_buf.size) or vim.api.nvim_buf_line_count(args.buf) > large_buf.lines
        then
          vim.b[args.buf].large_buf = true
          M.event("LargeBuf", true)
        end
      end,
    })
  end

  -- initialize rooter
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
    vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
      nested = true,
      group = group,
      desc = "Root detection when entering a buffer",
      callback = function(args)
        if root_config.autochdir then require("astrocore.rooter").root(args.buf) end
      end,
    })
    if vim.tbl_contains(root_config.detector or {}, "lsp") then
      vim.api.nvim_create_autocmd("LspAttach", {
        nested = true,
        group = group,
        desc = "Root detection on LSP attach",
        callback = function(args)
          if root_config.autochdir then
            local server = assert(vim.lsp.get_client_by_id(args.data.client_id)).name
            if not vim.tbl_contains(vim.tbl_get(root_config, "ignore", "servers") or {}, server) then
              require("astrocore.rooter").root(args.buf)
            end
          end
        end,
      })
    end
  end
end

return M
