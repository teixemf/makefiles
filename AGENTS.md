# Agent Guidance

## Purpose

Keep this repository consistent, predictable, and secure as new installers are
added. These rules apply to the entire repository. A closer `AGENTS.md` may add
service-specific requirements, but it must not weaken these rules without
explicitly documenting the exception.

## Generic Roles

Assume the roles required by the task. When subagents are available, separate
these roles whenever the change is large enough to benefit from independent
review.

1. **Maintainer** — preserves the shared structure, avoids duplication, and
   keeps Makefile interfaces consistent.
2. **Security Reviewer** — reviews privileges, accounts, permissions, secrets,
   downloads, services, firewall rules, SELinux, and network exposure.
3. **Platform Validator** — verifies supported systems, idempotency, clean
   installation, upgrades, backups, and recovery.
4. **Dependency Reviewer** — verifies supported versions, official sources,
   compatibility, and update strategy.
5. **Documentation Reviewer** — keeps `README.md`, `.env.example`, `make help`,
   and actual behavior synchronized.

The Maintainer implements. Changes involving privileges or network exposure
must receive a second pass from the Security Reviewer before completion.

## Service Structure

Each service must live under `services/<service>/` and be a self-contained
automation unit. It must be possible to enter `services/<service>/` and run
its documented `make` targets without relying on repository-level Makefiles or
another service directory. Follow this structure unless a documented
requirement justifies a deviation:

```text
services/<service>/
├── Makefile
├── .env.example
├── .gitignore
├── README.md
└── scripts/
    ├── common.sh
    ├── install.sh
    ├── configure.sh
    ├── validate.sh
    └── <target>.sh
```

- Keep the `Makefile` as a thin interface; place implementation logic in
  `scripts/`.
- Match script names to their corresponding targets whenever possible.
- Keep service-wide shared functions in `scripts/common.sh`.
- Keep service configuration, templates, scripts, documentation, and local
  ignore rules inside that service directory.
- Do not include another service's Makefile, call another service's scripts,
  or create target prerequisites across service directories.
- Do not add a repository-level Makefile or shared `.mk` files. Makefiles exist
  only inside service directories.
- Do not depend on repository-level variables or relative paths that only work
  when Make is invoked from the repository root.
- Prefer repeating a small, stable interface over a shared helper that couples
  services. Share only documented, versioned conventions that preserve each
  service's ability to operate independently.
- Scope every generated path, unit, account, port, backup location, and
  runtime resource to the service. Any intentional shared resource must be
  documented together with its ownership and conflict rules.

## Makefile Interface

Every service must provide the following targets when applicable and show them
in this order in `make help`:

1. `help`
2. `init`
3. `sync-env`
4. `lint`
5. `install`
6. `configure`
7. `upgrade`
8. `backup`
9. `validate`
10. `status`
11. `restart`
12. `logs`
13. `versions`

Service-specific targets, such as certificate management or plugin updates,
must appear next to the relevant lifecycle phase. A non-applicable target may
be omitted, but the omission must be clear in the service `README.md`.

- Set `.DEFAULT_GOAL` to `help`.
- Declare non-file targets in `.PHONY`.
- Accept `ENV_FILE`, defaulting to `.env`.
- Resolve `ENV_FILE` and script paths from the service Makefile's own
  directory, so direct invocation is reliable.
- `make init` must create local configuration from `.env.example` without
  replacing an existing file.
- `make sync-env` must merge new `.env.example` keys into an existing `.env`
  without sourcing either file or replacing existing assignments.
- `make lint` must not require `root`, network access, or machine changes.

## Environment Synchronization Contract

Every service that uses `.env.example` and `ENV_FILE` must provide
`make sync-env`. It must read the service-local example as plain text, add only
missing active assignment keys together with their contiguous associated
comment blocks, preserve source ordering and existing assignments byte-for-byte,
and report local-only keys as potentially obsolete without removing them.
Shared comments for adjacent assignments must be copied once, and comments for
groups whose assignments are all already present must not be added.
It must reject duplicate active assignments, never print or execute values,
preserve mode `0600`, create a protected backup before the first material
change, and replace the file atomically. Repeated execution with no missing
keys must not rewrite the file or create another backup. The target must work
with custom `ENV_FILE` paths without root or network access.

