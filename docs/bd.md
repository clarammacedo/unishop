<!-- CÓPIA DE APOIO do docs/BancoDeDados/bd.md (v0.2) do repositório principal. Em caso de divergência, vale o do repositório principal. -->

---
title: Documentação Técnica — Banco de Dados
project: Unishop
version: 0.2
date: 2026-10-16
status: vigente com pendências
owners: Ana Clara (banco de dados)
reviewers: Felipe Bessa (backend), Pedro Cândido (API), Francisco Magno (integração front-back)
based_on: MER do Unishop, dump do PostgreSQL de 07/10/2026, Regras de Negócio v0.4, Backend v0.3, API v0.3
related: docs/regras-de-negocio/regras-de-negocio.md, docs/backend/backend.md, docs/api/api.md, docs/frontend/frontend.md, docs/deploy/deploy.md
context: README.md, docs/README.md
pendencias: seção 15
language: pt-BR
---

# Documentação Técnica — Banco de Dados

- Versão 0.2 · 16/10/2026
- SGBD: PostgreSQL 18 (o Neon aceita as versões 14 a 18, e a versão é escolhida na criação do projeto)
- Responsável: Ana Clara · Revisores: Felipe Bessa (backend), Pedro Cândido (API), Francisco Magno (integração front-back)
- Base: MER do Unishop, dump de 07/10/2026, Regras de Negócio v0.4, Backend v0.3 e API v0.3

### Histórico de versões

| Versão | Data | O que mudou |
|---|---|---|
| 0.1 | 15/10/2026 | Dicionário das 7 tabelas do dump, lacunas frente ao Backend v0.2 e script de evolução proposto. |
| 0.2 | 16/10/2026 | O documento passa a descrever o **estado final** do banco (não mais o dump mais um script de ajustes). Todas as lacunas da seção 13 da v0.1 foram incorporadas ao dicionário. Entram: pedido com vendedor, produto, imagem, quantidade, preço unitário e taxa congelados; WhatsApp no anúncio; login com Google (`google_sub`, senha anulável); índice único em `lower(email)`; pagamento com índice único parcial e o estado `estorno_pendente`; datas em `timestamptz`; papéis do banco (`unishop_migrator`, `unishop_app`, `unishop_backup`); caminho único de migração pelo Prisma; limites do Neon (1 GB); nomes das seis categorias. Os nomes de coluna das consultas passam a ser os do banco. Fecha as pendências 1 a 11 da v0.1. |

## 1. Objetivo e escopo

Este documento descreve o banco de dados do Unishop: o que cada tabela guarda, como se relaciona com as outras e como o backend a usa. Fontes:

1. O MER (`mer_unishop.drawio`), o desenho do modelo.
2. O dump do PostgreSQL de 07/10/2026, o banco de desenvolvimento como estava no pgAdmin.
3. Os documentos de Regras de Negócio v0.4, Backend v0.3 e API v0.3, que dizem o que o banco precisa oferecer.

**O que este documento cobre**

- Dicionário de dados das 8 tabelas (7 do dump mais `token_usuario`), no estado final.
- Relacionamentos, chaves, restrições e valores permitidos.
- Como as regras de negócio (`RN-XXX-nn`) se apoiam no banco.
- Divergências entre o MER e o banco, e o caminho de migração.

**O que fica fora**

- Contrato das rotas: `openapi.yaml` e documento de API.
- As regras em si: documento de Regras de Negócio (aqui só se mostra onde o banco as apoia).
- Hospedagem, backup e restauração em produção: documento de Deploy.

> Se houver dúvida de comportamento, vale o que está nas Regras de Negócio. Este documento descreve a estrutura que as sustenta.

## 2. Visão geral do banco

O banco tem **8 tabelas**, todas no schema `public`, com chave primária numérica gerada automaticamente (`GENERATED ALWAYS AS IDENTITY`).

| Tabela | Papel em uma frase | Linhas crescem com... |
|---|---|---|
| `usuario` | Quem usa o sistema: aluno ou administrador | Cadastros |
| `categoria` | As 6 categorias fixas de produto | Quase nunca (seed) |
| `anuncio` | O produto à venda, com preço, estoque e WhatsApp | Anúncios publicados |
| `imagem_anuncio` | As fotos de cada anúncio | Fotos enviadas |
| `pedido` | A compra ou o interesse de um aluno por um anúncio | Compras e contatos |
| `pagamento` | A cobrança (Pix ou cartão) de um pedido | Pedidos pagos no site |
| `log_admin` | Registro das ações do administrador | Ações do admin |
| `token_usuario` | Links de uso único (senha, e-mail) | Recuperações de senha |

### Como as tabelas se agrupam

```text
 ACESSO E PESSOAS        CATÁLOGO                    VENDA                  AUDITORIA
 ┌──────────────┐     ┌────────────────┐        ┌────────────┐
 │   usuario    │────▶│    anuncio     │───────▶│   pedido   │───▶ pagamento
 │ token_usuario│     │ + categoria    │        └─────▲──────┘
 └──────┬───────┘     │ + imagem_anuncio│   (comprador e vendedor são usuario)
        │             └────────────────┘
        └──────────────────────────────────────────────────────────▶ log_admin
```

### Fluxo resumido

1. O aluno se cadastra (ou entra com Google) → linha em `usuario`.
2. Ele publica um produto → linha em `anuncio` (ligada a uma `categoria`) e de 1 a 5 linhas em `imagem_anuncio`.
3. Outro aluno quer comprar → linha em `pedido`, que já guarda o vendedor, o nome do produto, a imagem e o preço do momento.
4. Se pagou pelo site → linha em `pagamento`; o webhook do gateway confirma, o estoque do `anuncio` é descontado e o pedido vira `pago`.
5. Quando o administrador edita, suspende ou exclui algo → linha em `log_admin`.

## 3. Diagrama entidade-relacionamento

Estado final (v0.2), com as 8 tabelas e as colunas principais.

```text
                                  ┌───────────────┐
                                  │   categoria   │
                                  │ id_categoria  │ PK
                                  │ nome          │ UK
                                  └───────┬───────┘
                                          │ 1
                                   possui │
                                          │ N
┌─────────────────────┐ 1   publica  N ┌──┴──────────────────┐ 1   possui  1..5 ┌──────────────────┐
│       usuario       ├───────────────▶│       anuncio       ├────────────────▶│  imagem_anuncio  │
│ id_usuario     PK   │                │ id_anuncio     PK   │                 │ id_imagem   PK   │
│ nome, email    UK*  │                │ nome, descricao     │                 │ id_anuncio  FK   │
│ senha_hash (anul.)  │                │ preco, quantidade   │                 │ url_imagem       │
│ google_sub     UK   │                │ whatsapp, status    │                 │ public_id        │
│ whatsapp, curso     │                │ visualizacoes       │                 │ ordem (1..5)     │
│ foto_perfil         │                │ contatos            │                 └──────────────────┘
│ verificacao         │                │ excluido_em         │
│ tipo_usuario        │                │ vendido_em          │
│ status_conta        │                │ id_usuario     FK   │
│ ultimo_acesso       │                │ id_categoria   FK   │
│ tentativas_login    │                └──────────┬──────────┘
│ bloqueado_ate       │                           │ 1
│ senha_alterada_em   │                     gera  │
│ data_aceite_termos  │                           │ N
└──┬──────┬──────┬────┘            comprador N ┌──┴──────────────────┐ 1   possui  0..N ┌─────────────────────┐
   │      │      └────────────────────────────▶│       pedido        ├────────────────▶│      pagamento      │
   │      │ vendedor N                         │ id_pedido      PK   │                 │ id_pagamento   PK   │
   │      └───────────────────────────────────▶│ id_anuncio     FK   │                 │ id_pedido      FK   │
   │ 1                                          │ id_comprador   FK   │                 │ id_transacao_gateway│
   │ registra (admin)                           │ id_vendedor    FK   │                 │ forma, status       │
   │ N                                          │ nome_produto        │                 │ valor, data_expiracao│
┌──┴──────────────┐                             │ imagem_url          │                 │ chave_idempotencia  │
│    log_admin    │                             │ quantidade          │                 │ tentativas_estorno  │
│ id_log     PK   │                             │ preco_unitario      │                 │ ultimo_erro         │
│ id_admin   FK   │                             │ taxa_servico        │                 └─────────────────────┘
│ acao, entidade  │                             │ valor_total         │
│ id_entidade     │                             │ forma_negociacao    │
│ detalhes jsonb  │                             │ status_pedido       │
│ data_acao       │                             │ data_pedido         │
└─────────────────┘                             │ concluido_em        │
                                                │ atualizado_em       │
┌─────────────────┐ N                1          └─────────────────────┘
│  token_usuario  ├─────────────────▶ usuario
│ id_token   PK   │
│ tipo, token_hash│                      * UK sobre lower(email)
│ expira_em       │
└─────────────────┘
        Figura 1 · Diagrama entidade-relacionamento do banco (estado final, 8 tabelas)
```

