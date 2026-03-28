SHELL := bash
.DEFAULT_GOAL := help

.PHONY: help tools tools-lint tools-test lint test check ci

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
	if ! command -v bats >/dev/null 2>&1; then \
		echo "Missing required tool: bats"; \
		echo "Install on Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y bats"; \
		exit 1; \
	fi; \
	echo "All test tools are installed: bats"

lint: ## Run all lint checks
lint: tools-lint
	@echo "Running lint checks..."
	shellcheck bin/* test/*.bash
	shellcheck -s bash test/buildpack.bats
	shfmt -d bin test
	@echo "Lint checks passed"

test: ## Run the Bats test suite
test: tools-test
	@echo "Running test suite..."
	bats test/buildpack.bats
	@echo "Test suite passed"

check: ## Run lint and tests
check: lint test
	@echo "All checks passed"

ci: ## Run CI checks
ci: check
	@echo "CI checks passed"
