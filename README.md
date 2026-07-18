# Makefiles

Coleção de Makefiles e ficheiros auxiliares para instalar, configurar e operar
serviços e aplicações nas minhas máquinas.

> Os scripts podem alterar a configuração do sistema e vários alvos requerem
> privilégios de `root`. Leia sempre o código e reveja o ficheiro `.env` antes
> de executar uma instalação.

## Serviços disponíveis

| Serviço | Plataforma | Descrição |
| --- | --- | --- |
| [Node-RED](services/nodered-almalinux/) | AlmaLinux 9 | Node-RED, Nginx, TLS, systemd, firewall, backups e upgrades |

## Utilização

Cada serviço é utilizado exclusivamente a partir do seu próprio diretório:

```bash
cd services/nodered-almalinux
make init
vi .env
make lint
make install
```

## Estrutura

```text
services/<serviço>/
├── Makefile
├── .env.example
├── README.md
└── scripts/
```

Cada serviço é autónomo, documentado e inclui um alvo `lint`. Não existe um
Makefile agregador na raiz do repositório. Segredos e configuração específica
de cada máquina ficam em `.env`, que não deve ser adicionado ao Git.

As convenções obrigatórias para agentes e contribuições estão definidas em
[`AGENTS.md`](AGENTS.md).

## Assistência Codex

O skill local [`makefile-maintainer`](.codex/skills/makefile-maintainer/SKILL.md)
cria e revê GNU Makefiles segundo estas convenções. Pode ser invocado com:

```text
$makefile-maintainer
```

O script `.codex/skills/makefile-maintainer/scripts/audit-repository.sh` aplica
verificações determinísticas de estrutura, interface, documentação de alvos e
sintaxe dos scripts.

## Origem

O primeiro instalador deste repositório foi desenvolvido a partir da conversa
[Instalação Node-RED AlmaLinux](https://chatgpt.com/share/6a5ba9e3-9ee8-83ed-a64f-7ee6b087207e).

## Licença

Distribuído sob a [licença MIT](LICENSE).