### Leitura das cardinalidades

| Relacionamento | Cardinalidade | Significado |
|---|---|---|
| `usuario` → `anuncio` (publica) | 1:N | Um aluno publica vários anúncios; cada anúncio tem um único dono. |
| `categoria` → `anuncio` (possui) | 1:N | Uma categoria agrupa vários anúncios; cada anúncio está em uma só. |
| `anuncio` → `imagem_anuncio` (possui) | 1 : 1..5 | Um anúncio tem de uma a cinco fotos (RN-ANU-03). |
| `anuncio` → `pedido` (gera) | 1:N | Um anúncio pode receber vários pedidos. |
| `usuario` → `pedido` (comprador) | 1:N | Um aluno faz vários pedidos como comprador. |
| `usuario` → `pedido` (vendedor) | 1:N | O vendedor é gravado no pedido, para o histórico não depender do dono atual do anúncio (RN-PED-01). |
| `pedido` → `pagamento` (possui) | 1 : 0..N | Pedido por WhatsApp não tem pagamento. Pedido pelo site tem no máximo **um pagamento em andamento** (pendente ou aprovado) e pode ter tentativas recusadas ou expiradas no histórico. |
| `usuario` → `log_admin` (registra) | 1:N | Um administrador gera vários registros de log. |
| `usuario` → `token_usuario` (recebe) | 1:N | Um usuário pode ter vários links pendentes. |

## 4. Dicionário de dados (tabela por tabela)

Legenda: PK chave primária · FK chave estrangeira · UK valor único · NN `NOT NULL`. A coluna "Origem" cita a regra de negócio que justifica o campo. Todas as colunas de data são `timestamptz` (data e hora com fuso), gravadas em UTC.

### 4.1 usuario

**O que faz.** Guarda todas as pessoas que entram no sistema: alunos (que compram e vendem) e administradores (que moderam). É a tabela central de identidade.

**Como funciona.**

- O cadastro cria uma linha com `tipo_usuario = 'aluno'` e `status_conta = 'ativa'` (valores padrão). A conta de administrador só nasce pelo seed (RN-ADM-11).
- O e-mail é único **sem diferenciar maiúsculas** (índice sobre `lower(email)`, RN-ACE-03) e, para alunos, termina em `@edu.unifor.br` (RN-ACE-02); a checagem de domínio é do backend.
- A senha nunca é guardada em texto: só o hash bcrypt em `senha_hash` (RN-ACE-05). Quem entra por Google nasce **sem senha**: `senha_hash` fica nulo e `google_sub` guarda o identificador da conta Google (RN-ACE-14).
- `verificacao` indica se o e-mail institucional foi confirmado (por link, RN-ACE-07, ou por Google, RN-ACE-14). A conta criada por Google já nasce com `true`. O selo "aluno verificado" vem daqui.
- `ultimo_acesso` é atualizado pelo middleware `trackLastSeen` (no máximo uma vez por minuto). O painel admin mostra "logado agora" quando está nos últimos 5 minutos (RN-ADM-03).
- `tentativas_login` e `bloqueado_ate` sustentam o bloqueio de 15 minutos após 5 erros (RN-ACE-09). `senha_alterada_em` faz o backend recusar tokens emitidos antes da última troca (RN-ACE-11, RN-ACE-15).
- Suspender uma conta (`status_conta = 'suspensa'`) impede o login e oculta os anúncios do dono (RN-ADM-05).
- Excluir o perfil **anonimiza** a linha (seção 10), para os pedidos pagos continuarem no histórico da outra parte (RN-PER-06).

| Coluna | Tipo | Restrições | Descrição | Origem |
|---|---|---|---|---|
| `id_usuario` | integer | PK, NN, identity | Identificador do usuário | — |
| `nome` | varchar(150) | NN | Nome completo (3 a 150 caracteres) | RN-ACE-01 |
| `email` | varchar(150) | NN, UK em `lower(email)` | E-mail institucional (login) | RN-ACE-02, 03 |
| `senha_hash` | varchar(255) | NULL | Hash bcrypt; nulo para conta de Google ou anonimizada | RN-ACE-05, 14 |
| `google_sub` | varchar(64) | NULL, UK | Identificador da conta Google (`sub`) | RN-ACE-14 |
| `whatsapp` | varchar(20) | NULL | Só dígitos (10 ou 11, com DDD) | RN-PER-01, 07 |
| `curso` | varchar(100) | NULL | Curso do aluno | RN-PER-01 |
| `foto_perfil` | varchar(255) | NULL | URL da foto de perfil (Cloudinary) | RN-PER-05 |
| `verificacao` | boolean | NN, padrão `false` | E-mail institucional confirmado? | RN-ACE-07, 14 |
| `tipo_usuario` | varchar(20) | NN, padrão `'aluno'` | Perfil: `aluno` ou `admin` | Regras §3 |
| `status_conta` | varchar(20) | NN, padrão `'ativa'` | Situação da conta (seção 6) | RN-ADM-05, RN-ACE-12 |
| `data_aceite_termos` | timestamptz | NULL | Quando aceitou os Termos de uso | RN-ACE-06 |
| `tentativas_login` | integer | NN, padrão 0 | Senhas erradas seguidas | RN-ACE-09 |
| `bloqueado_ate` | timestamptz | NULL | Fim do bloqueio de login | RN-ACE-09 |
| `senha_alterada_em` | timestamptz | NULL | Última troca de senha | RN-ACE-11, 15 |
| `data_cadastro` | timestamptz | NN, padrão `now()` | Quando se cadastrou ("novos na semana") | RN-ADM-02 |
| `ultimo_acesso` | timestamptz | NULL | Última atividade (`last_seen` no código) | RN-ADM-03 |

Restrições: `usuario_pkey`; `uq_usuario_email_lower` (índice único sobre `lower(email)`); `usuario_google_sub_key` (UNIQUE); `ck_usuario_tipo`, `ck_usuario_status`, `ck_usuario_tentativas`; `ck_usuario_credencial` (conta ativa ou suspensa tem `senha_hash` ou `google_sub`).

### 4.2 categoria

**O que faz.** Lista as categorias em que os produtos são organizados. São seis, fixas (RN-CAT-01): ninguém cria, edita ou exclui categoria pelo sistema.

**Como funciona.**

- As linhas são criadas uma única vez pelo seed (`npm run db:seed`).
- A tela de categorias mostra a quantidade de anúncios ativos (RN-CAT-02). A contagem não é guardada: é calculada com `COUNT`, usando o mesmo filtro de visibilidade das listagens (seção 9.1).
- A busca por texto procura em `categoria.nome` e em `anuncio.nome` (RN-CAT-03).

| Coluna | Tipo | Restrições | Descrição | Origem |
|---|---|---|---|---|
| `id_categoria` | integer | PK, NN, identity | Identificador da categoria | — |
| `nome` | varchar(100) | NN, UK | Nome exibido (não se repete) | RN-CAT-01 |

Restrições: `categoria_pkey`, `categoria_nome_key`. Os seis nomes (Livros e apostilas, Eletrônicos, Alimentos, Materiais de curso, Vestuário, Outros) estão no seed (seção 11).

### 4.3 anuncio

**O que faz.** É o produto à venda. Guarda o que o vendedor escreveu (nome, descrição, preço), o WhatsApp de contato, o estoque, a situação e os contadores de visualização e contato.

**Como funciona.**

- Só aluno cria anúncio (admin recebe 403). Nasce com `status = 'ativo'` e `data_publicacao` automática.
- `quantidade` é o estoque. Ele não é reservado quando alguém inicia um pedido: só cai quando a venda se fecha, de forma atômica (seção 9.2). Chegando a zero, o anúncio passa a `vendido` (RN-EST-06).
- `status` controla a vitrine: só aparece para outros alunos se `ativo` (RN-ANU-05). `pausado` some sem perder dados; `vendido` é final para o dono (só o admin reverte, com log).
- `whatsapp` pertence ao anúncio: nasce com o número do perfil e pode ser editado (RN-ANU-01). Mudar o WhatsApp do perfil atualiza os anúncios **ativos** do aluno (RN-PER-03).
- `visualizacoes` soma +1 a cada abertura da página por quem não é o dono, sem deduplicar (RN-ANU-11). `contatos` soma +1 a cada contato por WhatsApp registrado (RN-ANU-08). O backend mantém os dois.
- A exclusão é **lógica**: `excluido_em` recebe a data, e a linha continua para os pedidos pagos permanecerem no histórico (RN-ANU-09).

