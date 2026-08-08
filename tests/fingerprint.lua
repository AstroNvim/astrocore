local tests_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
package.path = tests_dir .. "/?.lua;" .. package.path

io.write(require("test_environment").expected_fingerprint)
