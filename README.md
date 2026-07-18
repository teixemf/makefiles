# Makefiles

A collection of Makefiles and supporting files for installing, configuring, and
operating services and applications on my machines.

> These scripts can modify system configuration and several targets require
> `root` privileges. Always read the code and review `.env` before installing.

## Available services

| Service | Platform | Description |
| --- | --- | --- |
| [Node-RED](services/nodered-almalinux/) | AlmaLinux 9 | Node-RED, Nginx, TLS, systemd, firewall, backups, and upgrades |

## Usage

Each service is used exclusively from its own directory:

```bash
cd services/nodered-almalinux
make init
vi .env
make lint
make install
```

## Estrutura

```text
services/<service>/
├── Makefile
├── .env.example
├── README.md
└── scripts/
```

Each service is self-contained, documented, and includes a `lint` target. There
is no aggregate Makefile at the repository root. Machine-specific secrets and
configuration belong in `.env`, which must not be committed to Git.

Mandatory agent and contribution conventions are defined in
[`AGENTS.md`](AGENTS.md).

## Codex assistance

O skill local [`makefile-maintainer`](.codex/skills/makefile-maintainer/SKILL.md)
skill creates and reviews GNU Makefiles according to these conventions. It can
be invoked with:

```text
$makefile-maintainer
```

O script `.codex/skills/makefile-maintainer/scripts/audit-repository.sh` aplica
performs deterministic checks for structure, interfaces, documented targets,
and script syntax.

## Origin

The first installer in this repository was developed from the
[Node-RED AlmaLinux installation](https://chatgpt.com/share/6a5ba9e3-9ee8-83ed-a64f-7ee6b087207e)
conversation.

## License

Distributed under the [MIT license](LICENSE).