| Coluna | Tipo | Restrições | Descrição | Origem |
|---|---|---|---|---|
| `id_anuncio` | integer | PK, NN, identity | Identificador do anúncio | — |
| `nome` | varchar(150) | NN | Título do produto (3 a 150) | RN-ANU-01, 12 |
| `descricao` | text | NN | Descrição (10 a 2.000 caracteres, validado no backend) | RN-ANU-01, 12 |
| `preco` | numeric(10,2) | NN | Preço unitário, de 0,01 a 99.999,99 | RN-ANU-02 |
| `quantidade` | integer | NN, padrão 1 | Unidades em estoque, de 0 a 999 | RN-EST-01, 05 |
| `whatsapp` | varchar(20) | NN | Contato do anúncio, só dígitos | RN-ANU-01, RN-PER-07 |
| `status` | varchar(20) | NN, padrão `'ativo'` | `ativo`, `pausado` ou `vendido` (seção 6) | RN-ANU-04, 05 |
| `data_publicacao` | timestamptz | NN, padrão `now()` | Quando foi publicado | RN-ANU-07 |
| `visualizacoes` | integer | NN, padrão 0 | Contador de visualizações | RN-ANU-08, 11 |
| `contatos` | integer | NN, padrão 0 | Contador de contatos por WhatsApp | RN-ANU-08 |
| `excluido_em` | timestamptz | NULL | Preenchido = excluído (exclusão lógica) | RN-ANU-09 |
| `vendido_em` | timestamptz | NULL | Quando passou a `vendido` | RN-EST-06 |
| `id_usuario` | integer | FK → `usuario`, NN | Dono (vendedor) | RN-ANU-04 |
| `id_categoria` | integer | FK → `categoria`, NN | Categoria do produto | RN-ANU-01 |

Restrições: `anuncio_pkey`, `fk_anuncio_usuario`, `fk_anuncio_categoria`; `ck_anuncio_preco`, `ck_anuncio_qtd`, `ck_anuncio_status`, `ck_anuncio_contadores`; `ck_anuncio_ativo_com_estoque` (`status <> 'ativo' OR quantidade > 0`).

### 4.4 imagem_anuncio

**O que faz.** Guarda as fotos de cada anúncio. O arquivo fica na Cloudinary; o banco guarda o endereço (URL), o `public_id` para apagar o arquivo e a posição na galeria.

**Como funciona.**

- Todo anúncio tem de 1 a 5 imagens (RN-ANU-03). O mínimo é garantido pelo backend: o anúncio e a **primeira** imagem são gravados na mesma operação (`POST /listings`), e as demais entram uma por requisição (`POST /listings/:id/images`). O máximo de 5 é garantido também pelo banco (`ordem` de 1 a 5, única por anúncio).
- `ordem` define a galeria (1 = foto principal, usada na miniatura da listagem).
- Formatos: JPG e PNG, até **4 MB** por imagem (validado no upload, não no banco).
- Ao excluir uma imagem, o backend apaga o arquivo da Cloudinary pelo `public_id`. A imagem principal do **pedido** é uma cópia da URL (`pedido.imagem_url`), então sobrevive à exclusão.

| Coluna | Tipo | Restrições | Descrição | Origem |
|---|---|---|---|---|
| `id_imagem` | integer | PK, NN, identity | Identificador da imagem | — |
| `id_anuncio` | integer | FK → `anuncio`, NN | Anúncio a que a foto pertence | RN-ANU-03 |
| `url_imagem` | varchar(255) | NN | URL segura da imagem (CDN) | RNF009 |
| `public_id` | varchar(255) | NN | Identificador na Cloudinary | RN-ANU-03 |
| `ordem` | integer | NN | Posição na galeria (1 a 5) | RF008 |

Restrições: `imagem_anuncio_pkey`, `fk_imagem_anuncio`, `uq_imagem_ordem` (UNIQUE `id_anuncio, ordem`), `ck_imagem_ordem` (`ordem BETWEEN 1 AND 5`).

### 4.5 pedido

**O que faz.** Representa a compra ou o interesse de um aluno por um anúncio. É o elo entre comprador, vendedor, anúncio e (quando há) pagamento, e carrega a linha do tempo da venda no `status_pedido`.

**Como funciona.** Existem dois caminhos, escolhidos em `forma_negociacao`:

| Caminho | Como começa | Passa por pagamento? | Estoque cai quando... |
|---|---|---|---|
| Pagamento no site | "Seguir para o pagamento" → `pendente` | Sim (tabela `pagamento`) | O webhook confirma o pagamento |
| Contato por WhatsApp | "Entrar em contato" → `em_negociacao` | Não | O vendedor conclui a venda |

- O comprador é `id_comprador`; o vendedor é `id_vendedor`, **gravado no pedido** no momento da compra (RN-PED-01). O dono não pede o próprio anúncio (RN-ANU-10) e o admin não faz pedido; ambas as checagens são do backend.
- O pedido **congela** `nome_produto`, `imagem_url`, `quantidade`, `preco_unitario` e `taxa_servico`. Mudar o anúncio, trocar o dono ou apagar a imagem depois não altera o pedido.
- `valor_total = preco_unitario × quantidade + taxa_servico`, calculado só no backend (RN-PED-02). A taxa é R$ 0,00.
- Cada comprador tem **um pedido aberto por anúncio e forma de negociação** (índice único parcial `uq_pedido_aberto`, RN-PED-10).
- `concluido_em` guarda quando o pedido foi concluído. `atualizado_em` marca a última mudança e serve aos jobs de expiração (pedido pendente há mais de 30 minutos, RN-PAG-12).
- O padrão `'em_negociacao'` da coluna só serve ao caminho do WhatsApp; no caminho do site o backend informa `'pendente'`.

| Coluna | Tipo | Restrições | Descrição | Origem |
|---|---|---|---|---|
| `id_pedido` | integer | PK, NN, identity | Número do pedido | RN-PED-03 |
| `id_anuncio` | integer | FK → `anuncio`, NN | Anúncio comprado | RN-PED-01 |
| `id_comprador` | integer | FK → `usuario`, NN | Aluno que comprou | RN-PED-01 |
| `id_vendedor` | integer | FK → `usuario`, NN | Vendedor no momento da compra | RN-PED-01 |
| `forma_negociacao` | varchar(20) | NN | `pagamento_site` ou `whatsapp` | RN-PED-05 |
| `status_pedido` | varchar(20) | NN, padrão `'em_negociacao'` | Situação do pedido (seção 6) | Regras §4 |
| `nome_produto` | varchar(150) | NN | Nome do produto no momento da compra | RN-PED-01 |
| `imagem_url` | varchar(255) | NULL | Imagem principal no momento da compra | RN-PED-01 |
| `quantidade` | integer | NN | Unidades pedidas (> 0) | RN-EST-02 |
| `preco_unitario` | numeric(10,2) | NN | Preço de cada unidade na compra | RN-PED-01 |
| `taxa_servico` | numeric(10,2) | NN, padrão 0 | Taxa de serviço (R$ 0,00 hoje) | RN-PED-02 |
| `valor_total` | numeric(10,2) | NN | Total cobrado | RN-PED-02 |
| `data_pedido` | timestamptz | NN, padrão `now()` | Quando foi criado | RN-PED-06 |
| `concluido_em` | timestamptz | NULL | Quando foi concluído | RN-PED-08 |
| `atualizado_em` | timestamptz | NN, padrão `now()` | Última mudança | RN-PAG-12 |

Restrições: `pedido_pkey`, `fk_pedido_anuncio`, `fk_pedido_comprador`, `fk_pedido_vendedor`; `ck_pedido_qtd`, `ck_pedido_valor`, `ck_pedido_taxa`, `ck_pedido_forma`, `ck_pedido_status`; `uq_pedido_aberto` (índice único parcial).

> **Preenchimento em dois passos.** O backend cria o pedido já com todos os campos congelados, lendo o anúncio na mesma transação. Em manutenção, se algum dia houver linhas antigas sem `preco_unitario`, preencher com `anuncio.preco` antes de exigir `NOT NULL` (ver seção 11).

### 4.6 pagamento

**O que faz.** Guarda a cobrança de um pedido feito pelo site: a forma (Pix ou cartão), o código da transação no gateway (Mercado Pago), o estado e quando foi paga.

**Como funciona.**

- O Unishop não guarda dado de cartão (RN-PAG-02): só o `id_transacao_gateway`.
- Nasce `pendente` quando o Pix é gerado (expira em 30 minutos, `data_expiracao`) ou quando o cartão é cobrado.
- Quem confirma é o webhook assinado do gateway (RN-PAG-05): o backend recebe o aviso, consulta o pagamento de volta e só então marca `aprovado` e muda o pedido para `pago`.
- É idempotente: o mesmo aviso duas vezes não duplica nada (RN-PAG-06), porque o backend trava o pedido e confere o status antes de agir.
- **Várias tentativas por pedido.** Uma nova tentativa depois de uma recusa **cria outra linha**, e o histórico fica guardado. O que o banco impede é ter duas cobranças em andamento: o índice único parcial `uq_pagamento_ativo` permite no máximo uma linha `pendente` ou `aprovado` por pedido.
- `chave_idempotencia` vai ao gateway na cobrança e no estorno. Ela inclui o **número da tentativa**, para uma nova tentativa não repetir a chave da anterior.
- Estorno: o pagamento aprovado cujo pedido não pode ser honrado (sem estoque, anúncio inativo, pagamento tardio em pedido cancelado; RN-PAG-08, 13, 14) vai para `estorno_pendente`. O job de estorno chama o gateway e marca `estornado`; falhas incrementam `tentativas_estorno` e gravam `ultimo_erro`.
- A tela só mostra "pago" quando o pedido está `pago` no banco (RN-PAG-11).

