# Lua API

astrocore API documentation

## astrocore

### cmd


```lua
function astrocore.cmd(cmd: string|string[], show_error?: boolean)
  -> result: string|nil
```

 Run a shell command and capture the output and if the command succeeded or failed

*param* `cmd` — The terminal command to execute

*param* `show_error` — Whether or not to show an unsuccessful command as an error to the user

*return* `result` — The result of a successfully executed command or nil

### conditional_func


```lua
function astrocore.conditional_func(func: function, condition: boolean, ...any)
  -> result: any
```

 Call function if a condition is met

*param* `func` — The function to run

*param* `condition` — Whether to run the function or not

*return* `result` — the result of the function running or nil

### config


```lua
AstroCoreOpts
```

 The configuration as set by the user through the `setup()` function

### delete_url_match


```lua
function astrocore.delete_url_match(win?: integer)
```

 Delete the syntax matching rules for URLs/URIs if set

*param* `win` — the window id to remove url highlighting in (default: current window)

### empty_map_table


```lua
function astrocore.empty_map_table()
  -> mappings: table<string, table>
```

 Get an empty table of mappings with a key for each map mode

*return* `mappings` — a table with entries for each map mode

### event


```lua
function astrocore.event(event: string|vim.api.keyset_exec_autocmds, instant?: boolean)
```

 Trigger an AstroNvim user event

*param* `event` — The event pattern or full autocmd options (pattern always prepended with "Astro")

*param* `instant` — Whether or not to execute instantly or schedule

### exec_buffer_autocmds


```lua
function astrocore.exec_buffer_autocmds(event: string|string[], opts: vim.api.keyset.exec_autocmds)
```

 Execute autocommand across all valid buffers

*param* `event` — the event or events to execute

*param* `opts` — Dictionary of autocommnd options

### extend_tbl


```lua
function astrocore.extend_tbl(default?: table, opts?: table)
  -> extended: table
```

 Merge extended options with a default table of options

*param* `default` — The default table that you want to merge into

*param* `opts` — The new options that should be merged with the default table

*return* `extended` — The extended table

### file_worktree


```lua
function astrocore.file_worktree(file?: string, worktrees?: table<string, string>[])
  -> worktree: table<string, string>|nil
```

 Get the first worktree that a file belongs to

*param* `file` — the file to check, defaults to the current file

*param* `worktrees` — an array like table of worktrees with entries `toplevel` and `gitdir`, default retrieves from `vim.g.git_worktrees`

*return* `worktree` — a table specifying the `toplevel` and `gitdir` of a worktree or nil if not found

### get_plugin


```lua
function astrocore.get_plugin(plugin: string)
  -> spec: LazyPlugin?
```

 Get a plugin spec from lazy

*param* `plugin` — The plugin to search for

*return* `spec` — The found plugin spec from Lazy

### is_available


```lua
function astrocore.is_available(plugin: string)
  -> available: boolean
```

 Check if a plugin is defined in lazy. Useful with lazy loading when a plugin is not necessarily loaded yet

*param* `plugin` — The plugin to search for

*return* `available` — Whether the plugin is available

### list_insert_unique


```lua
function astrocore.list_insert_unique(dst: any[]|nil, src: any[])
  -> result: any[]
```

 Insert one or more values into a list like table and maintain that you do not insert non-unique values (THIS MODIFIES `dst`)

*param* `dst` — The list like table that you want to insert into

*param* `src` — Values to be inserted

*return* `result` — The modified list like table

### load_plugin_with_func


```lua
function astrocore.load_plugin_with_func(plugin: string, module: table, funcs: string|string[])
```

 A helper function to wrap a module function to require a plugin before running

*param* `plugin` — The plugin to call `require("lazy").load` with

*param* `module` — The system module where the functions live (e.g. `vim.ui`)

*param* `funcs` — The functions to wrap in the given module (e.g. `"ui", "select"`)

### normalize_mappings


```lua
function astrocore.normalize_mappings(mappings?: table<string, table<string, (string|function|AstroCoreMapping|false)?>?>)
```

 Normalize a mappings table to use official keycode casing

### notify


```lua
function astrocore.notify(msg: string, type: integer|nil, opts?: table)
```

 Serve a notification with a title of AstroNvim

*param* `msg` — The notification body

*param* `type` — The type of the notification (:help vim.log.levels)

