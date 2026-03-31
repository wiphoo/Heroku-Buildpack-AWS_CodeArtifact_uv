SHELL := bash
.DEFAULT_GOAL := help

.PHONY: help tools tools-lint tools-test lint test test-integration test-integration-generic test-integration-heroku check ci

help: ## Show available development commands
	@awk 'BEGIN {FS = ": ## "}; /^[a-zA-Z0-9_.-]+: ## / {printf "%-16s %s\n", $$1, $$2}' Makefile

tools: ## Check all required tools
	@$(MAKE) --no-print-directory tools-lint
	@$(MAKE) --no-print-directory tools-test
	@echo "All required tools are installed"

tools-lint: ## Check lint tools
	@echo "Checking lint tools..."; \
	missing=0; \
	for tool in shellcheck shfmt; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			echo "Missing required tool: $$tool"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
		echo "Install on Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y shellcheck shfmt"; \
		exit 1; \
	fi; \
	echo "All lint tools are installed: shellcheck shfmt"

tools-test: ## Check test tools
	@echo "Checking test tools..."; \
	missing=0; \
	for tool in bats; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			echo "Missing required tool: $$tool"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
		echo "Install on Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y bats"; \
		exit 1; \
	fi; \
	echo "All test tools are installed: bats"

lint: ## Run all lint checks
lint: tools-lint
	@echo "Running lint checks..."
	shellcheck bin/* lib/*.sh test/*.bash test/support/buildpacks/verifier/bin/*
	shellcheck -s bash test/buildpack.bats
	shfmt -d bin lib test
	@echo "Lint checks passed"

test: ## Run the Bats test suite
test: tools-test
	@echo "Running test suite..."
	bats test/buildpack.bats
	@echo "Test suite passed"

test-integration: ## Run generic and Heroku-24 pack/docker integration tests
	@$(MAKE) --no-print-directory test-integration-generic
	@$(MAKE) --no-print-directory test-integration-heroku

test-integration-generic: ## Run the generic builder integration test
	test/integration.bash generic

test-integration-heroku: ## Run the Heroku-24 builder integration test
	test/integration.bash heroku-24

check: ## Run lint and tests
check: lint test
	@echo "All checks passed"

ci: ## Run CI checks
ci: check test-integration
	@echo "CI checks passed"
