# Unishop · Banco de dados

Sistema de marketplace universitário (Unifor) · trabalho de Desenvolvimento de Plataformas Web, T242-12.
Este repositório guarda o **material de banco de dados** do projeto (MER e scripts de apoio). O código e a documentação completa ficam no repositório principal do Unishop.

## Fonte de verdade

O banco é criado e evoluído **só pelo Prisma** (`schema.prisma` → migração `0_init` → migração manual), conforme `docs/BancoDeDados/bd.md` v0.2 do repositório principal. Os arquivos SQL daqui são **cópias de apoio**: em caso de divergência, vale o `bd.md`.

- PostgreSQL 18 (Neon em produção; Docker Compose em desenvolvimento).
- 8 tabelas: `usuario`, `categoria`, `anuncio`, `imagem_anuncio`, `pedido`, `pagamento`, `log_admin`, `token_usuario`.
- Datas em `timestamptz` (UTC), dinheiro em `numeric(10,2)`, chaves `GENERATED ALWAYS AS IDENTITY`.

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `docs/mer_unishop.drawio` | MER atual (v0.2), 8 entidades, aberto no draw.io |
| `database/migracao_manual_v0.2.sql` | `CHECK`, índices, view `anuncio_visivel` (cópia da seção 14 do `bd.md`) |
| `database/papeis_v0.2.sql` | Papéis `unishop_migrator`, `unishop_app`, `unishop_backup` e permissões |
| `database/seed.sql` | As 6 categorias fixas (RN-CAT-01) |
| `legacy/` | Estado de 07/10/2026 (dump e MER antigos). **Não restaurar** |

## Como recriar o banco

1. No repositório principal: gerar o `schema.prisma` e a migração `0_init`.
2. Aplicar `database/migracao_manual_v0.2.sql` (segunda migração) e, se os papéis existirem, `database/papeis_v0.2.sql`.
3. Rodar `database/seed.sql`. A conta admin vem do seed do backend, não daqui.

> Pendências: testar a migração `0_init` + manual em banco vazio e confirmar no Neon como criar os papéis (bd.md §15).
