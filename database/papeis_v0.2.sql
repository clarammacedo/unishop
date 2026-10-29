-- Papéis e permissões (cópia do bd.md v0.2, seção 14). Os papéis são criados fora do Git, com senha própria.
-- Confirmar no painel do Neon como criar papéis (pendência 1 do bd.md).

-- Criados fora do Git, com senha própria: unishop_migrator, unishop_app, unishop_backup

-- Quem migra é dono do schema (as tabelas ficam com ele como dono)
GRANT ALL ON SCHEMA public TO unishop_migrator;

-- A aplicação lê e escreve, mas não altera estrutura
GRANT USAGE ON SCHEMA public TO unishop_app, unishop_backup;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO unishop_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO unishop_app;

-- O backup só lê
GRANT SELECT ON ALL TABLES IN SCHEMA public TO unishop_backup;

-- Vale também para as tabelas criadas nas próximas migrações
ALTER DEFAULT PRIVILEGES FOR ROLE unishop_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO unishop_app;
ALTER DEFAULT PRIVILEGES FOR ROLE unishop_migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO unishop_app;
ALTER DEFAULT PRIVILEGES FOR ROLE unishop_migrator IN SCHEMA public
  GRANT SELECT ON TABLES TO unishop_backup;
