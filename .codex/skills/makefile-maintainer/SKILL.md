---
name: makefile-maintainer
description: Creates, reviews, and normalizes GNU Makefiles and .mk files in this repository. Use when adding a service, changing targets or variables, fixing Make errors, reviewing recipe portability and security, or checking consistency across Makefiles, scripts, .env.example, and documentation.
---

# Makefile Maintainer

Keep Makefiles small, predictable, and consistent interfaces for independent
installers under `services/`. Each `services/<service>/Makefile` must work when
run directly from its own directory. Do not create a repository-level Makefile.

## Workflow

1. Read the root `AGENTS.md` and any guidance closer to the target file.
2. Confirm the target file is a self-contained service Makefile.
3. Confirm a service has no dependency on another service or on being invoked
   from the repository root.
4. Compare with an adjacent service before introducing a new convention.
5. Read `references/makefile-standards.md` when creating or reviewing rules and
   recipes.
6. Keep orchestration declarative in Make and move shell logic to
   `scripts/<target>.sh`.
7. Update `.PHONY`, `make help`, scripts, `.env.example`, and `README.md`
   together whenever the interface changes.
8. Run `make help`, `make lint`, and safe `make -n` targets directly inside the
   changed service. Run `scripts/audit-repository.sh` when adding a service or
   changing shared conventions.
9. Perform a second security pass for changes involving `root`, networking,
   accounts, permissions, firewall rules, SELinux, certificates, or secrets.

## Repository Decisions

- Use GNU Make and declare `SHELL := /usr/bin/bash` when recipes depend on Bash.
- Keep `.DEFAULT_GOAL := help`, even when generic guidance prefers `all`.
- Use service-local absolute paths derived from `$(CURDIR)` or the Makefile
  location. Do not use paths that escape the service directory for normal
  service logic.
- Do not include other services' Makefiles, invoke their scripts, or make
  service targets depend on one another.
- Do not create root-level Make targets, aggregators, or forwarding commands.
- Do not require `clean`: these Makefiles manage services, not build artifacts.
- Use `ENV_FILE ?= .env` in services and never load secrets into the Makefile.
- Run privileged scripts through the service's shared wrapper.

## Expected Result

Deliver a small change that preserves the shared interface, fails early with
clear messages, and passes validation without installing software on the
development machine.
