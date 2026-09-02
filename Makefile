SHELL := /bin/sh

.PHONY: help setup format lint test workshop-test workshop-smoke build security ci

help:
	@printf '%s\n' 'Targets: setup format lint test workshop-test workshop-smoke build security ci'

setup:
	@echo 'Replace with project bootstrap command.'

format:
	@echo 'Replace with project formatter command.'

lint:
	@echo 'Replace with project lint command.'

test: workshop-test

workshop-test:
	@bash tests/test-root-workshop-layout.sh
	@bash tests/test-workshop-automated-installer.sh

workshop-smoke:
	@bash ci/workshop-smoke.sh

build:
	@echo 'Replace with project build command.'

security:
	@echo 'Use repository security workflows and add stack-specific scanners.'

ci: lint test build security
