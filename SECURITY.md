# Security

Este repositório é público e deve permanecer livre de informações internas de qualquer organização.

## Não publique

- endereços IP internos;
- nomes de domínio reais;
- nomes de servidores ou estações;
- nomes de usuários;
- nomes de empresas ou clientes;
- caminhos UNC reais;
- nomes de OUs, grupos ou GPOs reais;
- GUIDs de GPO/SYSVOL associados a ambiente real;
- credenciais, tokens, senhas ou chaves.

Use exemplos genéricos como:

```text
example.local
FILESERVER
PC-001
Inventory-GPO-Computers
\\FILESERVER\InventoryShare\Inventory
```

## Princípio de menor privilégio

O agente executa como `SYSTEM`. Em acesso SMB remoto, a estação usa a conta de computador do domínio.

Recomendações:

- grupo de segurança dedicado para as estações autorizadas;
- `Modify` no diretório de inventário em vez de `Full Control` quando possível;
- revisar permissões SMB e NTFS separadamente;
- testar primeiro em uma estação piloto;
- não usar `Enforced` na GPO sem necessidade operacional;
- manter o compartilhamento acessível apenas pela rede interna/VPN corporativa conforme a arquitetura adotada.

## Relato de vulnerabilidades

Não publique detalhes sensíveis de infraestrutura em issues públicas. Use um canal privado apropriado para reportar vulnerabilidades ou exposição de dados.
