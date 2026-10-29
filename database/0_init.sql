-- Gerado de schema.prisma com: npx prisma migrate diff --from-empty --to-schema prisma/schema.prisma --script (Prisma 7.10.1). Cópia de apoio; não editar à mão.
-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "usuario" (
    "id_usuario" SERIAL NOT NULL,
    "nome" VARCHAR(150) NOT NULL,
    "email" VARCHAR(150) NOT NULL,
    "senha_hash" VARCHAR(255),
    "google_sub" VARCHAR(64),
    "whatsapp" VARCHAR(20),
    "curso" VARCHAR(100),
    "foto_perfil" VARCHAR(255),
    "verificacao" BOOLEAN NOT NULL DEFAULT false,
    "tipo_usuario" VARCHAR(20) NOT NULL DEFAULT 'aluno',
    "status_conta" VARCHAR(20) NOT NULL DEFAULT 'ativa',
    "data_aceite_termos" TIMESTAMPTZ(6),
    "tentativas_login" INTEGER NOT NULL DEFAULT 0,
    "bloqueado_ate" TIMESTAMPTZ(6),
    "senha_alterada_em" TIMESTAMPTZ(6),
    "data_cadastro" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ultimo_acesso" TIMESTAMPTZ(6),

    CONSTRAINT "usuario_pkey" PRIMARY KEY ("id_usuario")
);

-- CreateTable
CREATE TABLE "categoria" (
    "id_categoria" SERIAL NOT NULL,
    "nome" VARCHAR(100) NOT NULL,

    CONSTRAINT "categoria_pkey" PRIMARY KEY ("id_categoria")
);

-- CreateTable
CREATE TABLE "anuncio" (
    "id_anuncio" SERIAL NOT NULL,
    "nome" VARCHAR(150) NOT NULL,
    "descricao" TEXT NOT NULL,
    "preco" DECIMAL(10,2) NOT NULL,
    "quantidade" INTEGER NOT NULL DEFAULT 1,
    "whatsapp" VARCHAR(20) NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'ativo',
    "data_publicacao" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "visualizacoes" INTEGER NOT NULL DEFAULT 0,
    "contatos" INTEGER NOT NULL DEFAULT 0,
    "excluido_em" TIMESTAMPTZ(6),
    "vendido_em" TIMESTAMPTZ(6),
    "id_usuario" INTEGER NOT NULL,
    "id_categoria" INTEGER NOT NULL,

    CONSTRAINT "anuncio_pkey" PRIMARY KEY ("id_anuncio")
);

-- CreateTable
CREATE TABLE "imagem_anuncio" (
    "id_imagem" SERIAL NOT NULL,
    "id_anuncio" INTEGER NOT NULL,
    "url_imagem" VARCHAR(255) NOT NULL,
    "public_id" VARCHAR(255) NOT NULL,
    "ordem" INTEGER NOT NULL,

    CONSTRAINT "imagem_anuncio_pkey" PRIMARY KEY ("id_imagem")
);

-- CreateTable
CREATE TABLE "pedido" (
    "id_pedido" SERIAL NOT NULL,
    "id_anuncio" INTEGER NOT NULL,
    "id_comprador" INTEGER NOT NULL,
    "id_vendedor" INTEGER NOT NULL,
    "forma_negociacao" VARCHAR(20) NOT NULL,
    "status_pedido" VARCHAR(20) NOT NULL DEFAULT 'em_negociacao',
    "nome_produto" VARCHAR(150) NOT NULL,
    "imagem_url" VARCHAR(255),
    "quantidade" INTEGER NOT NULL,
    "preco_unitario" DECIMAL(10,2) NOT NULL,
    "taxa_servico" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "valor_total" DECIMAL(10,2) NOT NULL,
    "data_pedido" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "concluido_em" TIMESTAMPTZ(6),
    "atualizado_em" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pedido_pkey" PRIMARY KEY ("id_pedido")
);

