# Node-RED em AlmaLinux com Make

Instalador repetível para:

- Node.js 24 e Node-RED;
- conta de sistema reservada, sem login;
- autenticação `adminAuth`;
- Nginx como reverse proxy;
- HTTPS auto-assinado por defeito;
- Let's Encrypt DNS-01 em staging ou produção;
- renovação automática por `systemd`;
- backup e upgrade.

## Arranque habitual

Execute os comandos a partir de `services/nodered-almalinux/`:

```bash
make init                 # cria .env sem substituir um ficheiro existente
vim .env              # defina FQDN, autenticação e DNS
chmod 600 .env
make install              # instala Node-RED, Nginx, firewall e TLS inicial
make validate             # valida a instalação
make status               # mostra o estado resumido
```

Por defeito, o Node-RED fica em `127.0.0.1:1880`, não é exposto directamente,
e o Nginx publica as portas 80/443. O `make install` instala um certificado
auto-assinado se ainda não existir.

### Aplicar alterações

Depois de alterar uma variável de configuração no `.env`, o comando normal é
voltar a executar:

```bash
make install
```

Este comando é o ponto de entrada completo e repetível: instala/actualiza as
dependências, reaplica a configuração do Node-RED e do Nginx, preserva os
dados existentes, activa os serviços, reinicia o Node-RED e termina executando
automaticamente `validate` e `status`. Não é necessário executar `make
configure` separadamente.

Há duas excepções intencionais:

- alterações de certificado devem usar `make cert-selfsigned`,
  `make cert-le-stag` ou `make cert-le-prod`, conforme o caso;
- alterações dos nós da palette devem usar explicitamente `make upgrade-nodes`.

Depois de uma alteração, pode confirmar o resultado com:

```bash
make validate
make status
```

### TLS com Let's Encrypt

Depois de configurar o fornecedor DNS no `.env`, teste primeiro a emissão:

```bash
make cert-le-stag
```

Quando o teste estiver correcto, emita o certificado confiável de produção:

```bash
make cert-le-prod
```

`make cert-le-prod` cria e activa automaticamente o
`acme-nodered-renew.timer`. Não é necessário executar outro comando para o
activar. Para consultar o estado, use opcionalmente:

```bash
systemctl list-timers acme-nodered-renew.timer
```

O staging é apenas um teste e não activa o timer de renovação. Os certificados
staging não são confiáveis pelos browsers.

O `.env` é interpretado como Bash e as variáveis são exportadas para o hook
DNS do `acme.sh`. Para Cloudflare, por exemplo:

```dotenv
ACME_DNS_PROVIDER=dns_cf
CF_Token='token-restrito'
CF_Account_ID='account-id'
```

Use um token restrito à zona necessária. O modo DNS manual não é usado porque
não permite renovação automática.

## Comandos acessórios

Todos os comandos abaixo são executados no directório do serviço. Os alvos que
alteram o sistema pedem `root` ou usam `sudo` automaticamente.

| Comando | Função |
| --- | --- |
| `make help` | Mostra a ajuda dos alvos disponíveis. |
| `make init` | Cria `.env` a partir de `.env.example`; falha se `.env` já existir. |
| `make lint` | Valida a sintaxe Bash sem root, rede ou alterações no sistema. |
| `make configure` | Regenera `settings.js`, o ambiente protegido, a unidade systemd e a configuração Nginx. |
| `make bcrypt` | Pede uma password silenciosamente e imprime o respectivo bcrypt. Requer `make install`. |
| `make cert-selfsigned` | Gera/substitui o certificado TLS auto-assinado. |
| `make upgrade` | Faz backup, actualiza o sistema Node.js/Node-RED/Nginx/acme.sh, configura e valida. |
| `make upgrade-nodes` | Actualiza os nós adicionais da palette; pode introduzir incompatibilidades. |
| `make upgrade-system` | Actualiza o sistema operativo e depois executa o upgrade do serviço. |
| `make backup` | Cria um backup protegido da configuração, dados e ACME. |
| `make validate` | Verifica serviço, autenticação, TLS, portas e firewall. |
| `make status` | Mostra o estado do Node-RED, Nginx, firewall e certificados. |
| `make restart` | Reinicia Node-RED e Nginx. |
| `make logs` | Segue apenas o journal do Node-RED. |
| `make logs-nginx` | Segue apenas os logs de acesso/erro do Nginx. |
| `make logs-all` | Segue simultaneamente o Node-RED e o Nginx. |
| `make versions` | Mostra as versões instaladas. |

Para usar outra instância/configuração:

```bash
make ENV_FILE=/root/nodered-producao.env install
make ENV_FILE=/root/nodered-producao.env status
```

## Variáveis do `.env`

O ficheiro real deve ter modo `0600`, não deve ser committed e deve ser
editado como sintaxe Bash. Use aspas para passwords, tokens ou valores com
caracteres especiais.

### Identidade e rede

| Variável | Descrição |
| --- | --- |
| `FQDN` | Nome DNS completo usado pelo Nginx e pelos certificados, por exemplo `nodered.example.com`. |
| `NODE_MAJOR` | Versão principal do Node.js instalada pelo NodeSource, por exemplo `24`. |
| `NODERED_VERSION` | Versão do Node-RED. `latest` acompanha a versão mais recente; para instalações previsíveis, fixe uma versão. |
| `NODERED_USER` | Conta de sistema que executa o Node-RED. Por defeito, `nodered`. |
| `NODERED_GROUP` | Grupo da conta do serviço. Por defeito, `nodered`. |
| `NODERED_HOME` | User directory do Node-RED, normalmente `/var/lib/nodered`. |
| `NODERED_BIND` | Endereço de escuta do Node-RED. Deve permanecer `127.0.0.1`; o acesso externo é feito pelo Nginx. |
| `NODERED_PORT` | Porta local do Node-RED, por defeito `1880`. |
| `NODERED_SESSION_SECONDS` | Duração da sessão de autenticação em segundos. |