| Coluna | Tipo | Restrições | Descrição | Origem |
|---|---|---|---|---|
| `id_pagamento` | integer | PK, NN, identity | Identificador do pagamento | — |
| `id_pedido` | integer | FK → `pedido`, NN | Pedido cobrado | RN-PAG-01 |
| `id_transacao_gateway` | varchar(255) | NULL, UK parcial | ID do pagamento no Mercado Pago | RN-PAG-05 |
| `forma_pagamento` | varchar(20) | NN | `pix` ou `cartao` | RN-PAG-01 |
| `status_pagamento` | varchar(20) | NN | Estado da cobrança (seção 6) | RN-PAG-04, 07, 08 |
| `data_pagamento` | timestamptz | NULL | Quando foi aprovado | RN-PAG-05 |
| `valor` | numeric(10,2) | NULL | Valor cobrado | RN-PED-02 |
| `data_expiracao` | timestamptz | NULL | Fim da validade do Pix | RN-PAG-04 |
| `chave_idempotencia` | varchar(100) | NULL, UK | Chave de idempotência (inclui a tentativa) | API §4.3 |
| `tentativas_estorno` | integer | NN, padrão 0 | Tentativas de estorno já feitas | RN-PAG-08 |
| `ultimo_erro` | text | NULL | Último erro do gateway (sem dado sensível) | RN-PAG-08 |
| `data_criacao` | timestamptz | NN, padrão `now()` | Quando a tentativa foi criada | RN-PAG-12 |

Restrições: `pagamento_pkey`, `fk_pagamento_pedido`, `uq_pagamento_idempotencia`, `uq_pagamento_transacao` (índice único parcial), `uq_pagamento_ativo` (índice único parcial); `ck_pagamento_forma`, `ck_pagamento_status`, `ck_pagamento_valor`.

### 4.7 log_admin

**O que faz.** É o diário de auditoria do administrador: quem fez o quê, em qual item e quando (RN-ADM-10).

**Como funciona.**

- Só o backend grava, na mesma transação da ação do admin: sem log, sem ação.
- É de leitura e inserção: registros não são editados nem apagados.
- `entidade` + `id_entidade` apontam o item afetado de forma genérica (`'usuario'` + 7, `'anuncio'` + 42). Não há chave estrangeira em `id_entidade`, de propósito: o log precisa sobreviver à exclusão do alvo.
- `acao` descreve o que foi feito (`editar_usuario`, `suspender_usuario`, `reativar_usuario`, `excluir_usuario`, `editar_anuncio`, `reverter_vendido`, `excluir_anuncio`).
- `detalhes` guarda o resumo da mudança (campos antes e depois), sem senha, token nem dado de cartão.

| Coluna | Tipo | Restrições | Descrição | Origem |
|---|---|---|---|---|
| `id_log` | integer | PK, NN, identity | Identificador do registro | — |
| `id_admin` | integer | FK → `usuario`, NN | Administrador responsável | RN-ADM-10 |
| `acao` | varchar(50) | NN | O que foi feito | RN-ADM-10 |
| `entidade` | varchar(20) | NN | `usuario` ou `anuncio` | RN-ADM-10 |
| `id_entidade` | integer | NN | Id do alvo (sem FK) | RN-ADM-10 |
| `detalhes` | jsonb | NULL | Resumo da mudança (antes e depois) | RN-ADM-10 |
| `data_acao` | timestamptz | NN, padrão `now()` | Quando ocorreu | RN-ADM-10 |

Restrições: `log_admin_pkey`, `fk_log_admin_usuario`, `ck_log_entidade`.

### 4.8 token_usuario

**O que faz.** Guarda os links de uso único: redefinição de senha, troca de e-mail e, quando a chave estiver ligada, confirmação de e-mail (RN-ACE-07, 10; RN-PER-02).

**Como funciona.**

- Só o **hash** do token é guardado (`token_hash`); o valor em claro vai apenas no e-mail.
- `expira_em` define a validade (30 minutos para a redefinição) e `usado_em` marca o uso. Um token usado ou vencido é recusado.
- `novo_email` só é usado na troca de e-mail.
- Um job apaga os tokens vencidos.

| Coluna | Tipo | Restrições | Descrição | Origem |
|---|---|---|---|---|
| `id_token` | integer | PK, NN, identity | Identificador do token | — |
| `id_usuario` | integer | FK → `usuario`, NN | Dono do token | RN-ACE-10 |
| `tipo` | varchar(30) | NN | `confirmacao_email`, `redefinicao_senha` ou `troca_email` | RN-ACE-07, 10, RN-PER-02 |
| `token_hash` | varchar(255) | NN, UK | Hash do token | RN-ACE-10 |
| `novo_email` | varchar(150) | NULL | Novo e-mail (só na troca) | RN-PER-02 |
| `expira_em` | timestamptz | NN | Fim da validade | RN-ACE-10 |
| `usado_em` | timestamptz | NULL | Quando foi usado | RN-ACE-10 |
| `criado_em` | timestamptz | NN, padrão `now()` | Quando foi criado | — |

Restrições: `token_usuario_pkey`, `fk_token_usuario`, `uq_token_hash`, `ck_token_tipo`.

## 5. Relacionamentos e integridade

### Chaves estrangeiras

| Constraint | De (filha) | Para (pai) | Efeito ao excluir o pai |
|---|---|---|---|
| `fk_anuncio_usuario` | `anuncio.id_usuario` | `usuario.id_usuario` | Bloqueia (`NO ACTION`) |
| `fk_anuncio_categoria` | `anuncio.id_categoria` | `categoria.id_categoria` | Bloqueia |
| `fk_imagem_anuncio` | `imagem_anuncio.id_anuncio` | `anuncio.id_anuncio` | Bloqueia |
| `fk_pedido_anuncio` | `pedido.id_anuncio` | `anuncio.id_anuncio` | Bloqueia |
| `fk_pedido_comprador` | `pedido.id_comprador` | `usuario.id_usuario` | Bloqueia |
| `fk_pedido_vendedor` | `pedido.id_vendedor` | `usuario.id_usuario` | Bloqueia |
| `fk_pagamento_pedido` | `pagamento.id_pedido` | `pedido.id_pedido` | Bloqueia |
| `fk_log_admin_usuario` | `log_admin.id_admin` | `usuario.id_usuario` | Bloqueia |
| `fk_token_usuario` | `token_usuario.id_usuario` | `usuario.id_usuario` | Bloqueia |

Nenhuma FK declara `ON DELETE`, então o PostgreSQL usa `NO ACTION`: não se apaga um registro que ainda é referenciado. Isso combina com a estratégia do Unishop de não apagar fisicamente: anúncio é excluído de forma lógica e usuário é anonimizado (seções 4.3 e 10). `DELETE` físico em `usuario` ou `anuncio` é exceção de manutenção, não operação normal.

### Restrições de unicidade

| Constraint | Coluna(s) | Regra que protege |
|---|---|---|
| `uq_usuario_email_lower` | `lower(usuario.email)` | E-mail único, sem diferenciar maiúsculas (RN-ACE-03) |
| `usuario_google_sub_key` | `usuario.google_sub` | Uma conta Unishop por conta Google |
| `categoria_nome_key` | `categoria.nome` | Sem categoria duplicada |
| `uq_imagem_ordem` | `imagem_anuncio(id_anuncio, ordem)` | Sem duas fotos na mesma posição |
| `uq_pedido_aberto` | `pedido(id_comprador, id_anuncio, forma_negociacao)` onde `status_pedido` em (`pendente`, `em_negociacao`) | Um pedido aberto por comprador, anúncio e forma (RN-PED-10) |
| `uq_pagamento_ativo` | `pagamento(id_pedido)` onde `status_pagamento` em (`pendente`, `aprovado`) | Uma cobrança em andamento por pedido |
| `uq_pagamento_transacao` | `pagamento(id_transacao_gateway)` onde não nulo | Webhook acha o pagamento sem ambiguidade |
| `uq_pagamento_idempotencia` | `pagamento.chave_idempotencia` | Sem cobrança duplicada |
| `uq_token_hash` | `token_usuario.token_hash` | Token único |

### Ordem de criação das tabelas

```text
1. usuario        2. categoria
        └────────┬───────┘
3. anuncio        (usuario, categoria)
4. imagem_anuncio (anuncio)
5. pedido         (anuncio, usuario)
6. pagamento      (pedido)
7. log_admin      (usuario)
8. token_usuario  (usuario)
```

