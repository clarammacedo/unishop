-- Cópia da seção 14 do bd.md v0.2 (Unishop). A fonte de verdade é o repositório principal:
-- aplicar DEPOIS da migração 0_init gerada pelo Prisma. Não rodar sozinho em banco vazio.
-- Ainda não testado em banco real (pendência 5 do bd.md).
-- ============================================================
-- Unishop · migração manual · v0.2
-- Aplicar depois da migração 0_init do Prisma · PostgreSQL 18
-- ============================================================
BEGIN;

-- ------------------------------------------------------------
-- 1) USUARIO
-- ------------------------------------------------------------
CREATE UNIQUE INDEX uq_usuario_email_lower ON public.usuario (lower(email));  -- RN-ACE-03

ALTER TABLE public.usuario
  ADD CONSTRAINT ck_usuario_tipo       CHECK (tipo_usuario IN ('aluno', 'admin')),
  ADD CONSTRAINT ck_usuario_status     CHECK (status_conta IN ('ativa', 'suspensa', 'excluida')),
  ADD CONSTRAINT ck_usuario_tentativas CHECK (tentativas_login >= 0),
  ADD CONSTRAINT ck_usuario_credencial CHECK (
        status_conta = 'excluida' OR senha_hash IS NOT NULL OR google_sub IS NOT NULL);

CREATE INDEX ix_usuario_ultimo_acesso ON public.usuario (ultimo_acesso);       -- "logado agora"

-- ------------------------------------------------------------
-- 2) ANUNCIO
-- ------------------------------------------------------------
ALTER TABLE public.anuncio
  ADD CONSTRAINT ck_anuncio_preco      CHECK (preco >= 0.01 AND preco <= 99999.99),   -- RN-ANU-02
  ADD CONSTRAINT ck_anuncio_qtd        CHECK (quantidade >= 0 AND quantidade <= 999), -- RN-EST-05
  ADD CONSTRAINT ck_anuncio_status     CHECK (status IN ('ativo', 'pausado', 'vendido')),
  ADD CONSTRAINT ck_anuncio_contadores CHECK (visualizacoes >= 0 AND contatos >= 0),
  ADD CONSTRAINT ck_anuncio_ativo_com_estoque CHECK (status <> 'ativo' OR quantidade > 0);

CREATE INDEX ix_anuncio_vitrine
  ON public.anuncio (id_categoria, status, data_publicacao DESC)
  WHERE excluido_em IS NULL;
CREATE INDEX ix_anuncio_usuario  ON public.anuncio (id_usuario);               -- "meus anúncios"
CREATE INDEX ix_anuncio_recentes ON public.anuncio (data_publicacao DESC);

-- ------------------------------------------------------------
-- 3) IMAGEM_ANUNCIO
-- ------------------------------------------------------------
ALTER TABLE public.imagem_anuncio
  ADD CONSTRAINT ck_imagem_ordem CHECK (ordem BETWEEN 1 AND 5);                -- RN-ANU-03
CREATE INDEX ix_imagem_anuncio ON public.imagem_anuncio (id_anuncio);

-- ------------------------------------------------------------
-- 4) PEDIDO
-- ------------------------------------------------------------
ALTER TABLE public.pedido
  ADD CONSTRAINT ck_pedido_qtd    CHECK (quantidade > 0),
  ADD CONSTRAINT ck_pedido_preco  CHECK (preco_unitario >= 0),
  ADD CONSTRAINT ck_pedido_valor  CHECK (valor_total >= 0),
  ADD CONSTRAINT ck_pedido_taxa   CHECK (taxa_servico >= 0),
  ADD CONSTRAINT ck_pedido_forma  CHECK (forma_negociacao IN ('pagamento_site', 'whatsapp')),
  ADD CONSTRAINT ck_pedido_status CHECK (status_pedido IN
      ('pendente', 'pago', 'retirada_combinada', 'concluido', 'em_negociacao', 'cancelado'));

