# Security

## Sensitive data

Never include passwords, DNS tokens, private keys, certificates, or `.env`
files in commits, issues, or public logs.

## Reporting vulnerabilities

Do not open a public issue for an unpatched vulnerability. Use GitHub's private
security reporting channel when it is available for the repository.

## Running scripts

The installers perform privileged operations. Before using a target:

1. review the `Makefile` and associated scripts;
2. confirm the values in `.env`;
3. test first on a non-critical machine;
4. keep backups outside the target machine.
