--
-- PostgreSQL database dump
--

\restrict 3Tjf4MyhB5ICzdYjlLLGlAqzbQ6qzccIknvrSxTrZB6fCgbyp99pSqfOLibYEll

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-10-07 22:08:19

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 224 (class 1259 OID 16421)
-- Name: anuncio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.anuncio (
    id_anuncio integer NOT NULL,
    nome character varying(150) NOT NULL,
    descricao text,
    preco numeric(10,2) NOT NULL,
    quantidade integer DEFAULT 1 NOT NULL,
    status character varying(20) DEFAULT 'ativo'::character varying NOT NULL,
    data_publicacao timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    visualizacoes integer DEFAULT 0 NOT NULL,
    contatos integer DEFAULT 0 NOT NULL,
    id_usuario integer NOT NULL,
    id_categoria integer NOT NULL
);


ALTER TABLE public.anuncio OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16420)
-- Name: anuncio_id_anuncio_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.anuncio ALTER COLUMN id_anuncio ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.anuncio_id_anuncio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 222 (class 1259 OID 16411)
-- Name: categoria; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categoria (
    id_categoria integer NOT NULL,
    nome character varying(100) NOT NULL
);


ALTER TABLE public.categoria OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16410)
-- Name: categoria_id_categoria_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.categoria ALTER COLUMN id_categoria ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categoria_id_categoria_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 16454)
-- Name: imagem_anuncio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.imagem_anuncio (
    id_imagem integer NOT NULL,
    id_anuncio integer NOT NULL,
    url_imagem character varying(255) NOT NULL,
    ordem integer NOT NULL
);


ALTER TABLE public.imagem_anuncio OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16453)
-- Name: imagem_anuncio_id_imagem_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.imagem_anuncio ALTER COLUMN id_imagem ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.imagem_anuncio_id_imagem_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 232 (class 1259 OID 16511)
-- Name: log_admin; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.log_admin (
    id_log integer NOT NULL,
    id_admin integer NOT NULL,
    acao character varying(50) NOT NULL,
    entidade character varying(20) NOT NULL,
    id_entidade integer NOT NULL,
    data_acao timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.log_admin OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16510)
-- Name: log_admin_id_log_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.log_admin ALTER COLUMN id_log ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.log_admin_id_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 16494)
-- Name: pagamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pagamento (
    id_pagamento integer NOT NULL,
    id_pedido integer NOT NULL,
    id_transacao_gateway character varying(255),
    forma_pagamento character varying(20) NOT NULL,
    status_pagamento character varying(20) NOT NULL,
    data_pagamento timestamp without time zone,
    valor numeric(10,2)
);


ALTER TABLE public.pagamento OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16493)
-- Name: pagamento_id_pagamento_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.pagamento ALTER COLUMN id_pagamento ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.pagamento_id_pagamento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 16469)
-- Name: pedido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pedido (
    id_pedido integer NOT NULL,
    id_anuncio integer NOT NULL,
    id_comprador integer NOT NULL,
    forma_negociacao character varying(20) NOT NULL,
    status_pedido character varying(20) DEFAULT 'em_negociacao'::character varying NOT NULL,
    data_pedido timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    valor_total numeric(10,2) NOT NULL
);


ALTER TABLE public.pedido OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16468)
-- Name: pedido_id_pedido_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.pedido ALTER COLUMN id_pedido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.pedido_id_pedido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 16389)
-- Name: usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario (
    id_usuario integer NOT NULL,
    nome character varying(150) NOT NULL,
    email character varying(150) NOT NULL,
    senha_hash character varying(255) NOT NULL,
    whatsapp character varying(20),
    curso character varying(100),
    foto_perfil character varying(255),
    verificacao boolean DEFAULT false NOT NULL,
    tipo_usuario character varying(20) DEFAULT 'aluno'::character varying NOT NULL,
    status_conta character varying(20) DEFAULT 'ativa'::character varying NOT NULL,
    data_cadastro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ultimo_acesso timestamp without time zone
);