Para apagar tudo (só em desenvolvimento), use a ordem inversa, ou `prisma migrate reset`.

## 6. Valores fixos (estados) de cada coluna

Os campos abaixo são `varchar` com `CHECK` (seção 14): qualquer texto fora da lista é recusado pelo banco. Os valores ficam **em português**, e o backend usa os mesmos nomes (enum do Prisma com `@map`). Há um valor por estado no banco; os textos exibidos ao usuário (por exemplo, "Pago · aguardando retirada" para o comprador e "Pago · combinar retirada" para o vendedor) ficam na interface.

### usuario.tipo_usuario

| Valor | Significado |
|---|---|
| `aluno` | Compra, anuncia e edita o próprio perfil (padrão) |
| `admin` | Gerencia usuários e produtos; não compra, não paga e não anuncia. Só criado por seed |

### usuario.status_conta

| Valor | Significado | Como entra e sai |
|---|---|---|
| `ativa` | Pode entrar e usar o sistema (padrão) | Cadastro ou reativação pelo admin |
| `suspensa` | Não entra; anúncios ocultos, dados preservados | Admin suspende ou reativa (RN-ADM-05) |
| `excluida` | Conta anonimizada (nome "Usuário removido") | Usuário ou admin exclui (RN-PER-06, RN-ADM-06) |

> "Bloqueada por 15 min" (5 senhas erradas, RN-ACE-09) e "e-mail não confirmado" (RN-ACE-07) são situações temporárias. O bloqueio usa `bloqueado_ate` e a confirmação usa `verificacao`; nenhum deles cria valor novo em `status_conta`.

### anuncio.status

| Valor | Significado | Visível na vitrine? |
|---|---|---|
| `ativo` | À venda (padrão) | Sim |
| `pausado` | Escondido pelo dono ou admin; mantém dados e unidades | Não |
| `vendido` | Estoque zerou ou o dono marcou como vendido; só o admin reverte | Não |

"Excluído" não é status: é exclusão lógica pela coluna `excluido_em`.

### pedido.forma_negociacao

| Valor | Significado |
|---|---|
| `pagamento_site` | Pedido pago por Pix ou cartão dentro do Unishop |
| `whatsapp` | Contato com o vendedor pelo WhatsApp; sem pagamento no site |

### pedido.status_pedido

| Valor | Significado | Caminho |
|---|---|---|
| `pendente` | Aguardando pagamento | Site |
| `pago` | Pagamento confirmado e estoque descontado | Site |
| `retirada_combinada` | Vendedor marcou o encontro | Site |
| `concluido` | Produto entregue (comprador confirmou ou vendedor concluiu o WhatsApp) | Ambos |
| `em_negociacao` | Contato por WhatsApp registrado (padrão do banco) | WhatsApp |
| `cancelado` | Encerrado sem venda (Pix expirou, 30 min sem pagar, comprador cancelou, vendedor encerrou, sem estoque ou anúncio inativo, com estorno) | Ambos |

```text
SITE:      pendente ─▶ pago ─▶ retirada_combinada ─▶ concluido
           pendente ─▶ cancelado   (Pix expirou, 30 min sem pagar, comprador cancelou)
           pendente ─▶ cancelado   (pagamento aprovado, mas sem estoque ou anúncio inativo: estorno)

WHATSAPP:  em_negociacao ─▶ concluido   (vendedor confirma a venda e desconta o estoque)
           em_negociacao ─▶ cancelado   (vendedor encerra ou comprador cancela)
```

Um pedido `cancelado` nunca volta a `pendente`.

### pagamento.forma_pagamento

| Valor | Significado |
|---|---|
| `pix` | QR Code e copia e cola, válido por 30 minutos |
| `cartao` | Cobrança por token gerado no navegador |

### pagamento.status_pagamento

| Valor | Status no Mercado Pago | Efeito no pedido |
|---|---|---|
| `pendente` | `pending`, `in_process` | Nenhum |
| `aprovado` | `approved` | Liquidação: desconta estoque e marca `pago` (RN-PAG-14) |
| `recusado` | `rejected` | Pedido segue `pendente`; o aluno tenta de novo (nova linha) |
| `expirado` | `cancelled` ou Pix vencido | Pedido `cancelado` (RN-PAG-04) |
| `estorno_pendente` | `approved`, mas o pedido não pode ser honrado | Pedido `cancelado`; o job de estorno chama o gateway |
| `estornado` | `refunded` | Estorno concluído |

### log_admin.entidade

| Valor | Alvo |
|---|---|
| `usuario` | Conta de usuário |
| `anuncio` | Produto/anúncio |

### token_usuario.tipo

| Valor | Uso |
|---|---|
| `confirmacao_email` | Confirmar o e-mail institucional (chave de RN-ACE-07 ligada) |
| `redefinicao_senha` | Recuperar a senha (30 minutos) |
| `troca_email` | Confirmar o novo e-mail do perfil (RN-PER-02) |

## 7. Convenções e mapeamento para o backend

### Convenções do banco

- Tabelas e colunas em português, minúsculas, `snake_case` (`id_anuncio`, `data_publicacao`).
- Tabelas no singular (`usuario`, `pedido`).
- Chave primária `id_<tabela>`; chave estrangeira com o mesmo nome da PK que referencia (exceções que carregam o papel: `id_comprador`, `id_vendedor` e `id_admin`, que apontam para `usuario`).
- Chaves geradas por `GENERATED ALWAYS AS IDENTITY`. Para inserir um id manual (por exemplo, em um seed), é preciso `OVERRIDING SYSTEM VALUE`.
- Dinheiro em `numeric(10,2)` (nunca `float`); o backend calcula em centavos inteiros e converte ao gravar.
- Datas em `timestamptz`, gravadas em UTC.
- Constraints com nome padronizado: `fk_<filha>_<pai>`, `<tabela>_pkey`, `ck_<tabela>_<regra>`, `uq_<tabela>_<regra>`, `ix_<tabela>_<uso>`.

### Mapeamento banco × nomes usados no Backend

O backend escreve o código em inglês e o banco está em português. O Prisma resolve com `@map` e `@@map`, sem renomear nada no banco. Esta é a referência dessa correspondência:

| Banco | Backend | Banco | Backend |
|---|---|---|---|
| `usuario` | `user` | `anuncio.quantidade` | `listing.quantity` |
| `anuncio` | `listing` | `anuncio.preco` | `listing.price` |
| `categoria` | `category` | `anuncio.excluido_em` | `listing.deletedAt` |
| `pedido` | `order` | `usuario.ultimo_acesso` | `user.lastSeen` |
| `pagamento` | `payment` | `usuario.google_sub` | `user.googleSub` |
| `imagem_anuncio` | `listingImage` | `pedido.valor_total` | `order.totalAmount` |
| `log_admin` | `auditLog` | `pedido.preco_unitario` | `order.unitPrice` |
| `token_usuario` | `userToken` | `usuario.tipo_usuario` | `user.role` (`aluno` → `student`) |

> Os **valores** dos estados são os mesmos nos dois lados (`pago`, `concluido`, `em_negociacao`...). Se o enum do Prisma usar nomes em inglês, o `@map` converte; o que importa é existir um único conjunto de valores.

## 8. Como o banco apoia as regras de negócio

Cada regra que cabe ao banco e onde ela é garantida. "Banco" = restrição que o PostgreSQL faz valer; "Backend" = regra de código, com apoio do banco.

