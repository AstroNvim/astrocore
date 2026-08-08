local tests_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
package.path = tests_dir .. "/?.lua;" .. package.path

local config = require "config"
local environment = require "test_environment"

environment.clear_test_environment(config.filesystem(), config.root)