*param* `opts` — The nvim-notify options to use (:help notify-options)

### on_load


```lua
function astrocore.on_load(plugins: string|string[], load_op: string|fun()|string[])
```

 Execute a function when a specified plugin is loaded with Lazy.nvim, or immediately if already loaded

*param* `plugins` — the name of the plugin or a list of plugins to defer the function execution on. If a list is provided, only one needs to be loaded to execute the provided function

*param* `load_op` — the function to execute when the plugin is loaded, a plugin name to load, or a list of plugin names to load

### patch_func


```lua
function astrocore.patch_func(orig?: function, override: fun(orig: function, ...any):...unknown)
  -> patched: function
```

 Monkey patch into an existing function

 Example from `:h vim.paste()`
 ```lua
 local patch_func = require("astrocore").patch_func
 vim.paste = patch_func(vim.paste, function(orig, lines, phase)
   for i, line in ipairs(lines) do
     -- Scrub ANSI color codes from paste input.
     lines[i] = line:gsub('\27%[[0-9;mK]+', '')
   end
   return orig(lines, phase)
 end)
 ```

*param* `orig` — the original function to override, if `nil` is provided then an empty function is passed

*param* `override` — the override function

*return* `patched` — the new function with the patch applied

### plugin_opts


```lua
function astrocore.plugin_opts(plugin: string)
  -> opts: table
```

 Resolve the options table for a given plugin with lazy

*param* `plugin` — The plugin to search for

*return* `opts` — The plugin options

### read_file


```lua
function astrocore.read_file(path: string)
  -> content: string
```

 Helper function to read a file and return it's content

*param* `path` — the path to the file to read

*return* `content` — the contents of the file

### reload


```lua
function astrocore.reload()
```

 Partially reload AstroNvim user settings. Includes core vim options, mappings, and highlights. This is an experimental feature and may lead to instabilities until restart.

### rename_file


```lua
function astrocore.rename_file(opts?: AstroCoreRenameFileOpts)
```

 Prompt the user to rename a file

*param* `opts` — optional fields for file renaming

### set_mappings


```lua
function astrocore.set_mappings(map_table: table<string, table<string, (string|function|AstroCoreMapping|false)?>?>, base?: vim.keymap.set.Opts)
```

 Table based API for setting keybindings

*param* `map_table` — A nested table where the first key is the vim mode, the second key is the key to map, and the value is the function to set the mapping to

*param* `base` — A base set of options to set on every keybinding

### set_url_match


```lua
function astrocore.set_url_match(win?: integer)
```

 Add syntax matching rules for highlighting URLs/URIs

*param* `win` — the window id to remove url highlighting in (default: current window)

### setup


```lua
function astrocore.setup(opts: AstroCoreOpts)
```

 Setup and configure AstroCore