| Regra | Resumo | Como o banco apoia | Onde |
|---|---|---|---|
| RN-ACE-03 | E-mail único, sem maiúsculas | `uq_usuario_email_lower` | Banco |
| RN-ACE-05 | Senha só como hash | Só existe `senha_hash`; não há coluna de senha em texto | Banco |
| RN-ACE-06 | Aceite dos Termos com data | `usuario.data_aceite_termos` | Banco |
| RN-ACE-07 | Confirmação de e-mail por link | `usuario.verificacao` + `token_usuario` | Banco, Backend |
| RN-ACE-09 | 5 erros = bloqueio de 15 min | `tentativas_login`, `bloqueado_ate` | Backend |
| RN-ACE-10 | Link de senha: 30 min, uso único | `token_usuario` (`expira_em`, `usado_em`) | Backend |
| RN-ACE-11, 15 | Token antigo recusado após troca de senha | `senha_alterada_em` | Backend |
| RN-ACE-14 | Conta Google sem senha | `google_sub` único; `senha_hash` anulável | Banco |
| RN-ADM-03 | "Logado agora" = últimos 5 min | `usuario.ultimo_acesso` | Banco |
| RN-ADM-05 | Suspender sem apagar dados | `status_conta = 'suspensa'` + `ck_usuario_status` | Banco |
| RN-ADM-10 | Log de ações do admin | `log_admin` (+ `detalhes`) | Banco |
| RN-ANU-02 | Preço > 0, duas casas | `numeric(10,2)` e `ck_anuncio_preco` | Banco |
| RN-ANU-03 | De 1 a 5 imagens | `ck_imagem_ordem`, `uq_imagem_ordem`; mínimo de 1 pelo backend | Banco, Backend |
| RN-ANU-05 | Só anúncio ativo, de conta ativa e não excluído aparece | `anuncio.status`, `excluido_em`, `usuario.status_conta`, view `anuncio_visivel` | Banco |
| RN-ANU-07 | Anúncio novo no topo | `data_publicacao` + `ix_anuncio_vitrine` | Banco |
| RN-ANU-08, 11 | Indicadores do dono | `visualizacoes`, `contatos`; pedidos por `COUNT` | Backend |
| RN-ANU-09 | Exclusão sem perder pedidos | `excluido_em` + FKs que bloqueiam `DELETE` | Banco |
| RN-EST-04 | Desconto atômico | `UPDATE ... WHERE quantidade >= n` (seção 9.2) | Backend |
| RN-EST-05 | Quantidade nunca negativa; ativo tem estoque | `ck_anuncio_qtd`, `ck_anuncio_ativo_com_estoque` | Banco |
| RN-PED-01 | Pedido congela vendedor, produto, preço | `id_vendedor`, `nome_produto`, `imagem_url`, `quantidade`, `preco_unitario`, `taxa_servico` | Banco |
| RN-PED-02 | `valor_total = preço × qtd + taxa` | `valor_total`; cálculo no backend | Backend |
| RN-PED-03 | Pedido sobrevive à exclusão do anúncio | `id_pedido` + exclusão lógica | Banco |
| RN-PED-05 | WhatsApp = "Em negociação", sem estoque | `forma_negociacao`, `status_pedido` | Banco |
| RN-PED-06 | "Meus pedidos" do mais recente ao mais antigo | `data_pedido` + `ix_pedido_comprador` | Banco |
| RN-PED-10 | Um pedido aberto por comprador e anúncio | `uq_pedido_aberto` | Banco |
| RN-PAG-02 | Dado de cartão nunca no Unishop | `pagamento` só guarda `id_transacao_gateway` | Banco |
| RN-PAG-04 | Pix expira em 30 min | `pagamento.data_expiracao` | Banco |
| RN-PAG-06 | Webhook repetido não duplica | `uq_pagamento_ativo` + trava do pedido na transação | Banco, Backend |
| RN-PAG-08, 13, 14 | Sem estoque, pagamento tardio, anúncio inativo: cancela e estorna | `status_pedido = 'cancelado'`, `status_pagamento = 'estorno_pendente'` | Backend |
| RN-PAG-12 | Pedido pendente cancelado em 30 min | `pedido.atualizado_em`, `ix_pedido_status` | Backend |
| RN-PAG-11 | "Pago" só quando o pedido está pago | `GET /orders/:id` lê `pedido.status_pedido` | Backend |

## 9. Consultas e operações críticas

Operações em que o banco precisa estar correto. Os nomes de colunas são os do dicionário (seção 4).

### 9.1 Filtro único de visibilidade (RN-ANU-05)

Toda listagem pública (categorias, busca, carrossel e contagem) usa o mesmo filtro: anúncio ativo, de conta ativa e não excluído. A view `anuncio_visivel` (seção 14) guarda esse filtro em um só lugar; no código, o repository mantém a mesma regra em uma única função.

```sql
SELECT a.id_anuncio, a.nome, a.preco, a.data_publicacao
FROM public.anuncio_visivel a
ORDER BY a.data_publicacao DESC
LIMIT 20;
```

Contagem de anúncios ativos por categoria (tela de categorias, RN-CAT-02), com o filtro completo:

```sql
SELECT c.id_categoria, c.nome, COUNT(v.id_anuncio) AS qtd_ativos
FROM public.categoria c
LEFT JOIN public.anuncio_visivel v ON v.id_categoria = c.id_categoria
GROUP BY c.id_categoria, c.nome
ORDER BY c.nome;
```

> O Prisma não lê VIEW sem o recurso `views` habilitado. No MVP, as duas consultas acima podem rodar com `$queryRaw`, ou o repository repete o mesmo filtro (`status = 'ativo'`, `excluido_em IS NULL`, dono com `status_conta = 'ativa'`).

### 9.2 Desconto de estoque atômico (RN-EST-04, RN-EST-05)

Um único comando que só altera a linha se houver unidades suficientes. Se duas pessoas compram a última unidade ao mesmo tempo, só uma altera a linha.

```sql
UPDATE public.anuncio
   SET quantidade = quantidade - :n
 WHERE id_anuncio = :id_anuncio
   AND quantidade >= :n;
-- 1 linha alterada   => havia estoque
-- 0 linhas alteradas => não há estoque (RN-EST-04)
```

Quando a quantidade chega a zero, na mesma transação:

```sql
UPDATE public.anuncio
   SET status = 'vendido', vendido_em = now()
 WHERE id_anuncio = :id_anuncio
   AND quantidade = 0
   AND status IN ('ativo', 'pausado');          -- RN-EST-06
```

### 9.3 Liquidação do pagamento (transação única)

Pix e cartão passam pela mesma rotina (RN-PAG-14). Esboço do que acontece no banco:

```sql
BEGIN;

-- 1) trava o pedido (evita duas liquidações ao mesmo tempo; garante idempotência)
SELECT status_pedido, id_anuncio, quantidade
  FROM public.pedido WHERE id_pedido = :id_pedido FOR UPDATE;
-- se status_pedido = 'pago'      => COMMIT sem fazer nada (RN-PAG-06)
-- se status_pedido = 'cancelado' => passo 4 (pagamento tardio, RN-PAG-13)

-- 2) confere se o anúncio está ativo e se o vendedor tem conta ativa
--    (anuncio_visivel); se não => passo 4

-- 3) desconta o estoque (9.2). Se 0 linhas alteradas => passo 4
-- 3a) HAVIA ESTOQUE
UPDATE public.pedido    SET status_pedido = 'pago', atualizado_em = now()
 WHERE id_pedido = :id_pedido;
UPDATE public.pagamento SET status_pagamento = 'aprovado', data_pagamento = now()
 WHERE id_pedido = :id_pedido AND status_pagamento = 'pendente';

-- 4) NÃO PODE SER HONRADO (sem estoque, anúncio inativo ou pedido já cancelado)
UPDATE public.pedido    SET status_pedido = 'cancelado', atualizado_em = now()
 WHERE id_pedido = :id_pedido AND status_pedido <> 'cancelado';
UPDATE public.pagamento SET status_pagamento = 'estorno_pendente', data_pagamento = now()
 WHERE id_pedido = :id_pedido AND status_pagamento = 'pendente';

COMMIT;
-- depois do COMMIT: estorno no gateway (await, não em segundo plano) e, se der certo,
-- status_pagamento = 'estornado'; e-mail ao comprador (RN-NOT-03) ou ao vendedor (RN-NOT-01).
```

O e-mail e a chamada ao gateway ficam **fora** da transação, para ela ser rápida; o job de estorno retoma o que ficou em `estorno_pendente`.

### 9.4 Indicadores do administrador

Só contam **alunos**, e "logado agora" só conta contas ativas (RN-ADM-02).

```sql
-- Alunos "logados agora" (últimos 5 minutos) - RN-ADM-03
SELECT COUNT(*) FROM public.usuario
 WHERE tipo_usuario = 'aluno' AND status_conta = 'ativa'
   AND ultimo_acesso >= now() - INTERVAL '5 minutes';

-- Alunos cadastrados (ativos e suspensos)
SELECT COUNT(*) FROM public.usuario
 WHERE tipo_usuario = 'aluno' AND status_conta <> 'excluida';

-- Novos alunos na semana - RN-ADM-02
SELECT COUNT(*) FROM public.usuario
 WHERE tipo_usuario = 'aluno' AND status_conta <> 'excluida'
   AND data_cadastro >= now() - INTERVAL '7 days';

-- Produtos ativos / pausados / vendidos (não excluídos) - RN-ADM-07
SELECT status, COUNT(*) FROM public.anuncio
 WHERE excluido_em IS NULL GROUP BY status;
```

### 9.5 Pedidos recebidos por um vendedor (RN-PED-07)

O vendedor está gravado no próprio pedido:

```sql
SELECT p.id_pedido, p.status_pedido, p.valor_total, p.data_pedido,
       p.nome_produto, c.nome AS comprador
FROM public.pedido p
JOIN public.usuario c ON c.id_usuario = p.id_comprador
WHERE p.id_vendedor = :id_vendedor
ORDER BY p.data_pedido DESC;
```

### 9.6 Pedidos de um comprador (RN-PED-06)

```sql
SELECT p.id_pedido, p.status_pedido, p.valor_total, p.data_pedido,
       p.nome_produto, p.imagem_url
FROM public.pedido p
WHERE p.id_comprador = :id_comprador
ORDER BY p.data_pedido DESC;
```