### Autenticação e credenciais

| Variável | Descrição |
| --- | --- |
| `NODERED_ADMIN_USER` | Utilizador do editor e da Admin API. |
| `NODERED_ADMIN_PASSWORD` | Password em claro usada apenas durante a configuração para gerar bcrypt. Prefira o hash. |
| `NODERED_ADMIN_PASSWORD_HASH` | Hash bcrypt do administrador. Quando definido, tem prioridade sobre `NODERED_ADMIN_PASSWORD`. |
| `NODE_RED_CREDENTIAL_SECRET` | Segredo usado para cifrar credenciais guardadas nos flows. Não o altere depois de começar a usar o serviço. `make init` tenta gerar um valor. |
| `NODERED_HTTP_NODE_AUTH` | `true` protege também os endpoints HTTP In; `false` desactiva essa camada. |
| `NODERED_HTTP_NODE_USER` | Utilizador da autenticação dos endpoints HTTP In. |
| `NODERED_HTTP_NODE_PASSWORD` | Password em claro usada apenas para gerar o hash HTTP. |
| `NODERED_HTTP_NODE_PASSWORD_HASH` | Hash bcrypt da password dos endpoints HTTP. |

Para gerar um hash sem escrever a password no comando nem no histórico da shell:

```bash
make bcrypt
```

Depois use o resultado, por exemplo:

```dotenv
NODERED_ADMIN_PASSWORD=
NODERED_ADMIN_PASSWORD_HASH='$2b$10$...'
```

### TLS e ACME

| Variável | Descrição |
| --- | --- |
| `SELF_SIGNED_DAYS` | Validade, em dias, do certificado auto-assinado. |
| `ACME_EMAIL` | Email da conta Let's Encrypt; é obrigatório para `cert-le-stag` e `cert-le-prod`. |
| `ACME_DNS_PROVIDER` | Hook DNS do `acme.sh`, por exemplo `dns_cf` para Cloudflare. |
| `ACME_DNS_SLEEP` | Segundos de espera pela propagação do registo DNS. |
| `ACME_KEY_LENGTH` | Chave do certificado: `ec-256`, `ec-384`, `2048`, `3072` ou `4096`. |
| `ACME_GIT_REF` | Branch, tag ou ref do checkout do `acme.sh`; `master` é o valor do exemplo. |
| `ACME_HOME` | Directório do checkout do `acme.sh`, normalmente `/opt/acme.sh`. |
| `ACME_CONFIG_ROOT` | Configuração ACME separada por ambiente, normalmente `/etc/acme.sh`. |
| `ACME_CERT_ROOT` | Dados/certificados ACME separados por ambiente, normalmente `/var/lib/acme.sh`. |

Para Cloudflare:

| Variável | Descrição |
| --- | --- |
| `CF_Token` | Token Cloudflare restrito à edição DNS da zona necessária. |
| `CF_Account_ID` | ID da conta Cloudflare. |
| `CF_Zone_ID` | ID da zona, opcional quando o hook consegue determinar a zona. |

Para outros fornecedores DNS, altere `ACME_DNS_PROVIDER` e adicione as
variáveis exigidas pelo hook correspondente do `acme.sh`, como
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `OVH_AK`, `OVH_AS` e `OVH_CK`.

### Backups e compatibilidade

| Variável | Descrição |
| --- | --- |
| `UPGRADE_PALETTE_NODES` | Mantido no `.env` para a política de actualização dos nós; o valor recomendado é `false`. Use `make upgrade-nodes` explicitamente. |
| `BACKUP_ROOT` | Directório dos backups, normalmente `/var/backups/nodered`. |
| `BACKUP_RETENTION_DAYS` | Número de dias de retenção dos backups. |
| `ALLOW_RHEL_COMPAT` | `true` permite derivados RHEL compatíveis; `false` restringe a instalação a AlmaLinux. |

## Upgrade e operação

Upgrade normal:

```bash
make upgrade
```

Este alvo cria um backup, actualiza os pacotes RPM, garante `NODE_MAJOR`,
actualiza Node-RED para `NODERED_VERSION`, executa `npm rebuild`, actualiza o
checkout `acme.sh`, regenera a configuração e valida os serviços.

Os nós adicionais da palette não são actualizados automaticamente:

```bash
make upgrade-nodes
```

Para actualizar primeiro o sistema operativo e depois o serviço:

```bash
make upgrade-system
```

## Ficheiros instalados

- `/var/lib/nodered` — userDir e flows;
- `/etc/node-red/environment` — segredos/hashes, modo `0640`;
- `/etc/systemd/system/nodered.service`;
- `/etc/nginx/conf.d/nodered.conf`;
- `/etc/nginx/tls/<FQDN>/`;
- `/opt/acme.sh`;
- `/etc/acme.sh/{staging,prod}`;
- `/var/lib/acme.sh/{staging,prod}`;
- `/var/backups/nodered` — backups protegidos, incluindo `.env` e dados ACME.

## Notas de segurança

- Não faça commit do `.env`.
- Mantenha o `.env` com modo `0600`.
- Não abra a porta 1880 na firewall.
- Não altere `NODE_RED_CREDENTIAL_SECRET` após guardar credenciais nos flows.
- Teste primeiro com `make cert-le-stag`.
- Um certificado staging ou auto-assinado não será confiável para browsers.
