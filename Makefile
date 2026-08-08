.PHONY: test test-semantic test-prepare test-clear test-update-deps test-unit test-unit-environment test-unit-unit-helpers test-unit-helpers test-unit-core test-unit-buffer test-unit-rooter test-unit-toggles test-unit-treesitter test-unit-health-resession test-e2e test-setup test-files test-buffer test-rooter test-toggles test-treesitter

TEST_TARGETS := test test-semantic test-unit test-unit-environment test-unit-unit-helpers test-unit-helpers test-unit-core test-unit-buffer test-unit-rooter test-unit-toggles test-unit-treesitter test-unit-health-resession test-e2e test-setup test-files test-buffer test-rooter test-toggles test-treesitter

$(TEST_TARGETS): test-prepare

test:
	@nvim -l tests/minit.lua --minitest tests/unit/*_spec.lua tests/e2e/*_spec.lua

test-semantic:
	@nvim -l tests/minit.lua --minitest tests/unit/*_spec.lua tests/e2e/*_spec.lua

test-prepare:
	@nvim -l tests/bootstrap.lua

test-clear:
	@nvim -l tests/clear_test_environment.lua

test-update-deps:
	@$(MAKE) test-clear
	@$(MAKE) test-prepare

test-unit:
	@nvim -l tests/minit.lua --minitest tests/unit/*_spec.lua

test-unit-environment:
	@nvim -l tests/minit.lua --minitest tests/unit/test_environment_spec.lua

test-unit-unit-helpers:
	@nvim -l tests/minit.lua --minitest tests/unit/unit_helpers_spec.lua

test-unit-helpers:
	@nvim -l tests/minit.lua --minitest tests/unit/helpers_spec.lua

test-unit-core:
	@nvim -l tests/minit.lua --minitest tests/unit/core_spec.lua

test-unit-buffer:
	@nvim -l tests/minit.lua --minitest tests/unit/buffer_spec.lua

test-unit-rooter:
	@nvim -l tests/minit.lua --minitest tests/unit/rooter_spec.lua

test-unit-toggles:
	@nvim -l tests/minit.lua --minitest tests/unit/toggles_spec.lua

test-unit-treesitter:
	@nvim -l tests/minit.lua --minitest tests/unit/treesitter_spec.lua

test-unit-health-resession:
	@nvim -l tests/minit.lua --minitest tests/unit/health_resession_spec.lua

test-e2e:
	@nvim -l tests/minit.lua --minitest tests/e2e/*_spec.lua

test-setup:
	@nvim -l tests/minit.lua --minitest tests/e2e/setup_spec.lua

test-files:
	@nvim -l tests/minit.lua --minitest tests/e2e/files_spec.lua

test-buffer:
	@nvim -l tests/minit.lua --minitest tests/e2e/buffer_spec.lua

test-rooter:
	@nvim -l tests/minit.lua --minitest tests/e2e/rooter_spec.lua

test-toggles:
	@nvim -l tests/minit.lua --minitest tests/e2e/toggles_spec.lua

test-treesitter:
	@nvim -l tests/minit.lua --minitest tests/e2e/treesitter_spec.lua
