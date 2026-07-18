SHELL := /usr/bin/bash
.DEFAULT_GOAL := help

ENV_FILE ?= .env
ENV_ABS := $(abspath $(ENV_FILE))
SCRIPTS := $(CURDIR)/scripts

.PHONY: help init check-env lint install configure bcrypt cert-selfsigned cert-le-stag \
        cert-le-prod upgrade upgrade-nodes upgrade-system backup validate status \
        restart logs logs-nginx logs-all versions

define run_as_root
	@if [ "$$(id -u)" -eq 0 ]; then \
		ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/$(1)"; \
	elif command -v sudo >/dev/null 2>&1; then \
		sudo ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/$(1)"; \
	else \
		echo "ERROR: run as root or install/configure sudo." >&2; \
		exit 1; \
	fi
endef

help:
	@printf '%s\n' \
	  'Node-RED for AlmaLinux — available targets:' \
	  '' \
	  '  make help               show this help' \
	  '  make init               create .env from .env.example' \
	  '  make lint               validate script syntax' \
	  '  make install            complete installation; self-signed TLS by default' \
	  '  make configure          regenerate settings.js, systemd, and Nginx' \
	  '  make bcrypt             prompt for a password and print its bcrypt hash' \
	  '  make cert-selfsigned    install/replace the self-signed certificate' \
	  '  make cert-le-stag       test Let'\''s Encrypt DNS-01 staging issuance' \
	  '  make cert-le-prod       issue/install a production Let'\''s Encrypt certificate' \
	  '  make upgrade            backup + upgrade Node.js/Node-RED/Nginx/Certbot' \
	  '  make upgrade-nodes      upgrade additional nodes in NODERED_HOME' \
	  '  make upgrade-system     dnf upgrade completo + make upgrade' \
	  '  make backup             create a protected local backup' \
	  '  make validate           validate service, authentication, TLS, and firewall' \
	  '  make status             show a summary of the service status' \
	  '  make restart            restart Node-RED and Nginx' \
	  '  make logs               follow Node-RED logs only' \
	  '  make logs-nginx         follow Nginx logs only' \
	  '  make logs-all           follow Node-RED and Nginx logs' \
	  '  make versions           show installed versions' \
	  '' \
	  'Use another file with: make ENV_FILE=/path/instance.env install'

init:
	@if [ -e "$(ENV_ABS)" ]; then \
		echo "ERROR: $(ENV_ABS) already exists." >&2; exit 1; \
	fi
	@cp .env.example "$(ENV_ABS)"
	@chmod 600 "$(ENV_ABS)"
	@secret="$$(openssl rand -hex 32 2>/dev/null || od -An -N32 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"; \
	if [ -n "$$secret" ]; then \
		sed -i "s|^NODE_RED_CREDENTIAL_SECRET=$$|NODE_RED_CREDENTIAL_SECRET=$$secret|" "$(ENV_ABS)"; \
	fi
	@echo "Created $(ENV_ABS). Edit FQDN, authentication, and DNS credentials if needed."

lint:
	@for script in "$(SCRIPTS)"/*.sh; do bash -n "$$script"; done
	@echo "Valid Bash syntax."

check-env:
	@test -r "$(ENV_ABS)" || { \
		echo "ERROR: $(ENV_ABS) is missing. Run 'make init'." >&2; exit 1; \
	}

install: check-env
	$(call run_as_root,install.sh)

configure: check-env
	$(call run_as_root,configure.sh)

bcrypt:
	@"$(SCRIPTS)/bcrypt.sh"

cert-selfsigned: check-env
	$(call run_as_root,cert-selfsigned.sh)

cert-le-stag: check-env
	$(call run_as_root,cert-letsencrypt-staging.sh)

cert-le-prod: check-env
	$(call run_as_root,cert-letsencrypt-prod.sh)

upgrade: check-env
	$(call run_as_root,upgrade.sh)

upgrade-nodes: check-env
	$(call run_as_root,upgrade-nodes.sh)

upgrade-system: check-env
	$(call run_as_root,upgrade-system.sh)

backup: check-env
	$(call run_as_root,backup.sh)

validate: check-env
	$(call run_as_root,validate.sh)

status: check-env
	$(call run_as_root,status.sh)

restart: check-env
	$(call run_as_root,restart.sh)

logs: check-env
	$(call run_as_root,logs.sh)

logs-nginx: check-env
	$(call run_as_root,logs-nginx.sh)

logs-all: check-env
	$(call run_as_root,logs-all.sh)

versions: check-env
	$(call run_as_root,versions.sh)