See: [astrocore.config](file:///home/runner/work/astrocore/astrocore/lua/astrocore/init.lua#13#0)

### toggle_term_cmd


```lua
function astrocore.toggle_term_cmd(opts: string|table)
```

 Toggle a user terminal if it exists, if not then create a new one and save it

*param* `opts` — A terminal command string or a table of options for Terminal:new() (Check toggleterm.nvim documentation for table format)

### unique_list


```lua
function astrocore.unique_list(list: any[])
  -> result: any[]
```

 Remove duplicate entries from a given list (does not mutate the  original list)

*param* `list` — The list like table that you want to remove duplicates from

*return* `result` — The list like table of unique values

### update_packages


```lua
function astrocore.update_packages()
```

 Sync Lazy and then update Mason

### url_matcher


```lua
string
```

 regex used for matching a valid URL/URI string

### user_terminals


```lua
{ [string]: table<integer, table> }
```

 A table to manage ToggleTerm terminals created by the user, indexed by the command run and then the instance number

### which_key_queue


```lua
nil
```

 A placeholder variable used to queue section names to be registered by which-key

### which_key_register


```lua
function astrocore.which_key_register()
```

 Register queued which-key mappings

### with_file


```lua
function astrocore.with_file(filename: string, mode?: "a"|"a+"|"a+b"|"ab"|"r"...(+7), callback?: fun(file: file*), on_error?: fun(err: string))
```

 Execute function with open file

*param* `filename` — path to file to interact with

*param* `mode` — the mode in which to open the file

*param* `callback` — the callback to execute with the opened file

*param* `on_error` — the callback to execute if unable to open the file

```lua
mode:
   -> "r" -- Read mode.
    | "w" -- Write mode.
    | "a" -- Append mode.
    | "r+" -- Update mode, all previous data is preserved.
    | "w+" -- Update mode, all previous data is erased.
    | "a+" -- Append update mode, previous data is preserved, writing is only allowed at the end of file.
    | "rb" -- Read mode. (in binary mode.)
    | "wb" -- Write mode. (in binary mode.)
    | "ab" -- Append mode. (in binary mode.)
    | "r+b" -- Update mode, all previous data is preserved. (in binary mode.)
    | "w+b" -- Update mode, all previous data is erased. (in binary mode.)
    | "a+b" -- Append update mode, previous data is preserved, writing is only allowed at the end of file. (in binary mode.)
```


## astrocore.buffer

### close


```lua
function astrocore.buffer.close(bufnr?: integer, force?: boolean)
```

 Close a given buffer

*param* `bufnr` — The buffer to close or the current buffer if not provided

*param* `force` — Whether or not to foce close the buffers or confirm changes (default: false)

### close_all


```lua
function astrocore.buffer.close_all(keep_current?: boolean, force?: boolean)
```

 Close all buffers

*param* `keep_current` — Whether or not to keep the current buffer (default: false)

*param* `force` — Whether or not to foce close the buffers or confirm changes (default: false)

### close_left


```lua
function astrocore.buffer.close_left(force?: boolean)
```

 Close buffers to the left of the current buffer

*param* `force` — Whether or not to foce close the buffers or confirm changes (default: false)

### close_right


```lua
function astrocore.buffer.close_right(force?: boolean)
```

 Close buffers to the right of the current buffer

*param* `force` — Whether or not to foce close the buffers or confirm changes (default: false)

### close_tab


```lua
function astrocore.buffer.close_tab(tabpage?: integer)
```

 Close a given tab

*param* `tabpage` — The tabpage to close or the current tab if not provided

### current_buf


```lua
nil
```

 Placeholders for keeping track of most recent and previous buffer

### has_filetype


```lua
function astrocore.buffer.has_filetype(bufnr?: integer)
  -> boolean
```

 Check if a buffer has a filetype

*param* `bufnr` — The buffer to check, default to current buffer

*return* — Whether the buffer has a filetype or not

### is_large


```lua
function astrocore.buffer.is_large(bufnr?: integer, large_buf_opts?: AstroCoreMaxFile)
  -> is_large: boolean
```

 Check if a buffer is a large buffer (always returns false if large buffer detection is disabled)

*param* `bufnr` — the buffer to check the size of, default to current buffer

*param* `large_buf_opts` — large buffer parameters, default to AstroCore configuration

*return* `is_large` — whether the buffer is detected as large or not

### is_restorable


```lua
function astrocore.buffer.is_restorable(bufnr: integer)
  -> boolean
```

 Check if a buffer can be restored

*param* `bufnr` — The buffer to check

*return* — Whether the buffer is restorable or not

### is_valid


```lua
function astrocore.buffer.is_valid(bufnr?: integer)
  -> boolean
```

 Check if a buffer is valid

*param* `bufnr` — The buffer to check, default to current buffer

*return* — Whether the buffer is valid or not

### is_valid_session


```lua
function astrocore.buffer.is_valid_session()
  -> boolean
```

 Check if the current buffers form a valid session

*return* — Whether the current session of buffers is a valid session

### last_buf


```lua
nil
```

### move


```lua
function astrocore.buffer.move(n: integer)
```

 Move the current buffer tab n places in the bufferline

*param* `n` — The number of tabs to move the current buffer over by (positive = right, negative = left)

### nav


```lua
function astrocore.buffer.nav(n: integer)
```

 Navigate left and right by n places in the bufferline

*param* `n` — The number of tabs to navigate to (positive = right, negative = left)

### nav_to


```lua
function astrocore.buffer.nav_to(tabnr: integer)
```

 Navigate to a specific buffer by its position in the bufferline

*param* `tabnr` — The position of the buffer to navigate to

### prev


```lua
function astrocore.buffer.prev()
```

 Navigate to the previously used buffer

### sort


```lua
function astrocore.buffer.sort(compare_func: string|function, skip_autocmd: boolean|nil)
  -> boolean
```

 Sort a the buffers in the current tab based on some comparator

*param* `compare_func` — a string of a comparator defined in require("astrocore.buffer.comparator") or a custom comparator function

*param* `skip_autocmd` — whether or not to skip triggering AstroBufsUpdated autocmd event

*return* — Whether or not the buffers were sorted

### wipe


```lua
function astrocore.buffer.wipe(bufnr?: integer, force?: boolean)
```

 Fully wipeout a given buffer

*param* `bufnr` — The buffer to wipe or the current buffer if not provided

*param* `force` — Whether or not to foce close the buffers or confirm changes (default: false)


## astrocore.buffer.comparator

### bufnr


```lua
function astrocore.buffer.comparator.bufnr(bufnr_a: integer, bufnr_b: integer)
  -> comparison: boolean
```

 Comparator of two buffer numbers

*param* `bufnr_a` — buffer number A

*param* `bufnr_b` — buffer number B

*return* `comparison` — true if A is sorted before B, false if B should be sorted before A

### extension


```lua
function astrocore.buffer.comparator.extension(bufnr_a: integer, bufnr_b: integer)
  -> comparison: boolean
```

 Comparator of two buffer numbers based on the file extensions

*param* `bufnr_a` — buffer number A

*param* `bufnr_b` — buffer number B

*return* `comparison` — true if A is sorted before B, false if B should be sorted before A

### full_path


```lua
function astrocore.buffer.comparator.full_path(bufnr_a: integer, bufnr_b: integer)
  -> comparison: boolean
```

 Comparator of two buffer numbers based on the full path

*param* `bufnr_a` — buffer number A

*param* `bufnr_b` — buffer number B

*return* `comparison` — true if A is sorted before B, false if B should be sorted before A

### modified


```lua
function astrocore.buffer.comparator.modified(bufnr_a: integer, bufnr_b: integer)
  -> comparison: boolean
```

 Comparator of two buffers based on modification date

*param* `bufnr_a` — buffer number A

*param* `bufnr_b` — buffer number B

*return* `comparison` — true if A is sorted before B, false if B should be sorted before A

### unique_path


```lua
function astrocore.buffer.comparator.unique_path(bufnr_a: integer, bufnr_b: integer)
  -> comparison: boolean
```

 Comparator of two buffers based on their unique path

*param* `bufnr_a` — buffer number A

*param* `bufnr_b` — buffer number B

*return* `comparison` — true if A is sorted before B, false if B should be sorted before A


## astrocore.rooter

### bufpath


```lua
function astrocore.rooter.bufpath(bufnr: integer)
  -> path: string?
```

 Get the real path of a buffer

*param* `bufnr` — the buffer

*return* `path` — the real path

### detect


```lua
function astrocore.rooter.detect(bufnr?: integer, all?: boolean, config?: AstroCoreRooterOpts)
  -> detected: AstroCoreRooterRoot[]
```

 Detect roots in a given buffer

*param* `bufnr` — the buffer to detect

*param* `all` — whether to return all roots or just one

*param* `config` — a rooter configuration (defaults to global configuration)

*return* `detected` — roots

### exists


```lua
function astrocore.rooter.exists(path: string)
  -> exists: boolean
```

 Check if a path exists

*param* `path` — the path

*return* `exists` — whether or not the path exists

### info


```lua
function astrocore.rooter.info(config?: AstroCoreRooterOpts)
```

 Get information information about the current root

*param* `config` — a rooter configuration (defaults to global configuration)

### is_excluded


```lua
function astrocore.rooter.is_excluded(path: string, config?: AstroCoreRooterOpts)
  -> excluded: boolean
```

 Check if a path is excluded

*param* `path` — the path

*param* `config` — a rooter configuration (defaults to global configuration)

*return* `excluded` — whether or not the path is excluded

### normpath


```lua
function astrocore.rooter.normpath(path: string)
  -> string
```

 Normalize path

### realpath


```lua
function astrocore.rooter.realpath(path?: string)
  -> the: string?
```

 Resolve a given path

*param* `path` — the path to resolve

*return* `the` — resolved path

### resolve


```lua
function astrocore.rooter.resolve(spec: string|fun(bufnr: integer):string|string[]|nil|string[], config?: AstroCoreRooterOpts)
  -> function
```

 Resolve the root detection function for a given spec

*param* `spec` — the root detector specification

*param* `config` — the root configuration

### root


```lua
function astrocore.rooter.root(bufnr?: integer, config?: AstroCoreRooterOpts)
```

 Run the root detection and set the current working directory if a new root is detected

*param* `bufnr` — the buffer to detect

*param* `config` — a rooter configuration (defaults to global configuration)

### set_pwd


```lua
function astrocore.rooter.set_pwd(root: AstroCoreRooterRoot, config?: AstroCoreRooterOpts)
  -> success: boolean
```

 Set the current directory to a given root

*param* `root` — the root to set the pwd to

*param* `config` — a rooter configuration (defaults to global configuration)

*return* `success` — whether or not the pwd was successfully set


## astrocore.toggles

### autochdir


```lua
function astrocore.toggles.autochdir(silent?: boolean)
```

 Toggle rooter autochdir

*param* `silent` — if true then don't sent a notification

### autopairs


```lua
function astrocore.toggles.autopairs(silent?: boolean)
```

 Toggle autopairs

*param* `silent` — if true then don't sent a notification

### background


```lua
function astrocore.toggles.background(silent?: boolean)
```

 Toggle background="dark"|"light"

*param* `silent` — if true then don't sent a notification

### buffer_cmp


```lua
function astrocore.toggles.buffer_cmp(bufnr?: integer, silent?: boolean)
```

 Toggle buffer local cmp

*param* `bufnr` — the buffer to toggle cmp completion on

*param* `silent` — if true then don't sent a notification

### buffer_syntax


```lua
function astrocore.toggles.buffer_syntax(bufnr?: integer, silent?: boolean)
```

 Toggle syntax highlighting and treesitter

*param* `bufnr` — the buffer to toggle syntax on

*param* `silent` — if true then don't sent a notification

### cmp


```lua
function astrocore.toggles.cmp(silent?: boolean)
```

 Toggle cmp entrirely

*param* `silent` — if true then don't sent a notification

### conceal


```lua
function astrocore.toggles.conceal(silent?: boolean)
```

 Toggle conceal=2|0

*param* `silent` — if true then don't sent a notification

### diagnostics


```lua
function astrocore.toggles.diagnostics(silent?: boolean)
```

 Toggle diagnostics

*param* `silent` — if true then don't sent a notification

### foldcolumn


```lua
function astrocore.toggles.foldcolumn(silent?: boolean)
```

 Toggle foldcolumn=0|1

*param* `silent` — if true then don't sent a notification

### indent


```lua
function astrocore.toggles.indent(silent?: boolean)
```

 Set the indent and tab related numbers

*param* `silent` — if true then don't sent a notification

### notifications


```lua
function astrocore.toggles.notifications(silent?: boolean)
```

 Toggle notifications for UI toggles

*param* `silent` — if true then don't sent a notification

### number


```lua
function astrocore.toggles.number(silent?: boolean)
```

 Change the number display modes

*param* `silent` — if true then don't sent a notification

### paste


```lua
function astrocore.toggles.paste(silent?: boolean)
```

 Toggle paste

*param* `silent` — if true then don't sent a notification

### signcolumn


```lua
function astrocore.toggles.signcolumn(silent?: boolean)
```

 Toggle signcolumn="auto"|"no"

*param* `silent` — if true then don't sent a notification

### spell


```lua
function astrocore.toggles.spell(silent?: boolean)
```

 Toggle spell

*param* `silent` — if true then don't sent a notification

### statusline


```lua
function astrocore.toggles.statusline(silent?: boolean)
```

 Toggle laststatus=3|2|0

*param* `silent` — if true then don't sent a notification

### tabline


```lua
function astrocore.toggles.tabline(silent?: boolean)
```

 Toggle showtabline=2|0

*param* `silent` — if true then don't sent a notification

### url_match


```lua
function astrocore.toggles.url_match(silent?: boolean)
```

 Toggle URL/URI syntax highlighting rules

*param* `silent` — if true then don't sent a notification

### virtual_lines


```lua
function astrocore.toggles.virtual_lines(silent?: boolean)
```

 Toggle diagnostics virtual lines

*param* `silent` — if true then don't sent a notification

### virtual_text


```lua
function astrocore.toggles.virtual_text(silent?: boolean)
```

 Toggle diagnostics virtual text

*param* `silent` — if true then don't sent a notification

### wrap


```lua
function astrocore.toggles.wrap(silent?: boolean)
```

 Toggle wrap

*param* `silent` — if true then don't sent a notification