-- CreateTable
CREATE TABLE "pagamento" (
    "id_pagamento" SERIAL NOT NULL,
    "id_pedido" INTEGER NOT NULL,
    "id_transacao_gateway" VARCHAR(255),
    "forma_pagamento" VARCHAR(20) NOT NULL,
    "status_pagamento" VARCHAR(20) NOT NULL,
    "data_pagamento" TIMESTAMPTZ(6),
    "valor" DECIMAL(10,2),
    "data_expiracao" TIMESTAMPTZ(6),
    "chave_idempotencia" VARCHAR(100),
    "tentativas_estorno" INTEGER NOT NULL DEFAULT 0,
    "ultimo_erro" TEXT,
    "data_criacao" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pagamento_pkey" PRIMARY KEY ("id_pagamento")
);

-- CreateTable
CREATE TABLE "log_admin" (
    "id_log" SERIAL NOT NULL,
    "id_admin" INTEGER NOT NULL,
    "acao" VARCHAR(50) NOT NULL,
    "entidade" VARCHAR(20) NOT NULL,
    "id_entidade" INTEGER NOT NULL,
    "detalhes" JSONB,
    "data_acao" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "log_admin_pkey" PRIMARY KEY ("id_log")
);

-- CreateTable
CREATE TABLE "token_usuario" (
    "id_token" SERIAL NOT NULL,
    "id_usuario" INTEGER NOT NULL,
    "tipo" VARCHAR(30) NOT NULL,
    "token_hash" VARCHAR(255) NOT NULL,
    "novo_email" VARCHAR(150),
    "expira_em" TIMESTAMPTZ(6) NOT NULL,
    "usado_em" TIMESTAMPTZ(6),
    "criado_em" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "token_usuario_pkey" PRIMARY KEY ("id_token")
);

-- CreateIndex
CREATE UNIQUE INDEX "usuario_google_sub_key" ON "usuario"("google_sub");

-- CreateIndex
CREATE UNIQUE INDEX "categoria_nome_key" ON "categoria"("nome");

-- CreateIndex
CREATE UNIQUE INDEX "uq_imagem_ordem" ON "imagem_anuncio"("id_anuncio", "ordem");

-- CreateIndex
CREATE UNIQUE INDEX "uq_pagamento_idempotencia" ON "pagamento"("chave_idempotencia");

-- CreateIndex
CREATE UNIQUE INDEX "uq_token_hash" ON "token_usuario"("token_hash");

-- AddForeignKey
ALTER TABLE "anuncio" ADD CONSTRAINT "fk_anuncio_usuario" FOREIGN KEY ("id_usuario") REFERENCES "usuario"("id_usuario") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "anuncio" ADD CONSTRAINT "fk_anuncio_categoria" FOREIGN KEY ("id_categoria") REFERENCES "categoria"("id_categoria") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "imagem_anuncio" ADD CONSTRAINT "fk_imagem_anuncio" FOREIGN KEY ("id_anuncio") REFERENCES "anuncio"("id_anuncio") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "pedido" ADD CONSTRAINT "fk_pedido_anuncio" FOREIGN KEY ("id_anuncio") REFERENCES "anuncio"("id_anuncio") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "pedido" ADD CONSTRAINT "fk_pedido_comprador" FOREIGN KEY ("id_comprador") REFERENCES "usuario"("id_usuario") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "pedido" ADD CONSTRAINT "fk_pedido_vendedor" FOREIGN KEY ("id_vendedor") REFERENCES "usuario"("id_usuario") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "pagamento" ADD CONSTRAINT "fk_pagamento_pedido" FOREIGN KEY ("id_pedido") REFERENCES "pedido"("id_pedido") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "log_admin" ADD CONSTRAINT "fk_log_admin_usuario" FOREIGN KEY ("id_admin") REFERENCES "usuario"("id_usuario") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "token_usuario" ADD CONSTRAINT "fk_token_usuario" FOREIGN KEY ("id_usuario") REFERENCES "usuario"("id_usuario") ON DELETE NO ACTION ON UPDATE NO ACTION;