ALTER TABLE public.usuario OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16388)
-- Name: usuario_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.usuario ALTER COLUMN id_usuario ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.usuario_id_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 4861 (class 2606 OID 16442)
-- Name: anuncio anuncio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.anuncio
    ADD CONSTRAINT anuncio_pkey PRIMARY KEY (id_anuncio);


--
-- TOC entry 4857 (class 2606 OID 16419)
-- Name: categoria categoria_nome_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_nome_key UNIQUE (nome);


--
-- TOC entry 4859 (class 2606 OID 16417)
-- Name: categoria categoria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_pkey PRIMARY KEY (id_categoria);


--
-- TOC entry 4863 (class 2606 OID 16462)
-- Name: imagem_anuncio imagem_anuncio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.imagem_anuncio
    ADD CONSTRAINT imagem_anuncio_pkey PRIMARY KEY (id_imagem);


--
-- TOC entry 4871 (class 2606 OID 16522)
-- Name: log_admin log_admin_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_admin
    ADD CONSTRAINT log_admin_pkey PRIMARY KEY (id_log);


--
-- TOC entry 4867 (class 2606 OID 16504)
-- Name: pagamento pagamento_id_pedido_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagamento
    ADD CONSTRAINT pagamento_id_pedido_key UNIQUE (id_pedido);


--
-- TOC entry 4869 (class 2606 OID 16502)
-- Name: pagamento pagamento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagamento
    ADD CONSTRAINT pagamento_pkey PRIMARY KEY (id_pagamento);


--
-- TOC entry 4865 (class 2606 OID 16482)
-- Name: pedido pedido_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT pedido_pkey PRIMARY KEY (id_pedido);


--
-- TOC entry 4853 (class 2606 OID 16409)
-- Name: usuario usuario_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_email_key UNIQUE (email);


--
-- TOC entry 4855 (class 2606 OID 16407)
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id_usuario);


--
-- TOC entry 4872 (class 2606 OID 16448)
-- Name: anuncio fk_anuncio_categoria; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.anuncio
    ADD CONSTRAINT fk_anuncio_categoria FOREIGN KEY (id_categoria) REFERENCES public.categoria(id_categoria);


--
-- TOC entry 4873 (class 2606 OID 16443)
-- Name: anuncio fk_anuncio_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.anuncio
    ADD CONSTRAINT fk_anuncio_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4874 (class 2606 OID 16463)
-- Name: imagem_anuncio fk_imagem_anuncio; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.imagem_anuncio
    ADD CONSTRAINT fk_imagem_anuncio FOREIGN KEY (id_anuncio) REFERENCES public.anuncio(id_anuncio);


--
-- TOC entry 4878 (class 2606 OID 16523)
-- Name: log_admin fk_log_admin_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_admin
    ADD CONSTRAINT fk_log_admin_usuario FOREIGN KEY (id_admin) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4877 (class 2606 OID 16505)
-- Name: pagamento fk_pagamento_pedido; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagamento
    ADD CONSTRAINT fk_pagamento_pedido FOREIGN KEY (id_pedido) REFERENCES public.pedido(id_pedido);


--
-- TOC entry 4875 (class 2606 OID 16483)
-- Name: pedido fk_pedido_anuncio; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_anuncio FOREIGN KEY (id_anuncio) REFERENCES public.anuncio(id_anuncio);


--
-- TOC entry 4876 (class 2606 OID 16488)
-- Name: pedido fk_pedido_comprador; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_comprador FOREIGN KEY (id_comprador) REFERENCES public.usuario(id_usuario);


-- Completed on 2026-10-07 22:08:20

--
-- PostgreSQL database dump complete
--

\unrestrict 3Tjf4MyhB5ICzdYjlLLGlAqzbQ6qzccIknvrSxTrZB6fCgbyp99pSqfOLibYEll

