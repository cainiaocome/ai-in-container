SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

IMAGE ?= ghcr.io/cainiaocome/ai-in-container:docker-sandbox

.PHONY: help build validate-kits test test-unit test-sandbox load-template

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the self-managed Docker Sandbox template image
	docker build -t "$(IMAGE)" .

load-template: build ## Load the locally built image into the sbx template store
	@tmp="$$(mktemp "${TMPDIR:-/tmp}/ai-in-container-template.XXXXXX")"; \
	trap 'rm -f "$$tmp"' EXIT; \
	docker image save "$(IMAGE)" -o "$$tmp"; \
	sbx template load "$$tmp"

validate-kits: ## Validate all local Docker Sandbox kit specs
	@for kit in sandbox/kits/*; do \
		echo "Validating $$kit"; \
		sbx kit validate "$$kit"; \
	done

test-unit: ## Run launcher and static configuration tests
	bash tests/test-launchers.sh
	bash tests/test-layout.sh

test: test-unit ## Run tests that do not require KVM or sbx login

test-sandbox: ## Run a real nested-Docker smoke test in a Docker Sandbox microVM
	AGENT_HERE_IMAGE="$(IMAGE)" bash tests/test-sandbox-smoke.sh