### 9.7 Jobs de expiração

```sql
-- Pedidos pendentes há mais de 30 minutos, sem pagamento aprovado (RN-PAG-12)
SELECT p.id_pedido FROM public.pedido p
 WHERE p.status_pedido = 'pendente'
   AND p.data_pedido < now() - INTERVAL '30 minutes'
   AND NOT EXISTS (SELECT 1 FROM public.pagamento g
                    WHERE g.id_pedido = p.id_pedido AND g.status_pagamento = 'aprovado');

-- Pix vencido (RN-PAG-04)
SELECT id_pagamento FROM public.pagamento
 WHERE status_pagamento = 'pendente' AND data_expiracao < now();

-- Estornos a concluir (RN-PAG-08)
SELECT id_pagamento FROM public.pagamento
 WHERE status_pagamento = 'estorno_pendente' AND tentativas_estorno < 10;
```

## 10. Segurança, LGPD e anonimização

### Dados sensíveis no banco

| Dado | Onde | Proteção |
|---|---|---|
| Senha | `usuario.senha_hash` | Só hash bcrypt (custo 12). Nunca em log (RN-ACE-05) |
| WhatsApp | `usuario.whatsapp`, `anuncio.whatsapp` | O backend só o devolve em rotas autenticadas (RN-PER-04) |
| E-mail | `usuario.email` | Único; trocado na anonimização |
| Conta Google | `usuario.google_sub` | Identificador opaco; apagado na anonimização |
| Cartão | não existe no banco | Só o token vai ao gateway; o banco guarda `id_transacao_gateway` (RN-PAG-02) |
| Transação do gateway | `pagamento.id_transacao_gateway` | Sem valor de ataque isolado; mesmo assim não vai para log |
| Token de link | `token_usuario.token_hash` | Só o hash; o valor em claro vai apenas no e-mail |

### Papéis do banco (acesso)

Três papéis, cada um com a menor permissão possível:

| Papel | Para quê | Permissão |
|---|---|---|
| `unishop_migrator` | Migrações (CI e quem migra), usa `DATABASE_URL_UNPOOLED` (conexão direta) | Dono do schema; cria e altera estrutura |
| `unishop_app` | A API em execução, usa `DATABASE_URL` (conexão com pooler) | `SELECT`, `INSERT`, `UPDATE`, `DELETE` nas tabelas; **sem** permissão de alterar estrutura |
| `unishop_backup` | Cópia de segurança agendada, usa `DATABASE_URL_BACKUP` | Somente leitura (`SELECT`) |

- TLS obrigatório em todas as conexões (`sslmode=require`). O banco não é exposto à internet além do acesso do provedor (exceção documentada no Deploy); o plano gratuito do Neon não tem lista de IPs permitidos (IP Allow).
- Dados reais de produção nunca vão para desenvolvimento nem para preview (LGPD). Cada ambiente tem seu próprio banco ou branch, criado **vazio** a partir do schema; um branch do Neon copia os dados do pai, por isso o branch de desenvolvimento nunca é derivado do de produção.
- `DATABASE_URL` e as demais strings de conexão são segredos: nunca no Git.

### Anonimização ao excluir o perfil (RN-PER-06, RN-ADM-06)

Excluir o perfil não apaga a linha de `usuario`: ela é anonimizada, e os pedidos pagos continuam no histórico da outra parte, mostrando "Usuário removido". A exclusão é **bloqueada** enquanto houver pedido `pago` ou `retirada_combinada` em aberto, como comprador ou vendedor. Estado final esperado:

| Coluna | Valor após anonimizar |
|---|---|
| `nome` | `'Usuário removido'` |
| `email` | Valor sem uso e único, por exemplo `removido_<id>@removido.invalid` (libera o e-mail original para novo cadastro) |
| `senha_hash`, `google_sub` | `NULL` (a conta nunca mais entra, pois `status_conta = 'excluida'`) |
| `whatsapp`, `curso`, `foto_perfil` | `NULL` |
| `status_conta` | `'excluida'` |
| Anúncios do usuário | Excluídos de forma lógica (`excluido_em`) |
| Pedidos `pendente` e `em_negociacao` | Cancelados |
| Tokens pendentes | Apagados |

```sql
UPDATE public.usuario
   SET nome = 'Usuário removido',
       email = 'removido_' || id_usuario || '@removido.invalid',
       senha_hash = NULL, google_sub = NULL,
       whatsapp = NULL, curso = NULL, foto_perfil = NULL,
       status_conta = 'excluida'
 WHERE id_usuario = :id;
```

### Cópias de segurança e dados anonimizados

Backups e pontos de restauração feitos antes da anonimização guardam os dados antigos até vencerem (no Neon gratuito, a janela de restauração é de 6 horas; os arquivos do backup agendado seguem o prazo definido no Deploy). Se um backup for restaurado, a anonimização é **reaplicada** em seguida. Essa limitação consta nos Termos e na Política de privacidade.

## 11. Como criar, migrar e popular o banco

### Caminho único: Prisma

O banco **não** é restaurado a partir do dump no Neon. A estrutura é criada e evoluída por **uma só via**, as migrações do Prisma, para desenvolvimento, preview e produção terem o mesmo schema.

1. **Baseline (`0_init`).** Com o `schema.prisma` descrevendo as 8 tabelas (nomes pelo mapeamento da seção 7), gerar a migração inicial a partir do zero:

   ```bash
   mkdir -p prisma/migrations/0_init
   npx prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma \
     --script > prisma/migrations/0_init/migration.sql
   ```

   (Em versões mais novas do Prisma a opção se chama `--to-schema`; conferir com `--help`.)

2. **Regras que o Prisma não expressa.** Uma segunda migração, escrita à mão (`prisma migrate dev --create-only`), com o SQL da **seção 14**: `CHECK`, índices parciais, índice sobre `lower(email)`, view, papéis e permissões.
3. **Aplicar.** `npx prisma migrate deploy` em cada ambiente, com `DATABASE_URL_UNPOOLED` (conexão direta, sem pooler) e o papel `unishop_migrator`.
4. **Desenvolvimento local.** O banco local do dump de 07/10/2026 é descartável: recriar com `npx prisma migrate reset` e o seed. Não há conversão do dump antigo.

> Alterações futuras seguem a mesma regra: alterar o `schema.prisma`, gerar a migração, revisar o SQL e, se envolver `CHECK` ou índice parcial, acrescentar na migração manual.

### Gerar uma cópia (backup)

O backup é o do Deploy (workflow agendado com `pg_dump` na versão 18, usando `DATABASE_URL_BACKUP`, somente leitura). Para um dump manual:

```bash
pg_dump "$DATABASE_URL_BACKUP" --schema-only -f unishop_schema.sql   # só a estrutura
pg_dump "$DATABASE_URL_BACKUP" -f unishop_completo.sql               # estrutura + dados
```

### Popular (seed)

O `npm run db:seed` cria:

1. As 6 categorias fixas (RN-CAT-01), de forma repetível:

   ```sql
   INSERT INTO public.categoria (nome) VALUES
     ('Livros e apostilas'), ('Eletrônicos'), ('Alimentos'),
     ('Materiais de curso'), ('Vestuário'), ('Outros')
   ON CONFLICT (nome) DO NOTHING;
   ```

2. A conta de administrador (RN-ADM-11), com `tipo_usuario = 'admin'`, `verificacao = true`, `data_aceite_termos` preenchida, e-mail e senha vindos de `ADMIN_EMAIL` e `ADMIN_PASSWORD` (a senha entra como hash). É a única exceção à regra do domínio `@edu.unifor.br`. A senha inicial deve ser trocada no primeiro acesso (RN-ACE-15).

### Limites do Neon (plano gratuito)

| Item | Limite |
|---|---|
| Armazenamento | 1 GB por projeto (as imagens ficam fora do banco, na Cloudinary) |
| Computação | 100 CU-hora por projeto por mês |
| Branches | 10 por projeto |
| Restauração instantânea | Janela de 6 horas |
| Transferência de saída | 5 GB por mês |
| Suspensão | O banco "dorme" após 5 minutos sem uso (não desativável); a primeira consulta depois disso demora mais |
| Lista de IPs (IP Allow) | Não disponível |

Os limites mudam com o tempo; conferir no painel do Neon antes da demonstração.

## 12. MER × banco: divergências

Comparação entre o `mer_unishop.drawio` e o banco. O banco segue o MER, e as diferenças abaixo são correções do **MER**, que ainda precisa ser atualizado (o `.drawio` não faz parte desta entrega).