-- Um pedido aberto por comprador, anúncio e forma de negociação (RN-PED-10)
CREATE UNIQUE INDEX uq_pedido_aberto
  ON public.pedido (id_comprador, id_anuncio, forma_negociacao)
  WHERE status_pedido IN ('pendente', 'em_negociacao');

CREATE INDEX ix_pedido_comprador ON public.pedido (id_comprador, data_pedido DESC);
CREATE INDEX ix_pedido_vendedor  ON public.pedido (id_vendedor, data_pedido DESC);
CREATE INDEX ix_pedido_anuncio   ON public.pedido (id_anuncio, data_pedido DESC);
CREATE INDEX ix_pedido_status    ON public.pedido (status_pedido, data_pedido);  -- jobs de expiração

-- ------------------------------------------------------------
-- 5) PAGAMENTO
-- ------------------------------------------------------------
ALTER TABLE public.pagamento
  ADD CONSTRAINT ck_pagamento_forma  CHECK (forma_pagamento IN ('pix', 'cartao')),
  ADD CONSTRAINT ck_pagamento_status CHECK (status_pagamento IN
      ('pendente', 'aprovado', 'recusado', 'expirado', 'estorno_pendente', 'estornado')),
  ADD CONSTRAINT ck_pagamento_valor  CHECK (valor IS NULL OR valor >= 0),
  ADD CONSTRAINT ck_pagamento_estorno CHECK (tentativas_estorno >= 0);

-- No máximo uma cobrança em andamento por pedido; tentativas recusadas ficam no histórico
CREATE UNIQUE INDEX uq_pagamento_ativo
  ON public.pagamento (id_pedido)
  WHERE status_pagamento IN ('pendente', 'aprovado');

-- O webhook localiza o pagamento pelo ID do gateway
CREATE UNIQUE INDEX uq_pagamento_transacao
  ON public.pagamento (id_transacao_gateway)
  WHERE id_transacao_gateway IS NOT NULL;

CREATE INDEX ix_pagamento_pedido    ON public.pagamento (id_pedido);
CREATE INDEX ix_pagamento_pendentes ON public.pagamento (data_expiracao)
  WHERE status_pagamento = 'pendente';                                         -- job de Pix vencido
CREATE INDEX ix_pagamento_estorno   ON public.pagamento (status_pagamento)
  WHERE status_pagamento = 'estorno_pendente';                                 -- job de estorno

-- ------------------------------------------------------------
-- 6) LOG_ADMIN
-- ------------------------------------------------------------
ALTER TABLE public.log_admin
  ADD CONSTRAINT ck_log_entidade CHECK (entidade IN ('usuario', 'anuncio'));
CREATE INDEX ix_log_admin_admin    ON public.log_admin (id_admin, data_acao DESC);
CREATE INDEX ix_log_admin_entidade ON public.log_admin (entidade, id_entidade);

-- ------------------------------------------------------------
-- 7) TOKEN_USUARIO
-- ------------------------------------------------------------
ALTER TABLE public.token_usuario
  ADD CONSTRAINT ck_token_tipo CHECK (tipo IN
      ('confirmacao_email', 'redefinicao_senha', 'troca_email'));
CREATE INDEX ix_token_usuario ON public.token_usuario (id_usuario, tipo);
CREATE INDEX ix_token_expira  ON public.token_usuario (expira_em);             -- job de limpeza

-- ------------------------------------------------------------
-- 8) VIEW de visibilidade (filtro único da vitrine, RN-ANU-05)
-- ------------------------------------------------------------
CREATE VIEW public.anuncio_visivel AS
SELECT a.*
FROM public.anuncio a
JOIN public.usuario u ON u.id_usuario = a.id_usuario
WHERE a.status = 'ativo'
  AND a.excluido_em IS NULL
  AND u.status_conta = 'ativa';

COMMIT;