The synchronization contract is repository-wide. Any change to it must be
implemented and tested for every existing service in the same pull request;
new services must include the target and its regression tests before merging.

## Service Status and Version Contract

Every existing and future service must implement this contract unless a
documented platform limitation makes a target inapplicable:

- `make versions` is the standalone version and certificate/platform view;
- `make status` composes `versions` with a concise service summary;
- `make status-full` composes `status` with detailed systemd status;
- installed software versions are displayed as one labeled line each, using
  cyan consistently; upstream commands that can return multiple lines must be
  normalized to their first meaningful line;
- state rows use consistent icons and colors for active, transitional,
  inactive, failed, and unknown states;
- each service includes a lint-executed regression test for multiline version
  output when any upstream version command can produce it;
- `Makefile`, `make help`, `README.md`, scripts, and lint tests must describe
  the same contract.

The contract is repository-wide: whenever it changes, the same change must be
applied and validated for every existing service in the same pull request.
New services must implement the current contract before they are added.

## Accounts and Privileges

- Run each daemon under its own dedicated user and group.
- Whenever possible, create a system account with `useradd --system`, a
  dedicated home directory, and `/sbin/nologin` as its shell.
- Do not run a daemon as `root` when it can operate with fewer privileges.
- Do not reuse human accounts or share a service account between applications
  without a strong technical reason.
- Validate existing accounts before reusing them; fail when their home, group,
  or shell is incompatible.
- Give directories and files the minimum required ownership and permissions.
- Restrict privileged operations to installation and configuration; the
  running process must drop privileges.
- Document any upstream-required exception in the service `README.md` and
  highlight it during security review.

## Security and Configuration

- Never commit `.env`, passwords, tokens, keys, or certificates.
- Keep only fake values and safe documentation in `.env.example`.
- Store persistent secrets in restricted files, normally mode `0600` or `0640`,
  and never expose them in arguments, logs, or generated units.
- Bind to loopback by default when a reverse proxy is present.
- Open only strictly required ports.
- Preserve firewall and SELinux support when relevant to the platform.
- Do not use `curl | sh`. Download first, use HTTPS, verify the source, and pin
  a version and checksum or signature whenever possible.
- Do not disable system security mechanisms to make an installation work;
  configure the minimum required permission instead.

## Shell Implementation

- Use Bash with `set -Eeuo pipefail` in executable scripts.
- Quote variable expansions and paths.
- Validate every external variable before destructive operations.
- Prefer idempotent operations and temporary files with atomic installation for
  generated configuration.
- Preserve existing data and configuration; create a backup before upgrades
  with compatibility risk.
- Add diagnostic or recovery traps when a partial sequence could leave the
  service unavailable.
- Do not hide relevant errors with `|| true`; restrict it to explicitly safe,
  optional states.

## Required Validation

Before completing a change:

1. run `make lint` from the changed service directory;
2. run `bash -n` on changed scripts;
3. confirm that `make help` documents the actual targets;
4. run `make -n` when the dry-run does not expose secrets;
5. verify that Git still ignores `.env`;
6. verify that executable scripts retain mode `0755`;
7. update documentation and `.env.example` with interface changes;
8. run the changed service directly from `services/<service>/`, including
   `make help` and safe dry-runs;
9. run the repository auditor when changing shared conventions or adding a
   service;
10. clearly state which VM or platform tests were not executed.

## GitHub Workflow

- Every pull request must be linked to an existing, open GitHub issue created
  for the same change.
- Never create, push, or request a pull request before confirming the issue
  exists and recording its number in the pull request description.
- The issue must describe the purpose and acceptance criteria of the change;
  the pull request must explain how it implements that issue.
- If issue creation or access is unavailable, stop the publication workflow and
  leave the changes unsubmitted until the issue can be created.

Test real installations only on a disposable VM or machine running a supported
platform. Never run `make install` directly on the development machine merely
to validate a change.

## Completion Criteria

A change is complete only when code, example configuration, help output,
documentation, and validation describe the same behavior. Do not fix unrelated
issues unless they are clearly separated from the current task.
