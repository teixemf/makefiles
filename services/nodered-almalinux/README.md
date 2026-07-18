# Node-RED on AlmaLinux with Make

Repeatable installer for:

- AlmaLinux 9 and compatible RHEL derivatives;
- a dedicated non-login system account;
- Node-RED editor and Admin API authentication;
- Nginx reverse proxy with loopback-only Node-RED;
- self-signed TLS by default;
- Let's Encrypt DNS-01 staging and production certificates;
- systemd service and certificate renewal;
- protected backups and upgrades.

## Quick start

Run all commands from this directory:

```bash
make init
vi .env
make lint
make install
make validate
make status
```

`make install` is the complete, repeatable entry point. It installs
dependencies, applies Node-RED and Nginx configuration, preserves existing
data, enables services, and runs validation and status checks.

## TLS

The default installation creates a self-signed certificate when no certificate
exists. Configure the DNS provider in `.env`, then test issuance first:

```bash
make cert-le-stag
make cert-le-prod
```

Staging uses separate Certbot directories, does not install its certificate in
Nginx, and does not enable the renewal timer. It cannot replace an existing
production certificate.

Cloudflare is the default provider. Use a zone-scoped token with
`Zone:DNS:Edit` and `Zone:Zone:Read`. Credentials are stored in a protected
file with mode `0600` for automatic renewal.

## Available targets

| Target | Purpose |
| --- | --- |
| `make help` | Show the available targets. |
| `make init` | Create `.env` from `.env.example`; fail if it already exists. |
| `make lint` | Validate Bash syntax without root, network, or system changes. |
| `make configure` | Regenerate Node-RED, systemd, and Nginx configuration. |
| `make bcrypt` | Prompt for a password and print only its bcrypt hash. |
| `make cert-selfsigned` | Generate or replace the self-signed TLS certificate. |
| `make cert-le-stag` | Test Let's Encrypt DNS-01 issuance. |
| `make cert-le-prod` | Issue and install a production certificate. |
| `make upgrade` | Back up, upgrade dependencies, configure, and validate. |
| `make upgrade-nodes` | Explicitly upgrade additional palette nodes. |
| `make upgrade-system` | Upgrade the operating system, then the service. |
| `make backup` | Create a protected backup of configuration, data, and Certbot state. |
| `make validate` | Check the service, authentication, TLS, ports, and firewall. |
| `make status` | Show service status. |
| `make restart` | Restart Node-RED and Nginx. |
| `make logs` | Follow Node-RED logs. |
| `make logs-nginx` | Follow Nginx access and error logs. |
| `make logs-all` | Follow Node-RED and Nginx logs. |
| `make versions` | Show installed versions. |

Use an alternative configuration file with
`make ENV_FILE=/path/instance.env install`.

## Configuration

The real `.env` file must use mode `0600`, must not be committed, and is
interpreted as Bash. Quote passwords, tokens, and values containing special
characters.

Important variables include:

- `FQDN`: DNS name used by Nginx and certificates;
- `NODE_MAJOR`: AlmaLinux AppStream Node.js major version;
- `NODERED_VERSION`: Node-RED version, preferably pinned for reproducibility;
- `NODERED_USER`, `NODERED_GROUP`, and `NODERED_HOME`: service account and data;
- `NODERED_BIND`: keep `127.0.0.1` when using the reverse proxy;
- `NODERED_ADMIN_PASSWORD_HASH`: preferred editor/Admin API credential;
- `NODE_RED_CREDENTIAL_SECRET`: encryption key; never change after use;
- `CERTBOT_*`: certificate and renewal settings;
- `BACKUP_ROOT` and `BACKUP_RETENTION_DAYS`: backup policy.

`NODERED_ADMIN_PASSWORD` and `NODERED_HTTP_NODE_PASSWORD` are plaintext
bootstrap values used only to generate hashes. Prefer the corresponding bcrypt
hash variables and remove plaintext values after configuration.

## Security notes

- Never commit `.env`, passwords, tokens, keys, or certificates.
- Keep `.env` at mode `0600`.
- Do not expose Node-RED port `1880` through the firewall.
- Do not change `NODE_RED_CREDENTIAL_SECRET` after storing flow credentials.
- Test certificate issuance with `make cert-le-stag` before production.
- A self-signed certificate is not trusted by browsers.
