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
| `docs/bd.md` | Cópia do `bd.md` v0.2: dicionário de dados, regras e SQL (referência para o trabalho) |
| `docs/checklist-mer.md` | O que mudar no MER, item por item |
| `database/schema.prisma` | Cópia do `schema.prisma` do repositório principal |
| `database/0_init.sql` | Migração `0_init` gerada do `schema.prisma` (tabelas, FKs, `UNIQUE` simples) |
| `database/migracao_manual_v0.2.sql` | Identity, `CHECK`, índices, view `anuncio_visivel` (cópia da seção 14 do `bd.md`) |
| `database/papeis_v0.2.sql` | Papéis `unishop_migrator`, `unishop_app`, `unishop_backup` e permissões |
| `database/seed.sql` | As 6 categorias fixas (RN-CAT-01) |
| `database/testes_integridade.sql` | Testes que conferem se o banco recusa dado inválido (termina em `ROLLBACK`) |
| `docker-compose.yml` | PostgreSQL 18 local para rodar os scripts |
| `legacy/` | Estado de 07/10/2026 (dump e MER antigos). **Não restaurar** |

## Como recriar e testar o banco (em ordem)

1. `docker compose up -d` (banco `unishop_dev`, usuário e senha `dev`, porta 5432).
2. Aplicar, nesta ordem, com `psql postgresql://dev:dev@localhost:5432/unishop_dev -v ON_ERROR_STOP=1 -f <arquivo>`:
   `database/0_init.sql`, `database/migracao_manual_v0.2.sql`, `database/seed.sql`.
3. Rodar `database/testes_integridade.sql`. Sucesso = termina sem `ERROR` (cada teste imprime `OK`). O arquivo não deixa nada gravado.
4. Papéis (`database/papeis_v0.2.sql`): só depois de criar os três papéis com senha, fora do Git.
5. A conta admin vem do seed do backend, não daqui.

Para recomeçar do zero: `docker compose down -v`.

## Tarefas do banco

- **Atualizar o MER:** seguir `docs/checklist-mer.md` (pendência 4 do `bd.md`).
- **Testar o banco vazio:** passos acima (pendência 5). Já foi rodado com sucesso em PGlite (PostgreSQL em memória); falta rodar em PostgreSQL 18 de verdade.
- **Papéis no Neon:** confirmar no painel como criar os papéis com senha no plano gratuito (pendência 1).

> Mudou o `schema.prisma` ou a seção 14 no repositório principal? Recopie os arquivos daqui e gere o `0_init.sql` de novo.