| # | Item | No MER | No banco | O que fazer |
|---|---|---|---|---|
| 1 | Coluna de pedido | `forma_pagamento` | `forma_negociacao` | O banco está certo (pedido por WhatsApp não tem pagamento). Atualizar o MER |
| 2 | Coluna de `log_admin` | `id_amin` (erro de digitação) | `id_admin` | O banco está certo. Corrigir o MER |
| 3 | Tipos das PKs | `INT` / `SERIAL` | `integer GENERATED ALWAYS AS IDENTITY` | Equivalente. Atualizar a legenda |
| 4 | `pagamento.id_pedido` | FK, relação 1 : 0..1 | FK, **sem** UNIQUE; índice único parcial sobre pendente/aprovado | O banco guarda o histórico de tentativas (decisão da v0.2) |
| 5 | `pedido.id_anuncio` | Sublinhado como chave | FK comum | Ajuste visual no MER |
| 6 | Valores de status | Só comentários | `varchar` com `CHECK` | Acrescentar os `CHECK` ao MER |
| 7 | Colunas novas da v0.2 | Não existem | Seção 4 | Incluir no MER: `google_sub`, `whatsapp` e `excluido_em` no anúncio, `id_vendedor` e campos congelados no pedido, `token_usuario` etc. |

## 13. O que mudou da v0.1 para a v0.2

Todas as lacunas que a v0.1 listava (seção 13 dela) entraram no estado final. Para quem comparava com o dump de 07/10/2026:

| Tabela | Mudança frente ao dump | Regra |
|---|---|---|
| `usuario` | `data_aceite_termos`, `tentativas_login`, `bloqueado_ate`, `senha_alterada_em`, `google_sub`; `senha_hash` anulável; índice único em `lower(email)`; datas em `timestamptz` | RN-ACE-06, 09, 11, 14, 15 |
| `anuncio` | `whatsapp`, `excluido_em`, `vendido_em`; `descricao` obrigatória; `CHECK` de preço, estoque e estado | RN-ANU-01, 09, RN-EST-05 |
| `imagem_anuncio` | `public_id` obrigatório; `ordem` de 1 a 5 e única por anúncio | RN-ANU-03 |
| `pedido` | `id_vendedor`, `nome_produto`, `imagem_url`, `quantidade`, `preco_unitario` obrigatório, `taxa_servico`, `concluido_em`, `atualizado_em`; índice único dos pedidos abertos | RN-PED-01, 02, 10 |
| `pagamento` | Sem UNIQUE em `id_pedido` (índice parcial no lugar); estado `estorno_pendente`; `tentativas_estorno`, `ultimo_erro`, `data_expiracao`, `chave_idempotencia`, `data_criacao` | RN-PAG-04, 06, 08, 13, 14 |
| `log_admin` | `detalhes jsonb` | RN-ADM-10 |
| `token_usuario` | Tabela nova, sem `OWNER TO postgres` (o dono é o papel de migração) | RN-ACE-07, 10, RN-PER-02 |
| Geral | `CHECK` nos estados; índices; view `anuncio_visivel`; papéis do banco | RNF008, RN-ANU-05 |

## 14. SQL da migração manual

Este é o conteúdo da **segunda migração** (seção 11): tudo que o Prisma não gera sozinho. Colunas, tipos, chaves e `UNIQUE` simples já vêm do `schema.prisma`. O script deve ser testado em um banco de desenvolvimento antes de qualquer uso.

```sql
-- ============================================================
-- Unishop · migração manual · v0.2
-- Aplicar depois da migração 0_init do Prisma · PostgreSQL 18
-- ============================================================
BEGIN;

-- ------------------------------------------------------------
-- 0) CHAVES: SERIAL (gerado pelo Prisma) -> GENERATED ALWAYS AS IDENTITY
--    Roda sobre banco recém-criado pelo 0_init (tabelas vazias): o identity começa em 1.
-- ------------------------------------------------------------
DO $$
DECLARE
  t record;
BEGIN
  FOR t IN
    SELECT * FROM (VALUES
      ('usuario',        'id_usuario'),
      ('categoria',      'id_categoria'),
      ('anuncio',        'id_anuncio'),
      ('imagem_anuncio', 'id_imagem'),
      ('pedido',         'id_pedido'),
      ('pagamento',      'id_pagamento'),
      ('log_admin',      'id_log'),
      ('token_usuario',  'id_token')
    ) AS v(tabela, coluna)
  LOOP
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I DROP DEFAULT', t.tabela, t.coluna);
    EXECUTE format('DROP SEQUENCE IF EXISTS public.%I', t.tabela || '_' || t.coluna || '_seq');
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I ADD GENERATED ALWAYS AS IDENTITY',
                   t.tabela, t.coluna);
  END LOOP;
END $$;

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
```

### Papéis e permissões

Os papéis podem ser criados no Console do Neon ou por SQL com o papel de administração do projeto. **Confirmar no painel do Neon** como criar papéis com senha no seu projeto antes de executar. Os comandos abaixo mostram as permissões esperadas; as senhas vêm do gerenciador de segredos, nunca do repositório.

```sql
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
```

### Como conferir depois de rodar

```sql
-- todas as constraints
SELECT conrelid::regclass AS tabela, conname, contype
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY 1, 2;

-- todos os índices
SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public' ORDER BY 1, 2;
```

### Testes rápidos de integridade (devem falhar)

```sql
INSERT INTO public.anuncio (nome, descricao, preco, quantidade, whatsapp, id_usuario, id_categoria)
VALUES ('teste', 'descricao de teste', -5, 1, '85999999999', 1, 1);   -- viola ck_anuncio_preco

UPDATE public.anuncio SET quantidade = -1 WHERE id_anuncio = 1;       -- viola ck_anuncio_qtd

UPDATE public.pedido SET status_pedido = 'qualquer_coisa' WHERE id_pedido = 1;  -- viola ck_pedido_status

INSERT INTO public.usuario (nome, email, senha_hash)
VALUES ('Dup', 'ANA@edu.unifor.br', 'x'), ('Dup', 'ana@edu.unifor.br', 'x'); -- viola uq_usuario_email_lower

-- duas cobranças em andamento para o mesmo pedido: a segunda viola uq_pagamento_ativo
INSERT INTO public.pagamento (id_pedido, forma_pagamento, status_pagamento) VALUES (1, 'pix', 'pendente');
INSERT INTO public.pagamento (id_pedido, forma_pagamento, status_pagamento) VALUES (1, 'cartao', 'pendente');
```

## 15. Decisões e pendências

### Decisões já refletidas no banco

| Tema | Decisão |
|---|---|
| SGBD | PostgreSQL 18 (suportado pelo Neon), em desenvolvimento, CI, backup e produção |
| Migração | Só pelo Prisma: baseline `0_init` mais uma migração manual (seção 14). O dump não é restaurado no Neon |
| Chaves | Numéricas, `GENERATED ALWAYS AS IDENTITY` |
| Dinheiro | `numeric(10,2)` |
| Datas | `timestamptz`, em UTC |
| Estoque | `anuncio.quantidade`, sem reserva; desconto atômico só na venda fechada |
| Imagens | Arquivo na Cloudinary; banco guarda URL, `public_id` e ordem; de 1 a 5 imagens |
| Cartão | Nunca guardado; só `id_transacao_gateway` |
| Exclusão | Anúncio: exclusão lógica. Usuário: anonimização. Nenhum `DELETE` físico no uso normal |
| Auditoria | `log_admin` gravada na mesma transação da ação do admin |
| Pagamento por pedido | Várias tentativas, uma cobrança em andamento (`uq_pagamento_ativo`) |
| Login | E-mail e senha, e Google; `senha_hash` anulável (RN-ACE-14) |
| Idioma | Nomes de tabela, coluna e valores de estado em português; o backend mapeia com `@map` |
| Categorias | Livros e apostilas, Eletrônicos, Alimentos, Materiais de curso, Vestuário e Outros |
| Papéis | `unishop_migrator`, `unishop_app`, `unishop_backup` |

### Pendências em aberto

| # | Pendência | Proposta |
|---|---|---|
| 1 | Criação dos papéis no Neon: confirmar no painel (Console ou SQL) como criar papéis com senha no plano gratuito | Francisco ou Ana Clara confirma antes do primeiro deploy; se não for possível, usar um papel só e registrar a exceção no Deploy |
| 2 | Regras que o banco não garante: admin não compra, dono não compra o próprio anúncio, mínimo de 1 imagem, admin não remove o último admin | Backend (`authorizeRole`, `OWN_LISTING`, transação). Triggers são opcionais |
| 3 | Busca por texto no nome do anúncio | `ILIKE` no MVP; `pg_trgm` se a busca ficar lenta |
| 4 | Atualizar o MER conforme a seção 12 | Ajuste no `.drawio` (fora desta entrega) |
| 5 | Testar a migração `0_init` + manual em um banco vazio | Rodar a seção 14 e os testes de integridade antes de o Backend implementar os pedidos |

### Próximos passos sugeridos

1. Gerar o `schema.prisma` pelo mapeamento da seção 7 e a migração `0_init`.
2. Rodar a migração manual (seção 14) em um banco de desenvolvimento e conferir com os testes de integridade.
3. Escrever o seed (categorias e conta admin).
4. Atualizar o MER (seção 12).