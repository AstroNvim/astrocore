# Lua API

astrocore API documentation

## astrocore

AstroNvim Core Utilities

Various utility functions to use within AstroNvim and user configurations.

This module can be loaded with `local astro = require "astrocore"`

copyright 2023
license GNU General Public License v3.0

### cmd


```lua
function astrocore.cmd(cmd: string|string[], show_error?: boolean)
  -> string|nil
```

 Run a shell command and capture the output and if the command succeeded or failed

*param* `cmd` — The terminal command to execute

*param* `show_error` — Whether or not to show an unsuccessful command as an error to the user

*return* — The result of a successfully executed command or nil

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
function astrocore.delete_url_match()
```

 Delete the syntax matching rules for URLs/URIs if set

### empty_map_table


```lua
function astrocore.empty_map_table()
  -> table<string, table>
```

 Get an empty table of mappings with a key for each map mode

*return* — a table with entries for each map mode

### event


```lua
function astrocore.event(event: string)
```

 Trigger an AstroNvim user event

*param* `event` — The event name to be appended to Astro

### extend_tbl


```lua
function astrocore.extend_tbl(default?: table, opts?: table)
  -> table
```

 Merge extended options with a default table of options

*param* `default` — The default table that you want to merge into

*param* `opts` — The new options that should be merged with the default table

*return* — The merged table

### file_worktree


```lua
function astrocore.file_worktree(file?: string, worktrees?: table<string, string>[])
  -> table<string, string>|nil
```

 Get the first worktree that a file belongs to

*param* `file` — the file to check, defaults to the current file

*param* `worktrees` — an array like table of worktrees with entries `toplevel` and `gitdir`, default retrieves from `vim.g.git_worktrees`

*return* — a table specifying the `toplevel` and `gitdir` of a worktree or nil if not found

### get_hlgroup


```lua
function astrocore.get_hlgroup(name: string, fallback?: table)
  -> properties: table
```

 Get highlight properties for a given highlight name

*param* `name` — The highlight group name

*param* `fallback` — The fallback highlight properties

*return* `properties` — the highlight group properties

### get_plugin


```lua
function astrocore.get_plugin(plugin: string)
  -> available: LazyPlugin?
```

 Get a plugin spec from lazy

*param* `plugin` — The plugin to search for

*return* `available` — The found plugin spec from Lazy

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
function astrocore.list_insert_unique(lst: any[]|nil, vals: any)
  -> any[]
```

 Insert one or more values into a list like table and maintain that you do not insert non-unique values (THIS MODIFIES `lst`)

*param* `lst` — The list like table that you want to insert into

*param* `vals` — Either a list like table of values to be inserted or a single value to be inserted

*return* — The modified list like table

### load_plugin_with_func


```lua
function astrocore.load_plugin_with_func(plugin: string, module: table, func_names: string|string[])
```

 A helper function to wrap a module function to require a plugin before running

*param* `plugin` — The plugin to call `require("lazy").load` with

*param* `module` — The system module where the functions live (e.g. `vim.ui`)

*param* `func_names` — The functions to wrap in the given module (e.g. `{ "ui", "select }`)

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
function astrocore.on_load(plugins: string|string[], func: fun())
```

 Execute a function when a specified plugin is loaded with Lazy.nvim, or immediately if already loaded

*param* `plugins` — the name of the plugin or a list of plugins to defer the function execution on. If a list is provided, only one needs to be loaded to execute the provided function

*param* `func` — the function to execute when the plugin is loaded

### plugin_opts


```lua
function astrocore.plugin_opts(plugin: string)
  -> opts: table
```

 Resolve the options table for a given plugin with lazy

*param* `plugin` — The plugin to search for

*return* `opts` — The plugin options

### reload


```lua
function astrocore.reload()
```

 Partially reload AstroNvim user settings. Includes core vim options, mappings, and highlights. This is an experimental feature and may lead to instabilities until restart.

### set_mappings


```lua
function astrocore.set_mappings(map_table: table, base?: table)
```

 Table based API for setting keybindings

*param* `map_table` — A nested table where the first key is the vim mode, the second key is the key to map, and the value is the function to set the mapping to

*param* `base` — A base set of options to set on every keybinding

### set_url_match


```lua
function astrocore.set_url_match()
```

 Add syntax matching rules for highlighting URLs/URIs

### setup


```lua
function astrocore.setup(opts: AstroCoreOpts)
```

 Setup and configure AstroCore
See: [astrocore.config](file:///home/runner/work/astrocore/astrocore/./lua/astrocore/init.lua#13#0)

### system_open


```lua
function astrocore.system_open(path: string)
```

 Open a URL under the cursor with the current operating system

*param* `path` — The path of the file to open with the system opener

### toggle_term_cmd


```lua
function astrocore.toggle_term_cmd(opts: string|table)
```

 Toggle a user terminal if it exists, if not then create a new one and save it

*param* `opts` — A terminal command string or a table of options for Terminal:new() (Check toggleterm.nvim documentation for table format)

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


## astrocore.buffer

AstroNvim Buffer Utilities

Buffer management related utility functions

This module can be loaded with `local buffer_utils = require "astrocore.buffer"`

copyright 2023
license GNU General Public License v3.0

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

### sessions


```lua
unknown
```

### sort


```lua
function astrocore.buffer.sort(compare_func: string|function, skip_autocmd: boolean|nil)
  -> boolean
```

 Sort a the buffers in the current tab based on some comparator

*param* `compare_func` — a string of a comparator defined in require("astrocore.buffer.comparator") or a custom comparator function

*param* `skip_autocmd` — whether or not to skip triggering AstroBufsUpdated autocmd event

*return* — Whether or not the buffers were sorted


## astrocore.buffer.comparator

AstroNvim Buffer Comparators

Buffer comparator functions for sorting buffers

This module can be loaded with `local buffer_comparators = require "astrocore.buffer.comparator"`

copyright 2023
license GNU General Public License v3.0

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


## astrocore.mason

Mason Utilities

Mason related utility functions to use within AstroNvim and user configurations.

This module can be loaded with `local mason_utils = require("astrocore.mason")`

copyright 2023
license GNU General Public License v3.0

### update


```lua
function astrocore.mason.update(pkg_names?: string|string[], auto_install?: boolean)
```

 Update specified mason packages, or just update the registries if no packages are listed

*param* `pkg_names` — The package names as defined in Mason (Not mason-lspconfig or mason-null-ls) if the value is nil then it will just update the registries

*param* `auto_install` — whether or not to install a package that is not currently installed (default: True)

### update_all


```lua
function astrocore.mason.update_all()
```

 Update all packages in Mason


## astrocore.toggles

AstroNvim UI/UX Toggles

 Utility functions for easy UI toggles.

This module can be loaded with `local ui = require("astrocore.toggles")`

copyright 2023
license GNU General Public License v3.0

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

### buffer_indent_guides


```lua
function astrocore.toggles.buffer_indent_guides(bufnr?: integer, silent?: boolean)
```

 Toggle indent guides

*param* `bufnr` — the buffer to toggle indent scope on

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

### wrap


```lua
function astrocore.toggles.wrap(silent?: boolean)
```

 Toggle wrap

*param* `silent` — if true then don't sent a notification


