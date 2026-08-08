local M = {}

M.schema = 3
M.lazy = {
  name = "lazy.nvim",
  url = "https://github.com/folke/lazy.nvim.git",
  branch = "stable",
}
M.dependencies = {
  { name = "mini.test", url = "https://github.com/echasnovski/mini.test.git", branch = "main" },
  { name = "luassert", url = "https://github.com/lunarmodules/luassert.git", branch = "master" },
  { name = "say", url = "https://github.com/Olivine-Labs/say.git", branch = "master" },
  { name = "resession.nvim", url = "https://github.com/stevearc/resession.nvim.git", branch = "master" },
  { name = "nvim-treesitter", url = "https://github.com/nvim-treesitter/nvim-treesitter.git", branch = "main" },
}

M.lock_plugins = { "mini.test", "luassert", "say", "resession.nvim", "nvim-treesitter" }

M.required_paths = {
  { path = "lazy.nvim", type = "directory" },
  { path = "data", type = "directory" },
  { path = "data/nvim", type = "directory" },
  { path = "data/nvim/lazy", type = "directory" },
  { path = "lua", type = "directory" },
  { path = "lua/luassert", type = "directory" },
  { path = "lua/luassert/init.lua", type = "file" },
  { path = "lua/say", type = "directory" },
  { path = "lua/say/init.lua", type = "file" },
  { path = "state", type = "directory" },
  { path = "cache", type = "directory" },
  { path = "lazy-lock.json", type = "file" },
  { path = "manifest.json", type = "file" },
  { path = ".ready", type = "file" },
}

for _, dependency in ipairs(M.dependencies) do
  table.insert(M.required_paths, { path = "data/nvim/lazy/" .. dependency.name, type = "directory" })
end

M.copied_libraries = {
  {
    name = "luassert",
    source_root = "data/nvim/lazy/luassert/src",
    destination_root = "lua/luassert",
    files = {
      { source = "array.lua", destination = "array.lua" },
      { source = "assert.lua", destination = "assert.lua" },
      { source = "assertions.lua", destination = "assertions.lua" },
      { source = "compatibility.lua", destination = "compatibility.lua" },
      { source = "formatters/binarystring.lua", destination = "formatters/binarystring.lua" },
      { source = "formatters/init.lua", destination = "formatters/init.lua" },
      { source = "init.lua", destination = "init.lua" },
      { source = "languages/ar.lua", destination = "languages/ar.lua" },
      { source = "languages/de.lua", destination = "languages/de.lua" },
      { source = "languages/en.lua", destination = "languages/en.lua" },
      { source = "languages/fr.lua", destination = "languages/fr.lua" },
      { source = "languages/id.lua", destination = "languages/id.lua" },
      { source = "languages/is.lua", destination = "languages/is.lua" },
      { source = "languages/ja.lua", destination = "languages/ja.lua" },
      { source = "languages/ko.lua", destination = "languages/ko.lua" },
      { source = "languages/nl.lua", destination = "languages/nl.lua" },
      { source = "languages/ru.lua", destination = "languages/ru.lua" },
      { source = "languages/ua.lua", destination = "languages/ua.lua" },
      { source = "languages/zh.lua", destination = "languages/zh.lua" },
      { source = "match.lua", destination = "match.lua" },
      { source = "matchers/composite.lua", destination = "matchers/composite.lua" },
      { source = "matchers/core.lua", destination = "matchers/core.lua" },
      { source = "matchers/init.lua", destination = "matchers/init.lua" },
      { source = "mock.lua", destination = "mock.lua" },
      { source = "modifiers.lua", destination = "modifiers.lua" },
      { source = "namespaces.lua", destination = "namespaces.lua" },
      { source = "spy.lua", destination = "spy.lua" },
      { source = "state.lua", destination = "state.lua" },
      { source = "stub.lua", destination = "stub.lua" },
      { source = "util.lua", destination = "util.lua" },
    },
  },
  {
    name = "say",
    source_root = "data/nvim/lazy/say/src/say",
    destination_root = "lua/say",
    files = { { source = "init.lua", destination = "init.lua" } },
  },
}

M.untracked_allowlists = {
  ["lazy.nvim"] = { "doc/tags" },
  ["mini.test"] = { "doc/tags" },
  luassert = {},
  say = {},
  ["resession.nvim"] = { "doc/tags" },
  ["nvim-treesitter"] = { "doc/tags" },
}

return M
