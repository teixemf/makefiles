# NetBox

Self-contained operational tooling for an existing NetBox installation. It
does not install NetBox or create its database, account, reverse proxy, or
firewall configuration.

The default paths target the standard NetBox layout under `/opt/netbox`; copy
the configuration and adjust it for the managed host before running any
operation.

## Quick start

Run from this directory:

```bash
make init
make sync-env
vi .env
make lint
make status
make check-for-updates
```

`make init` creates `.env` with mode `0600` and never overwrites it. `.env`
contains paths and service names, but no credentials. NetBox credentials stay
in `NETBOX_SECRETS_FILE`, outside this repository.

## Available targets

| Target | Purpose |
| --- | --- |
| `make help` | Show all supported operations. |
| `make init` | Create a local `.env` from `.env.example`. |
| `make sync-env` | Add newly documented keys and associated comments without replacing local values. |
| `make lint` | Check Bash and Python syntax without root, network, or host changes. |
| `make install` | Report that NetBox installation is intentionally unsupported by this manager. |
| `make configure` | Report that NetBox configuration generation is intentionally unsupported by this manager. |
| `make check-for-updates` | Fetch tags and show whether a stable NetBox update exists. |
| `make list-tags` | Show recent stable NetBox tags. |
| `make upgrade` | Interactively upgrade to the newest stable NetBox tag. |
| `make upgrade VERSION=vX.Y.Z` | Interactively upgrade to one verified tag. |
| `make upgrade-plugins` | Inspect available plugin updates and upgrade after confirmation. |
| `make add-plugin PLUGIN=name` | Add one package name to `local_requirements.txt`. |
| `make backup` | Back up configuration, secrets, requirements, Git revision, and PostgreSQL data. |
| `make validate` | Run `manage.py check` as the dedicated NetBox account. |
| `make status` | Report NetBox, worker, PostgreSQL, and Redis unit states. |
| `make restart` | Restart the NetBox web and worker services. |
| `make logs` | Follow application and worker journals. |
| `make versions` | Show the NetBox revision, Python, and installed plugin versions. |

Use a separate instance configuration with
`make ENV_FILE=/path/instance.env status`.

## Security and operations

- Upgrade, plugin changes, backups, validation, and restarts require root or
  `sudo`; every changing upgrade action asks for confirmation first and creates
  a backup before it changes the installed revision or plugin packages.
- Backups contain secrets and database data. The backup directory and its
  contents are created with restricted permissions. Retention pruning only
  applies to direct child directories of `NETBOX_BACKUP_ROOT` older than
  `NETBOX_BACKUP_RETENTION_DAYS`.
- The secrets parser only accepts simple `KEY=value` entries and exports them
  to the calling process; it does not source the secrets file as shell code.
- `make check-for-updates`, `make list-tags`, and plugin update
  checks access upstream networks. `make lint` does not.
- Review the NetBox release notes and take a backup before every upgrade. Test
  real upgrades on a disposable supported system first.

## Origin

This service incorporates and restructures
[`teixemf/netbox-manager`](https://github.com/teixemf/netbox-manager) for the
independent-service conventions of this repository. The original project is
MIT licensed.
