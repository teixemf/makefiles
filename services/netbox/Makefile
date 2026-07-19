SHELL := /usr/bin/bash
.DEFAULT_GOAL := help

ENV_FILE ?= .env
ENV_ABS := $(abspath $(if $(filter /%,$(ENV_FILE)),$(ENV_FILE),$(CURDIR)/$(ENV_FILE)))
SCRIPTS := $(CURDIR)/scripts

.PHONY: help init sync-env lint check-env install configure check-for-updates list-tags upgrade \
        upgrade-plugins add-plugin backup validate status restart logs versions

define run_as_root
	@if [ "$$(id -u)" -eq 0 ]; then \
		ENV_FILE="$(ENV_ABS)" VERSION="$(VERSION)" PLUGIN="$(PLUGIN)" "$(SCRIPTS)/$(1)"; \
	elif command -v sudo >/dev/null 2>&1; then \
		sudo ENV_FILE="$(ENV_ABS)" VERSION="$(VERSION)" PLUGIN="$(PLUGIN)" "$(SCRIPTS)/$(1)"; \
	else \
		echo "ERROR: run as root or install/configure sudo." >&2; exit 1; \
	fi
endef

help:
	@printf '%s\n' \
	  'NetBox — available targets:' \
	  '' \
	  '  make help                  show this help' \
	  '  make init                  create .env from .env.example' \
	  '  make sync-env              add new keys/comments without replacing values' \
	  '  make lint                  validate scripts without machine changes' \
	  '  make install               explain why installation is not provided' \
	  '  make configure             explain why configuration is not provided' \
	  '  make check-for-updates     fetch tags and report NetBox updates' \
	  '  make list-tags             list the newest stable NetBox tags' \
	  '  make upgrade [VERSION=vX.Y.Z]  upgrade to the newest stable tag or a tag' \
	  '  make upgrade-plugins       review and upgrade configured plugins' \
	  '  make add-plugin PLUGIN=name add a package to local_requirements.txt' \
	  '  make backup                create a restricted NetBox backup' \
	  '  make validate              run Django validation checks' \
	  '  make status                show NetBox and dependency service state' \
	  '  make restart               restart NetBox application services' \
	  '  make logs                  follow NetBox application logs' \
	  '  make versions              show NetBox, Python, and plugin versions' \
	  '' \
	  'Use another file with: make ENV_FILE=/path/instance.env status'

init:
	@if [ -e "$(ENV_ABS)" ]; then echo "ERROR: $(ENV_ABS) already exists." >&2; exit 1; fi
	@cp "$(CURDIR)/.env.example" "$(ENV_ABS)"
	@chmod 600 "$(ENV_ABS)"
	@echo "Created $(ENV_ABS). Review its paths before running an operation."

sync-env:
	@ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/sync-env.sh"

lint:
	@for script in "$(SCRIPTS)"/*.sh; do bash -n "$$script"; done
	@"$(SCRIPTS)/test-sync-env.sh"
	@"$(SCRIPTS)/export_netbox_env.py" >/dev/null 2>&1 || test $$? -eq 2
	@"$(SCRIPTS)/check_plugin_updates.py" >/dev/null 2>&1 || test $$? -eq 1
	@echo "Valid Bash and Python syntax."

check-env:
	@test -r "$(ENV_ABS)" || { echo "ERROR: $(ENV_ABS) is missing. Run 'make init'." >&2; exit 1; }

install:
	@ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/install.sh"

configure:
	@ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/configure.sh"

check-for-updates list-tags: check-env
	@ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/updates.sh" "$@"

upgrade: check-env
	$(call run_as_root,upgrade.sh)

upgrade-plugins: check-env
	$(call run_as_root,upgrade-plugins.sh)

add-plugin: check-env
	@PLUGIN="$(PLUGIN)" $(call run_as_root,add-plugin.sh)

backup: check-env
	$(call run_as_root,backup.sh)

validate: check-env
	$(call run_as_root,validate.sh)

status: check-env
	@ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/status.sh"

restart: check-env
	$(call run_as_root,restart.sh)

logs: check-env
	@ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/logs.sh"

versions: check-env
	@ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/versions.sh"
