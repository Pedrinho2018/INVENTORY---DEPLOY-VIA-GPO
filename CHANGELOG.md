# Changelog

## 8.2-GM — Stable

- versão homologada após piloto em estação existente e estação limpa;
- padronização da versão `8.2-GM` em deploy, logs, tarefa e CSV;
- resumo de rede passa a considerar apenas interfaces físicas ativas;
- endereços APIPA `169.254.x.x` removidos do resumo;
- VPNs e interfaces virtuais removidas de `IPv4Adicionais` do resumo;
- todos os endereços continuam preservados em `rede-<PC>.csv` e `interfaces-<PC>.csv`;
- stagger de Startup entre 2 e 10 minutos por hostname;
- fallback de Logon entre 1 e 5 minutos;
- execução diária idempotente via `last-success.txt`;
- retry do compartilhamento antes da coleta;
- scripts de validação, teste imediato e rollback adicionados;
- documentação de implantação e troubleshooting ampliada.

## 8.1.1-GM

- correção da normalização de texto no Windows PowerShell 5.1;
- substituição de `Replace(char, char)` por regex para remoção de BOM/NUL.

## 8.1-GM

- refatoração do coletor monolítico para componentes PowerShell legíveis;
- separação entre deploy, tarefa, runner e coletor;
- logs estruturados e atualização automática via GPO.

## 8.0

- primeira versão pública sanitizada do projeto refatorado.
