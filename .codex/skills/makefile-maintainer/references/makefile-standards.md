# Makefile Standards

This reference adapts GNU Make guidance from
[`github/awesome-copilot`](https://github.com/github/awesome-copilot/blob/main/instructions/makefile.instructions.md)
to this repository's installer model. Consult the
[GNU Make manual](https://www.gnu.org/software/make/manual/) for detailed
semantics.

## Structure

- Treat every `services/<service>/` directory as an independent project. Its
  Makefile must be usable with `make -C services/<service> <target>` and with
  `cd services/<service> && make <target>`.
- Derive script and configuration paths from the service directory. Never rely
  on the caller's current directory, repository-level variables, or files in a
  sibling service.
- Do not use `include` for another service's `.mk` or Makefile, invoke another
  service's scripts, or create cross-service prerequisites.
- Keep service-specific templates, configuration examples, and scripts in the
  service directory. Do not create a root Makefile that aggregates services.
- Place variables before rules.
- Set `.DEFAULT_GOAL := help` explicitly.
- Group targets in the lifecycle order defined by `AGENTS.md`.
- Declare every action target in `.PHONY`.
- Keep Makefiles thin; place complex recipes in Bash scripts.
- Use descriptive and stable target names.

Minimal service template:

```makefile
SHELL := /usr/bin/bash
.DEFAULT_GOAL := help

ENV_FILE ?= .env
ENV_ABS := $(abspath $(ENV_FILE))
SCRIPTS := $(CURDIR)/scripts

.PHONY: help init lint install configure validate status restart logs versions

help:
	@printf '%s\n' \
	  '  make init       creates local configuration' \
	  '  make lint       validates without changing the machine' \
	  '  make install    installs the service'

install: check-env
	@ENV_FILE="$(ENV_ABS)" "$(SCRIPTS)/install.sh"
```

## Variables

- Use `:=` for immediately expanded values and `?=` for overridable defaults.
- Reference Make variables as `$(NAME)` and shell variables as `$$name`.
- Avoid `$(shell ...)` when a variable or script can solve the problem.
- Never store passwords, tokens, or keys in Makefile variables.
- Validate input in scripts before privileged or destructive operations.

## Rules and Recipes

- Start every recipe with a real tab, never spaces.
- Use `$(MAKE)` instead of invoking `make` directly.
- Do not use recursive Make between services and do not add a repository-level
  Makefile.
- Keep commands that share shell state in one shell or, preferably, move them
  into a script using `set -Eeuo pipefail`.
- Do not ignore errors with `-` or `|| true` unless the state is proven optional
  and safe.
- Quote paths and shell expansions.
- Avoid destructive default recipes and never install from `help` or `lint`.

## Dependencies and Parallel Execution

- Express actual prerequisites without circular dependencies.
- Do not depend on the textual order of independent targets.
- Claim `make -j` compatibility only after confirming that targets do not alter
  the same files, services, or resources.
- Prefer explicit sequential execution for imperative installers.

## Diagnostics

- Fail early when `.env`, a tool, or a required variable is missing.
- Produce messages that state the corrective action.
- Use `make -n` to inspect recipes without executing them.
- Use `make -p` or `make -qp` to inspect the rule database when debugging
  expansion or `.PHONY` behavior.
- Never require `root`, network access, or real local configuration for
  `make lint`.

## Differences From Compilation Makefiles

- The default target is `help`, not `all`.
- `clean` and `distclean` are optional and usually unnecessary.
- Implicit rules, pattern rules, and compiler variables rarely apply.
- Idempotency, rollback, permissions, and operational security matter more than
  incremental builds.
- Installation logic belongs in auditable scripts; Make only coordinates it.

## Review Checklist

- Does the structure match the other services?
- Does `make -C services/<service> help` work without any dispatcher?
- Are all normal paths and scripts resolved inside the service directory?
- Is the service free of cross-service Make, script, configuration, and target
  dependencies?
- Are `.DEFAULT_GOAL`, `.PHONY`, and `help` synchronized?
- Can `ENV_FILE` be overridden and converted to an absolute path?
- Do recipes use tabs and distinguish `$` from `$$` correctly?
- Is complex logic kept in `scripts/`?
- Are `lint` and `help` safe without privileges?
- Does the dry-run show expected commands without exposing secrets?
- Do the README and example configuration match the current interface?
