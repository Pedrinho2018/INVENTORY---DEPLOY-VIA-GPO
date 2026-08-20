# Security

Este projeto administra inventário de endpoints e pode revelar informações sensíveis de infraestrutura.

## Não publique

- IPs privados do ambiente real;
- nomes internos de servidores, domínios ou compartilhamentos;
- credenciais, tokens, certificados ou chaves;
- inventários CSV/JSON coletados de estações reais;
- nomes de usuários, serial numbers ou outras informações operacionais sem necessidade.

## Princípios de implantação

- execute o agente com o menor conjunto de permissões necessário;
- use um grupo de computadores dedicado no Active Directory;
- conceda `Modify`, e não `Full Control`, quando suficiente;
- valide permissões SMB e NTFS separadamente;
- teste a GPO em uma máquina piloto e depois em uma máquina limpa antes do rollout;
- mantenha logs locais para diagnóstico e auditoria.

Relatos de segurança devem evitar incluir dados reais do ambiente em issues públicas.
