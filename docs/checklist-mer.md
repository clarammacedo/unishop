# Checklist: atualizar o MER (`mer_unishop.drawio`)

Fonte: `docs/bd.md`, seção 12 (divergências) e seção 4 (dicionário de dados). **O banco está certo; o MER é que muda.** Marque cada item ao concluir.

- [ ] 1. `pedido`: trocar `forma_pagamento` por `forma_negociacao` (`pagamento_site` ou `whatsapp`).
- [ ] 2. `log_admin`: corrigir `id_amin` para `id_admin`.
- [ ] 3. Legenda dos tipos das PKs: `integer GENERATED ALWAYS AS IDENTITY` (no lugar de `INT` / `SERIAL`).
- [ ] 4. `pagamento.id_pedido`: FK **sem** UNIQUE; relação 1 : N (várias tentativas), com no máximo uma cobrança `pendente` ou `aprovado` por pedido (índice `uq_pagamento_ativo`).
- [ ] 5. `pedido.id_anuncio`: FK comum, sem sublinhado de chave.
- [ ] 6. Estados: acrescentar os `CHECK` (valores em `bd.md` seção 6).
- [ ] 7. Colunas novas da v0.2, conforme `bd.md` seção 4:
  - [ ] `usuario`: `google_sub`, `data_aceite_termos`, `tentativas_login`, `bloqueado_ate`, `senha_alterada_em`; `senha_hash` anulável.
  - [ ] `anuncio`: `quantidade`, `whatsapp`, `excluido_em`, `vendido_em`, `visualizacoes`, `contatos`.
  - [ ] `imagem_anuncio`: `public_id`, `ordem`.
  - [ ] `pedido`: `id_pedido` próprio, `id_vendedor`, `nome_produto`, `imagem_url`, `quantidade`, `preco_unitario`, `taxa_servico`, `concluido_em`, `atualizado_em`.
  - [ ] `pagamento`: `data_expiracao`, `chave_idempotencia`, `tentativas_estorno`, `ultimo_erro`, `data_criacao`.
  - [ ] `log_admin`: `detalhes` (jsonb).
  - [ ] Tabela nova `token_usuario` (8ª tabela), com FK para `usuario`.
- [ ] 8. Datas: `timestamptz` em todas as colunas de data.
- [ ] 9. Conferir as 8 entidades e as 9 chaves estrangeiras (`bd.md` seção 5) contra o desenho.

Ao terminar, exportar uma imagem do MER (opcional) e avisar o Pedro para atualizar o `docs/mer_unishop.drawio` no repositório principal, se ele existir lá.
