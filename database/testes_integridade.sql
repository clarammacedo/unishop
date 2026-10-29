-- Testes de integridade do Unishop (bd.md §14, "Testes rápidos de integridade").
-- Rodar DEPOIS de 0_init.sql e migracao_manual_v0.2.sql, em banco de desenvolvimento.
-- Tudo roda dentro de uma transação que termina em ROLLBACK: o banco não é alterado.
-- Resultado: cada teste dá NOTICE "OK ..." quando o banco recusa o dado, e
-- EXCEPTION "FALHOU ..." quando o banco aceita o que deveria recusar.
BEGIN;

-- Roda um comando que DEVE falhar e confere a constraint que o recusou
CREATE FUNCTION pg_temp.deve_falhar(descricao text, comando text, constraint_esperada text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  achada text;
BEGIN
  BEGIN
    EXECUTE comando;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS achada = CONSTRAINT_NAME;
    IF constraint_esperada IS NOT NULL AND achada IS DISTINCT FROM constraint_esperada
       AND achada NOT LIKE constraint_esperada THEN
      RAISE EXCEPTION 'FALHOU: % (esperava %, veio %: %)', descricao, constraint_esperada, achada, SQLERRM;
    END IF;
    RAISE NOTICE 'OK   % -> %', descricao, achada;
    RETURN;
  END;
  RAISE EXCEPTION 'FALHOU: % (o banco aceitou o dado)', descricao;
END $$;

-- Dados mínimos para os testes (id automático; sem OVERRIDING SYSTEM VALUE)
INSERT INTO public.categoria (nome) VALUES ('Categoria de teste');
INSERT INTO public.usuario (nome, email, senha_hash) VALUES ('Ana Teste', 'ana@edu.unifor.br', 'x');
INSERT INTO public.anuncio (nome, descricao, preco, quantidade, whatsapp, id_usuario, id_categoria)
  SELECT 'Livro', 'descricao de teste', 10.00, 5, '85999999999', u.id_usuario, c.id_categoria
  FROM public.usuario u, public.categoria c;
INSERT INTO public.pedido (id_anuncio, id_comprador, id_vendedor, forma_negociacao, nome_produto,
                           quantidade, preco_unitario, valor_total)
  SELECT a.id_anuncio, a.id_usuario, a.id_usuario, 'pagamento_site', 'Livro', 1, 10.00, 10.00
  FROM public.anuncio a;

-- Identity: o id é gerado sempre pelo banco (GENERATED ALWAYS)
SELECT pg_temp.deve_falhar('id manual em usuario', $t$
  INSERT INTO public.usuario (id_usuario, nome, email, senha_hash) VALUES (999, 'X', 'x@edu.unifor.br', 'x')$t$, NULL);

-- Anúncio
SELECT pg_temp.deve_falhar('preco negativo', $t$
  INSERT INTO public.anuncio (nome, descricao, preco, quantidade, whatsapp, id_usuario, id_categoria)
  SELECT 'teste', 'descricao de teste', -5, 1, '85999999999', id_usuario, 1 FROM public.usuario$t$, 'ck_anuncio_preco');
SELECT pg_temp.deve_falhar('quantidade negativa', $t$
  UPDATE public.anuncio SET quantidade = -1, status = 'pausado'$t$, 'ck_anuncio_qtd');
SELECT pg_temp.deve_falhar('anuncio ativo sem estoque', $t$
  UPDATE public.anuncio SET quantidade = 0 WHERE status = 'ativo'$t$, 'ck_anuncio_ativo_com_estoque');
SELECT pg_temp.deve_falhar('status de anuncio invalido', $t$
  UPDATE public.anuncio SET status = 'qualquer_coisa'$t$, 'ck_anuncio_status');

-- Imagem
SELECT pg_temp.deve_falhar('imagem com ordem 6', $t$
  INSERT INTO public.imagem_anuncio (id_anuncio, url_imagem, public_id, ordem)
  SELECT id_anuncio, 'https://x/y.jpg', 'y', 6 FROM public.anuncio$t$, 'ck_imagem_ordem');

-- Pedido
SELECT pg_temp.deve_falhar('status de pedido invalido', $t$
  UPDATE public.pedido SET status_pedido = 'qualquer_coisa'$t$, 'ck_pedido_status');
SELECT pg_temp.deve_falhar('forma de negociacao invalida', $t$
  UPDATE public.pedido SET forma_negociacao = 'fiado'$t$, 'ck_pedido_forma');
SELECT pg_temp.deve_falhar('quantidade zero no pedido', $t$
  UPDATE public.pedido SET quantidade = 0$t$, 'ck_pedido_qtd');
SELECT pg_temp.deve_falhar('dois pedidos abertos do mesmo comprador, anuncio e forma', $t$
  INSERT INTO public.pedido (id_anuncio, id_comprador, id_vendedor, forma_negociacao, status_pedido,
                             nome_produto, quantidade, preco_unitario, valor_total)
  SELECT id_anuncio, id_comprador, id_vendedor, forma_negociacao, 'pendente', 'Livro', 1, 10, 10
  FROM public.pedido$t$, 'uq_pedido_aberto');

-- Usuário
SELECT pg_temp.deve_falhar('e-mail que so difere em maiusculas', $t$
  INSERT INTO public.usuario (nome, email, senha_hash) VALUES ('Dup', 'ANA@edu.unifor.br', 'x')$t$, 'uq_usuario_email_lower');
SELECT pg_temp.deve_falhar('conta ativa sem senha e sem google', $t$
  INSERT INTO public.usuario (nome, email) VALUES ('Sem credencial', 'sem@edu.unifor.br')$t$, 'ck_usuario_credencial');
SELECT pg_temp.deve_falhar('tipo de usuario invalido', $t$
  UPDATE public.usuario SET tipo_usuario = 'dono'$t$, 'ck_usuario_tipo');

-- Pagamento: a segunda cobrança em andamento do mesmo pedido deve falhar
INSERT INTO public.pagamento (id_pedido, forma_pagamento, status_pagamento)
  SELECT id_pedido, 'pix', 'pendente' FROM public.pedido;
SELECT pg_temp.deve_falhar('duas cobrancas em andamento no mesmo pedido', $t$
  INSERT INTO public.pagamento (id_pedido, forma_pagamento, status_pagamento)
  SELECT id_pedido, 'cartao', 'pendente' FROM public.pedido$t$, 'uq_pagamento_ativo');
SELECT pg_temp.deve_falhar('status de pagamento invalido', $t$
  UPDATE public.pagamento SET status_pagamento = 'qualquer_coisa'$t$, 'ck_pagamento_status');

-- Log e token
SELECT pg_temp.deve_falhar('entidade de log invalida', $t$
  INSERT INTO public.log_admin (id_admin, acao, entidade, id_entidade)
  SELECT id_usuario, 'x', 'pedido', 1 FROM public.usuario$t$, 'ck_log_entidade');
SELECT pg_temp.deve_falhar('tipo de token invalido', $t$
  INSERT INTO public.token_usuario (id_usuario, tipo, token_hash, expira_em)
  SELECT id_usuario, 'magia', 'h', now() FROM public.usuario$t$, 'ck_token_tipo');

-- Sem DELETE em cascata: apagar usuario com anuncio deve ser bloqueado pela FK
SELECT pg_temp.deve_falhar('apagar usuario referenciado por anuncio ou pedido', $t$
  DELETE FROM public.usuario$t$, 'fk\_%');

ROLLBACK;
