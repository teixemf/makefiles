# Segurança

## Dados sensíveis

Nunca inclua palavras-passe, tokens DNS, chaves privadas, certificados ou
ficheiros `.env` em commits, issues ou logs públicos.

## Reportar vulnerabilidades

Não abra uma issue pública para uma vulnerabilidade ainda não corrigida. Use o
canal privado de reporte de segurança do GitHub quando estiver disponível no
repositório.

## Execução dos scripts

Os instaladores executam operações privilegiadas. Antes de usar um alvo:

1. reveja o `Makefile` e os scripts associados;
2. confirme os valores no `.env`;
3. teste primeiro numa máquina não crítica;
4. mantenha backups fora da máquina alvo.
