# Changelog

## 8.2 — Stable

- versão validada em estação piloto e em estação limpa;
- padronização da versão `8.2` em deploy, logs, tarefa e CSV;
- resumo de rede mostra apenas IPv4 relevantes de interfaces físicas ativas;
- APIPA `169.254.x.x`, VPNs e interfaces virtuais ficam fora do resumo;
- todos os endereços continuam disponíveis nos arquivos detalhados de rede;
- execução distribuída entre 2 e 10 minutos após o boot;
- coleta diária com marcador de sucesso;
- logs locais de deploy e execução;
- histórico JSON diário com retenção de 30 dias;
- documentação de implantação, validação, rollback e troubleshooting ampliada;
- nomes e exemplos do repositório público tornados completamente genéricos.

## 8.1.1

- correção da normalização de caracteres no Windows PowerShell 5.1;
- remoção de chamadas `Replace(char, char)` incompatíveis com substituição por string vazia.

## 8.1

- refatoração do coletor em PowerShell legível;
- separação entre coleta, runner, instalador de tarefa e deploy via GPO;
- retry do compartilhamento quando a rede ainda não está disponível;
- uma coleta bem-sucedida por dia;
- ferramentas auxiliares para AD, GPO, validação e rollback.

## 8.0

- reorganização inicial do projeto público em `src`, `deploy`, `tools` e `docs`.
