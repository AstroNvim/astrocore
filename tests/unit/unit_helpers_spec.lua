local MiniTest = require "mini.test"
local helpers = require "unit_helpers"

local T = MiniTest.new_set()

T["AC-ENV-011 restores package entries and scheduled callbacks"] = function()
  local module_name = "astrocore.test.unit_helper_fixture"
  local original_loaded, original_preload = package.loaded[module_name], package.preload[module_name]
  local fixture_preload = function() return { value = "fixture" } end
  package.preload[module_name] = fixture_preload

  helpers.with_module(module_name, {}, function(module, context)
    MiniTest.expect.equality(module.value, "fixture")
    vim.schedule(function() vim.g.astrocore_unit_helper_scheduled = true end)
    MiniTest.expect.equality(context.scheduled_count(), 1)
    context.drain_scheduled()
    MiniTest.expect.equality(vim.g.astrocore_unit_helper_scheduled, true)
    vim.defer_fn(function() vim.g.astrocore_unit_helper_deferred = true end, 10)
    MiniTest.expect.equality(context.deferred_count(), 1)
    context.drain_deferred()
    MiniTest.expect.equality(vim.g.astrocore_unit_helper_deferred, true)
    vim.g.astrocore_unit_helper_scheduled = nil
    vim.g.astrocore_unit_helper_deferred = nil
  end)

  MiniTest.expect.equality(package.loaded[module_name], original_loaded)
  MiniTest.expect.equality(package.preload[module_name], fixture_preload)
  package.preload[module_name] = original_preload
end

T["AC-ENV-012 restores nested vim fields and isolated notifications"] = function()
  local module_name = "astrocore.test.unit_helper_nested_fixture"
  package.preload[module_name] = function() return {} end
  local original_get_clients = vim.lsp.get_clients
  local notifications = {}
  helpers.with_module(module_name, {
    vim = { lsp = { get_clients = function() return { "fake" } end } },
    notify = function(...) table.insert(notifications, { ... }) end,
  }, function()
    MiniTest.expect.equality(vim.lsp.get_clients(), { "fake" })
    vim.notify "message"
  end)
  package.preload[module_name] = nil
  MiniTest.expect.equality(vim.lsp.get_clients, original_get_clients)
  MiniTest.expect.equality(notifications[1][1], "message")
end

T["AC-ENV-013A closes fake libuv handles after callback failure"] = function()
  local module_name = "astrocore.test.unit_helper_handle_fixture"
  package.preload[module_name] = function() return {} end
  local handle
  local ok = pcall(function()
    helpers.with_module(module_name, { fake_uv = true }, function()
      handle = vim.uv.new_timer()
      handle:start(1, 0, function() end)
      error "expected test failure"
    end)
  end)
  package.preload[module_name] = nil
  MiniTest.expect.equality(ok, false)
  MiniTest.expect.equality(handle.closed, true)
  MiniTest.expect.equality(handle.stopped, true)
end

return T
