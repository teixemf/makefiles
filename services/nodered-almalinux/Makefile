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
		echo "ERRO: execute como root ou instale/configure sudo." >&2; \
		exit 1; \
	fi
endef

help:
	@printf '%s\n' \
	  'Node-RED para AlmaLinux — alvos disponíveis:' \
	  '' \
	  '  make help               mostra esta ajuda' \
	  '  make init               cria .env a partir de .env.example' \
	  '  make lint               valida scripts e testes seguros' \
	  '  make install            instalação completa; TLS auto-assinado por defeito' \
	  '  make configure          volta a gerar settings.js, systemd e Nginx' \
	  '  make bcrypt             pede uma password e devolve o hash bcrypt' \
	  '  make cert-selfsigned    instala/substitui por certificado auto-assinado' \
	  '  make cert-le-stag       testa emissão Let'\''s Encrypt DNS-01 staging' \
	  '  make cert-le-prod       emite/instala Let'\''s Encrypt DNS-01 produção' \
	  '  make upgrade            backup + upgrade Node.js/Node-RED/Nginx/Certbot' \
	  '  make upgrade-nodes      actualiza nós adicionais em NODERED_HOME' \
	  '  make upgrade-system     dnf upgrade completo + make upgrade' \
	  '  make backup             cria backup local protegido' \
	  '  make validate           valida serviço, autenticação, TLS e firewall' \
	  '  make status             estado resumido' \
	  '  make restart            reinicia Node-RED e Nginx' \
	  '  make logs               segue apenas os logs do Node-RED' \
	  '  make logs-nginx         segue apenas os logs do Nginx' \
	  '  make logs-all           segue os logs do Node-RED e Nginx' \
	  '  make versions           mostra versões instaladas' \
	  '' \
	  'Pode usar outro ficheiro: make ENV_FILE=/caminho/instancia.env install'

init:
	@if [ -e "$(ENV_ABS)" ]; then \
		echo "ERRO: $(ENV_ABS) já existe." >&2; exit 1; \
	fi
	@cp .env.example "$(ENV_ABS)"
	@chmod 600 "$(ENV_ABS)"
	@secret="$$(openssl rand -hex 32 2>/dev/null || od -An -N32 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"; \
	if [ -n "$$secret" ]; then \
		sed -i "s|^NODE_RED_CREDENTIAL_SECRET=$$|NODE_RED_CREDENTIAL_SECRET=$$secret|" "$(ENV_ABS)"; \
	fi
	@echo "Criado $(ENV_ABS). Edite FQDN, autenticação e, se necessário, credenciais DNS."

lint:
	@for script in "$(SCRIPTS)"/*.sh; do bash -n "$$script"; done
	@"$(SCRIPTS)/test-listener-addresses.sh"
	@echo "Sintaxe Bash válida."

check-env:
	@test -r "$(ENV_ABS)" || { \
		echo "ERRO: falta $(ENV_ABS). Execute 'make init'." >&2; exit 1; \
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
