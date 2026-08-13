local MiniTest = require "mini.test"
local config = require "config"

local T = MiniTest.new_set()

local SHARED_WORKFLOWS_REF = "main"

local function read_file(path)
  local file = assert(io.open(path, "rb"))
  local contents = assert(file:read "*a")
  file:close()
  return contents
end

local function workflow_job(workflow, name)
  local start = assert(workflow:find("\n  " .. name .. ":\n", 1, true))
  local finish = workflow:find("\n  [_%a][_%w-]*:\n", start + 1)
  return workflow:sub(start, finish and finish - 1 or #workflow)
end

local function workflow_job_names(workflow)
  local jobs = assert(workflow:match "\njobs:\n(.*)")
  local names = {}
  for name in ("\n" .. jobs):gmatch "\n  ([_%a][_%w-]*):\n" do
    table.insert(names, name)
  end
  return names
end

local function make_target_body(makefile, target)
  local start = assert(makefile:find("\n" .. target .. ":\n", 1, true))
  local body_start = start + #target + 3
  local finish = makefile:find("\n[%w-]+:\n", body_start)
  return makefile:sub(body_start, finish and finish - 1 or #makefile)
end

T["AC-CONTRACT-001 exposes a standalone deterministic fingerprint target"] = function()
  local makefile = read_file(config.root .. "/Makefile")

  MiniTest.expect.equality(makefile:find ".PHONY:.*test%-fingerprint" ~= nil, true)
  MiniTest.expect.equality(makefile:find "TEST_TARGETS := [^\n]*test%-fingerprint" == nil, true)
  MiniTest.expect.equality(
    make_target_body(makefile, "test-fingerprint"),
    "\t@nvim -l tests/fingerprint.lua\n\t@printf '\\n'\n"
  )
end

T["AC-CONTRACT-002 delegates Neovim testing through a thin read-only caller"] = function()
  local workflow = read_file(config.root .. "/.github/workflows/ci.yml")
  local ci = workflow_job(workflow, "CI")
  local tests = workflow_job(workflow, "Tests")
  local release = workflow_job(workflow, "Release")
  local pr = workflow_job(workflow, "PR")
  local plugin_ci = "AstroNvim/.github/.github/workflows/plugin_ci.yml@" .. SHARED_WORKFLOWS_REF

  MiniTest.expect.equality("AstroCore", assert(workflow:match "name: ([^\n]+)"))
  MiniTest.expect.equality(workflow_job_names(workflow), { "CI", "Tests", "Release", "PR" })
  MiniTest.expect.equality(workflow:find("runs%-on:", 1) == nil, true)
  MiniTest.expect.equality(workflow:find("steps:", 1, true) == nil, true)
  MiniTest.expect.equality(workflow:find("0 6 %* %* %*", 1) ~= nil, true)
  MiniTest.expect.equality(workflow:find("0 8 %* %* 1", 1) ~= nil, true)
  MiniTest.expect.equality(
    workflow:find("pull_request_target:\n    types: [opened, edited, synchronize]", 1, true) ~= nil,
    true
  )

  MiniTest.expect.equality(ci:find("uses: " .. plugin_ci, 1, true) ~= nil, true)
  MiniTest.expect.equality(ci:find("if: ${{ github.event_name == 'pull_request' }}", 1, true) ~= nil, true)
  MiniTest.expect.equality(ci:find("contents: read", 1, true) ~= nil, true)
  MiniTest.expect.equality(ci:find("permissions:\n      contents: read\n    with:", 1, true) ~= nil, true)
  MiniTest.expect.equality(ci:find("secrets:", 1, true) == nil, true)
  MiniTest.expect.equality(ci:find("is_production: false", 1, true) ~= nil, true)

  MiniTest.expect.equality(
    tests:find("uses: AstroNvim/.github/.github/workflows/neovim_testing.yml@" .. SHARED_WORKFLOWS_REF, 1, true) ~= nil,
    true
  )
  MiniTest.expect.equality(
    tests:find(
      "if: ${{ github.event_name == 'push' || github.event_name == 'pull_request' || github.event_name == 'schedule' }}",
      1,
      true
    ) ~= nil,
    true
  )
  MiniTest.expect.equality(tests:find("contents: read", 1, true) ~= nil, true)
  MiniTest.expect.equality(tests:find("permissions:\n      contents: read\n    with:", 1, true) ~= nil, true)
  MiniTest.expect.equality(tests:find("secrets:", 1, true) == nil, true)
  MiniTest.expect.equality(tests:find('minimum_neovim: "0.11.0"', 1, true) ~= nil, true)
  MiniTest.expect.equality(tests:find('stable_neovim: "0.12.4"', 1, true) ~= nil, true)
  MiniTest.expect.equality(tests:find('cache_rotation: "1"', 1, true) ~= nil, true)
  MiniTest.expect.equality(tests:find("timeout_minutes: 30", 1, true) ~= nil, true)

  MiniTest.expect.equality(release:find("needs: Tests", 1, true) ~= nil, true)
  MiniTest.expect.equality(
    release:find(
      "concurrency:\n      group: ${{ github.event.repository.name }}-release\n      cancel-in-progress: false",
      1,
      true
    ) ~= nil,
    true
  )
  MiniTest.expect.equality(release:find("uses: " .. plugin_ci, 1, true) ~= nil, true)
  MiniTest.expect.equality(release:find("if: ${{ github.event_name == 'push' }}", 1, true) ~= nil, true)
  MiniTest.expect.equality(release:find("contents: write", 1, true) ~= nil, true)
  MiniTest.expect.equality(release:find("pull-requests: write", 1, true) ~= nil, true)
  MiniTest.expect.equality(
    release:find(
      "permissions:\n      contents: write\n      pull-requests: write\n    secrets:\n      RELEASE_TOKEN: ${{ secrets.RELEASE_TOKEN }}\n    with:",
      1,
      true
    ) ~= nil,
    true
  )
  MiniTest.expect.equality(release:find("is_production: true", 1, true) ~= nil, true)

  MiniTest.expect.equality(
    pr:find("uses: AstroNvim/.github/.github/workflows/validate_pr.yml@" .. SHARED_WORKFLOWS_REF, 1, true) ~= nil,
    true
  )
  MiniTest.expect.equality(pr:find("pull-requests: read", 1, true) ~= nil, true)
end

return T
