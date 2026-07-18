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
vim .env                  # defina FQDN, autenticação e DNS
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

`make cert-le-prod` activa automaticamente o timer oficial
`certbot-renew.timer`. Não é necessário executar outro comando para o activar.
Para consultar o estado, use opcionalmente:

```bash
systemctl list-timers certbot-renew.timer
```

O staging usa directórios Certbot separados, não instala o certificado no
Nginx e não activa o timer. Assim, o teste nunca substitui um certificado de
produção já instalado.

O `.env` é interpretado como Bash. As credenciais são usadas para preparar o
ficheiro protegido lido pelo plugin DNS do Certbot. Cloudflare é o fornecedor
predefinido:

```dotenv
CERTBOT_DNS_PROVIDER=cloudflare
CLOUDFLARE_API_TOKEN='token-restrito'
```

Use um token restrito à zona necessária, com `Zone:DNS:Edit` e
`Zone:Zone:Read`. O token é escrito em
`/etc/letsencrypt/dns-cloudflare-<FQDN>.ini`, com modo `0600`. O modo DNS
manual não é usado porque não permite renovação automática sem hooks
adicionais.

## Comandos acessórios

Todos os comandos abaixo são executados no directório do serviço. Os alvos que
alteram o sistema pedem `root` ou usam `sudo` automaticamente.

| Comando | Função |
| --- | --- |
| `make help` | Mostra a ajuda dos alvos disponíveis. |
| `make init` | Cria `.env` a partir de `.env.example`; falha se `.env` já existir. |
| `make lint` | Valida a sintaxe Bash sem root, rede ou alterações no sistema. |
| `make configure` | Regenera `settings.js`, o ambiente protegido, a unidade systemd e a configuração Nginx. |
| `make bcrypt` | Pede uma password silenciosamente e imprime o respectivo bcrypt; instala `httpd-tools` se necessário. |
| `make cert-selfsigned` | Gera/substitui o certificado TLS auto-assinado. |
| `make upgrade` | Faz backup, actualiza Node.js/Node-RED/Nginx/Certbot, configura e valida. |
| `make upgrade-nodes` | Actualiza os nós adicionais da palette; pode introduzir incompatibilidades. |
| `make upgrade-system` | Actualiza o sistema operativo e depois executa o upgrade do serviço. |
| `make backup` | Cria um backup protegido da configuração, dados e Certbot. |
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

A autenticação do editor e da Admin API não protege automaticamente os
endpoints criados pelos nós `HTTP In`. Com a opção global desactivada:

```dotenv
NODERED_HTTP_NODE_AUTH=false
```

os endpoints HTTP In não têm uma autenticação global fornecida pelo Node-RED.
Mesmo assim, cada flow pode implementar a sua própria autenticação individual,
por exemplo validando um token, uma API key ou um header através de nós
`Function`, `Change` ou outra lógica do flow.

Para exigir autenticação Basic HTTP global em todos os endpoints `HTTP In`:

```dotenv
NODERED_HTTP_NODE_AUTH=true
NODERED_HTTP_NODE_USER=api
NODERED_HTTP_NODE_PASSWORD=
NODERED_HTTP_NODE_PASSWORD_HASH='$2b$10$...'
```

Quando esta opção está activa, todos os clientes têm de enviar credenciais
HTTP válidas. Isto também se aplica a APIs, webhooks e callbacks criados pelos
flows, podendo exigir alterações nas integrações externas.

Para gerar um hash antes da instalação, sem escrever a password no comando nem
no histórico da shell:

```bash
make bcrypt
```

O alvo pede a password duas vezes e imprime apenas o hash. Se `htpasswd` não
existir, instala o pacote `httpd-tools` através de `dnf` (com `root` ou `sudo`).
Depois use o resultado, por exemplo:

```dotenv
NODERED_ADMIN_PASSWORD=
NODERED_ADMIN_PASSWORD_HASH='$2b$10$...'
```

### TLS e Certbot

| Variável | Descrição |
| --- | --- |
| `SELF_SIGNED_DAYS` | Validade, em dias, do certificado auto-assinado. |
| `CERTBOT_EMAIL` | Email da conta Let's Encrypt; obrigatório para `cert-le-stag` e `cert-le-prod`. |
| `CERTBOT_DNS_PROVIDER` | Plugin DNS do Certbot. O valor predefinido é `cloudflare`. |
| `CERTBOT_DNS_PROPAGATION_SECONDS` | Segundos de espera pela propagação do registo DNS. |
| `CERTBOT_KEY_TYPE` | Tipo de chave: `ecdsa` ou `rsa`. |
| `CERTBOT_ELLIPTIC_CURVE` | Curva usada com ECDSA: `secp256r1` ou `secp384r1`. |
| `CERTBOT_RSA_KEY_SIZE` | Tamanho usado com RSA: `2048`, `3072` ou `4096`. |
| `CERTBOT_DNS_CREDENTIALS_FILE` | Ficheiro protegido com as credenciais do plugin DNS; vazio usa um caminho específico por FQDN. |
| `CERTBOT_DEPLOY_HOOK` | Hook que copia certificados renovados para o Nginx e o recarrega; vazio usa um nome específico por FQDN. |

Os directórios de produção são os padrões do pacote
(`/etc/letsencrypt`, `/var/lib/letsencrypt` e `/var/log/letsencrypt`) para que
o timer oficial os renove sem configuração adicional. O
`certbot-renew.timer` é um recurso global do sistema e verifica todos os
certificados Certbot guardados em `/etc/letsencrypt`; cada certificado mantém
o seu próprio hook de deploy.

Para Cloudflare:

| Variável | Descrição |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Token restrito à zona, com permissões DNS Edit e Zone Read. |

Depois da primeira emissão, `CLOUDFLARE_API_TOKEN` pode ficar vazio no `.env`
se `CERTBOT_DNS_CREDENTIALS_FILE` já existir com modo `0600`. Para outro
fornecedor disponível no EPEL, altere `CERTBOT_DNS_PROVIDER` e crie previamente
o ficheiro de credenciais no formato exigido pelo plugin correspondente.

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
Certbot e o plugin DNS, regenera a configuração e valida os serviços.

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
- `/etc/letsencrypt` — conta, credenciais, certificados e renovação de produção;
- `/var/lib/letsencrypt` e `/var/log/letsencrypt` — estado e logs de produção;
- `/etc/letsencrypt-staging` — configuração/certificados isolados de staging;
- `/usr/local/libexec/nodered-certbot-deploy-<FQDN>` — deploy e reload após renovação;
- `/var/backups/nodered` — backups protegidos, incluindo `.env` e dados Certbot.

## Notas de segurança

- Não faça commit do `.env`.
- Mantenha o `.env` com modo `0600`.
- Não abra a porta 1880 na firewall.
- Não altere `NODE_RED_CREDENTIAL_SECRET` após guardar credenciais nos flows.
- Teste primeiro com `make cert-le-stag`.
- Um certificado auto-assinado não será confiável para browsers.
