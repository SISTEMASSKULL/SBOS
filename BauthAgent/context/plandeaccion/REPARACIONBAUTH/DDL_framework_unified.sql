--
-- PostgreSQL database dump
--

\restrict AHscJO91fT3HI1QdYyTtUfnZsccPQv3rK48UHou3CarA13RQHc09eBB7p9OLDxT

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

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
-- Name: framework_unified; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.framework_unified (
    section_id integer NOT NULL,
    section_name text NOT NULL,
    parent_path text,
    json_path text NOT NULL,
    depth integer DEFAULT 1 NOT NULL,
    order_index integer DEFAULT 1 NOT NULL,
    array_index bigint DEFAULT 0,
    node_type text NOT NULL,
    domain_map text[],
    source text NOT NULL,
    standard_ref text,
    industry_source text,
    content jsonb NOT NULL,
    content_en jsonb NOT NULL,
    content_es jsonb NOT NULL,
    help_text jsonb,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    semantic_type text,
    enforcement text,
    risk_level text,
    compliance_ref text[],
    lifecycle text,
    applicability text[],
    assurance_level text,
    auth_factor text,
    phishing_resistant boolean,
    session_timeout integer,
    mfa_required boolean,
    CONSTRAINT chk_array_min CHECK ((array_index >= 0)),
    CONSTRAINT chk_depth_min CHECK ((depth >= 1)),
    CONSTRAINT chk_order_min CHECK ((order_index >= 1)),
    CONSTRAINT framework_unified_assurance_level_check CHECK ((assurance_level = ANY (ARRAY['AAL1'::text, 'AAL2'::text, 'AAL3'::text]))),
    CONSTRAINT framework_unified_auth_factor_check CHECK ((auth_factor = ANY (ARRAY['knowledge'::text, 'possession'::text, 'inherence'::text, 'context'::text, 'multi'::text]))),
    CONSTRAINT framework_unified_enforcement_check CHECK ((enforcement = ANY (ARRAY['mandatory'::text, 'recommended'::text, 'optional'::text]))),
    CONSTRAINT framework_unified_lifecycle_check CHECK ((lifecycle = ANY (ARRAY['active'::text, 'deprecated'::text, 'draft'::text, 'proposed'::text]))),
    CONSTRAINT framework_unified_node_type_check CHECK ((node_type = ANY (ARRAY['section'::text, 'group'::text, 'policy'::text, 'config'::text]))),
    CONSTRAINT framework_unified_risk_level_check CHECK ((risk_level = ANY (ARRAY['critical'::text, 'high'::text, 'medium'::text, 'low'::text]))),
    CONSTRAINT framework_unified_semantic_type_check CHECK ((semantic_type = ANY (ARRAY['policy'::text, 'configuration'::text, 'method'::text, 'standard'::text, 'guideline'::text, 'group'::text])))
);


ALTER TABLE public.framework_unified OWNER TO postgres;

--
-- Name: framework_unified_section_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.framework_unified_section_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.framework_unified_section_id_seq OWNER TO postgres;

--
-- Name: framework_unified_section_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.framework_unified_section_id_seq OWNED BY public.framework_unified.section_id;


--
-- Name: framework_unified section_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.framework_unified ALTER COLUMN section_id SET DEFAULT nextval('public.framework_unified_section_id_seq'::regclass);


--
-- Name: framework_unified framework_unified_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.framework_unified
    ADD CONSTRAINT framework_unified_pkey PRIMARY KEY (section_id);


--
-- Name: idx_unified_assurance; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_assurance ON public.framework_unified USING btree (assurance_level);


--
-- Name: idx_unified_domain; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_domain ON public.framework_unified USING gin (domain_map);


--
-- Name: idx_unified_enforcement; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_enforcement ON public.framework_unified USING btree (enforcement);


--
-- Name: idx_unified_json_path; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unified_json_path ON public.framework_unified USING btree (json_path, source);


--
-- Name: idx_unified_lifecycle; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_lifecycle ON public.framework_unified USING btree (lifecycle);


--
-- Name: idx_unified_mfa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_mfa ON public.framework_unified USING btree (mfa_required);


--
-- Name: idx_unified_node_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_node_type ON public.framework_unified USING btree (node_type);


--
-- Name: idx_unified_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_parent ON public.framework_unified USING btree (parent_path, source);


--
-- Name: idx_unified_phish; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_phish ON public.framework_unified USING btree (phishing_resistant);


--
-- Name: idx_unified_risk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_risk ON public.framework_unified USING btree (risk_level);


--
-- Name: idx_unified_semantic; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_semantic ON public.framework_unified USING btree (semantic_type);


--
-- Name: idx_unified_source; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unified_source ON public.framework_unified USING btree (source);


--
-- Name: uq_json_path_global; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX uq_json_path_global ON public.framework_unified USING btree (json_path);


--
-- Name: uq_unified_section; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX uq_unified_section ON public.framework_unified USING btree (section_name, COALESCE(parent_path, ''::text), source);


--
-- Name: framework_unified fk_parent_path; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.framework_unified
    ADD CONSTRAINT fk_parent_path FOREIGN KEY (parent_path, source) REFERENCES public.framework_unified(json_path, source) NOT VALID;


--
-- PostgreSQL database dump complete
--

\unrestrict AHscJO91fT3HI1QdYyTtUfnZsccPQv3rK48UHou3CarA13RQHc09eBB7p9OLDxT

