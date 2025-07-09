--
-- PostgreSQL database dump
--

-- Dumped from database version 16.9 (Ubuntu 16.9-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.9 (Ubuntu 16.9-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: oban_job_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oban_job_state AS ENUM (
    'available',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'viewer',
    'creator'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins (
    id bigint NOT NULL,
    email public.citext NOT NULL,
    hashed_password character varying(255) NOT NULL,
    confirmed_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    role character varying(255) DEFAULT 'admin'::character varying NOT NULL,
    uid uuid NOT NULL
);


--
-- Name: admins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admins_id_seq OWNED BY public.admins.id;


--
-- Name: admins_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins_tokens (
    id bigint NOT NULL,
    admin_id bigint NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: admins_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admins_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admins_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admins_tokens_id_seq OWNED BY public.admins_tokens.id;


--
-- Name: creator_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.creator_codes (
    id bigint NOT NULL,
    code character varying(255) NOT NULL,
    inserted_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: creator_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.creator_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: creator_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.creator_codes_id_seq OWNED BY public.creator_codes.id;


--
-- Name: creators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.creators (
    id bigint NOT NULL,
    email character varying(255) NOT NULL,
    hashed_password character varying(255) NOT NULL,
    confirmed_at timestamp(0) without time zone,
    name character varying(255) NOT NULL,
    plan character varying(255) DEFAULT 'basic'::character varying,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    stripe_account_id character varying(255),
    onboarded boolean DEFAULT false,
    uid uuid NOT NULL,
    wallet_balance integer DEFAULT 0 NOT NULL
);


--
-- Name: creators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.creators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: creators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.creators_id_seq OWNED BY public.creators.id;


--
-- Name: creators_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.creators_tokens (
    id bigint NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    creator_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: creators_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.creators_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: creators_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.creators_tokens_id_seq OWNED BY public.creators_tokens.id;


--
-- Name: films; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.films (
    id bigint NOT NULL,
    trailer_upload_id character varying(255),
    trailer_asset_id character varying(255),
    trailer_playback_id character varying(255),
    film_upload_id character varying(255),
    film_asset_id character varying(255),
    film_playback_id character varying(255),
    project_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    duration integer
);


--
-- Name: COLUMN films.duration; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.films.duration IS 'Duration in minutes';


--
-- Name: films_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.films_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: films_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.films_id_seq OWNED BY public.films.id;


--
-- Name: live_streams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.live_streams (
    id bigint NOT NULL,
    mux_stream_id character varying(255),
    stream_key character varying(255),
    playback_id character varying(255),
    status character varying(255) DEFAULT 'idle'::character varying NOT NULL,
    project_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    expected_duration_minutes integer,
    recording boolean DEFAULT true NOT NULL
);


--
-- Name: live_streams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.live_streams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: live_streams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.live_streams_id_seq OWNED BY public.live_streams.id;


--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags text[] DEFAULT ARRAY[]::text[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oban_jobs IS '12';


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oban_jobs_id_seq OWNED BY public.oban_jobs.id;


--
-- Name: oban_peers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.oban_peers (
    name text NOT NULL,
    node text NOT NULL,
    started_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


--
-- Name: ownership_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ownership_records (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    project_id bigint NOT NULL,
    jwt_token text,
    expires_at timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: ownership_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ownership_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ownership_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ownership_records_id_seq OWNED BY public.ownership_records.id;


--
-- Name: premieres; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.premieres (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    start_time timestamp(0) without time zone NOT NULL,
    end_time timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: premieres_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.premieres_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: premieres_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.premieres_id_seq OWNED BY public.premieres.id;


--
-- Name: project_approval_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_approval_queue (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: project_approval_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_approval_queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_approval_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_approval_queue_id_seq OWNED BY public.project_approval_queue.id;


--
-- Name: project_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_reviews (
    id bigint NOT NULL,
    status character varying(255) NOT NULL,
    feedback text,
    project_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: project_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_reviews_id_seq OWNED BY public.project_reviews.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    title character varying(255) NOT NULL,
    description character varying(255) NOT NULL,
    type character varying(255) NOT NULL,
    premiere_date timestamp(0) without time zone NOT NULL,
    premiere_price numeric(10,2),
    rental_price numeric(10,2) NOT NULL,
    rental_window_hours integer NOT NULL,
    status character varying(255) DEFAULT 'draft'::character varying NOT NULL,
    creator_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    premiere_creator_cut numeric(10,2),
    rental_creator_cut numeric(10,2)
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email public.citext NOT NULL,
    hashed_password character varying(255) NOT NULL,
    confirmed_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    plan character varying(255) DEFAULT 'free'::character varying NOT NULL,
    name character varying(255),
    uid uuid NOT NULL,
    wallet_balance integer DEFAULT 0 NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: users_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_tokens_id_seq OWNED BY public.users_tokens.id;


--
-- Name: admins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins ALTER COLUMN id SET DEFAULT nextval('public.admins_id_seq'::regclass);


--
-- Name: admins_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins_tokens ALTER COLUMN id SET DEFAULT nextval('public.admins_tokens_id_seq'::regclass);


--
-- Name: creator_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creator_codes ALTER COLUMN id SET DEFAULT nextval('public.creator_codes_id_seq'::regclass);


--
-- Name: creators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators ALTER COLUMN id SET DEFAULT nextval('public.creators_id_seq'::regclass);


--
-- Name: creators_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators_tokens ALTER COLUMN id SET DEFAULT nextval('public.creators_tokens_id_seq'::regclass);


--
-- Name: films id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films ALTER COLUMN id SET DEFAULT nextval('public.films_id_seq'::regclass);


--
-- Name: live_streams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.live_streams ALTER COLUMN id SET DEFAULT nextval('public.live_streams_id_seq'::regclass);


--
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: ownership_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ownership_records ALTER COLUMN id SET DEFAULT nextval('public.ownership_records_id_seq'::regclass);


--
-- Name: premieres id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.premieres ALTER COLUMN id SET DEFAULT nextval('public.premieres_id_seq'::regclass);


--
-- Name: project_approval_queue id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_approval_queue ALTER COLUMN id SET DEFAULT nextval('public.project_approval_queue_id_seq'::regclass);


--
-- Name: project_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_reviews ALTER COLUMN id SET DEFAULT nextval('public.project_reviews_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: users_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens ALTER COLUMN id SET DEFAULT nextval('public.users_tokens_id_seq'::regclass);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: admins_tokens admins_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins_tokens
    ADD CONSTRAINT admins_tokens_pkey PRIMARY KEY (id);


--
-- Name: creator_codes creator_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creator_codes
    ADD CONSTRAINT creator_codes_pkey PRIMARY KEY (id);


--
-- Name: creators creators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators
    ADD CONSTRAINT creators_pkey PRIMARY KEY (id);


--
-- Name: creators_tokens creators_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators_tokens
    ADD CONSTRAINT creators_tokens_pkey PRIMARY KEY (id);


--
-- Name: films films_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT films_pkey PRIMARY KEY (id);


--
-- Name: live_streams live_streams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.live_streams
    ADD CONSTRAINT live_streams_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs non_negative_priority; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.oban_jobs
    ADD CONSTRAINT non_negative_priority CHECK ((priority >= 0)) NOT VALID;


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: oban_peers oban_peers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_peers
    ADD CONSTRAINT oban_peers_pkey PRIMARY KEY (name);


--
-- Name: ownership_records ownership_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ownership_records
    ADD CONSTRAINT ownership_records_pkey PRIMARY KEY (id);


--
-- Name: premieres premieres_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.premieres
    ADD CONSTRAINT premieres_pkey PRIMARY KEY (id);


--
-- Name: project_approval_queue project_approval_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_approval_queue
    ADD CONSTRAINT project_approval_queue_pkey PRIMARY KEY (id);


--
-- Name: project_reviews project_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_reviews
    ADD CONSTRAINT project_reviews_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_tokens users_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_pkey PRIMARY KEY (id);


--
-- Name: admins_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admins_email_index ON public.admins USING btree (email);


--
-- Name: admins_tokens_admin_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admins_tokens_admin_id_index ON public.admins_tokens USING btree (admin_id);


--
-- Name: admins_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admins_tokens_context_token_index ON public.admins_tokens USING btree (context, token);


--
-- Name: admins_uid_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admins_uid_index ON public.admins USING btree (uid);


--
-- Name: creators_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX creators_email_index ON public.creators USING btree (email);


--
-- Name: creators_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX creators_tokens_context_token_index ON public.creators_tokens USING btree (context, token);


--
-- Name: creators_tokens_creator_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX creators_tokens_creator_id_index ON public.creators_tokens USING btree (creator_id);


--
-- Name: creators_uid_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX creators_uid_index ON public.creators USING btree (uid);


--
-- Name: films_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX films_project_id_index ON public.films USING btree (project_id);


--
-- Name: live_streams_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX live_streams_project_id_index ON public.live_streams USING btree (project_id);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_args_index ON public.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_meta_index ON public.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_state_queue_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_index ON public.oban_jobs USING btree (state, queue, priority, scheduled_at, id);


--
-- Name: ownership_records_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ownership_records_expires_at_index ON public.ownership_records USING btree (expires_at);


--
-- Name: ownership_records_user_id_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ownership_records_user_id_project_id_index ON public.ownership_records USING btree (user_id, project_id);


--
-- Name: premieres_end_time_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX premieres_end_time_index ON public.premieres USING btree (end_time);


--
-- Name: premieres_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX premieres_project_id_index ON public.premieres USING btree (project_id);


--
-- Name: premieres_start_time_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX premieres_start_time_index ON public.premieres USING btree (start_time);


--
-- Name: project_reviews_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_reviews_project_id_index ON public.project_reviews USING btree (project_id);


--
-- Name: projects_creator_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_creator_id_index ON public.projects USING btree (creator_id);


--
-- Name: projects_premiere_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_premiere_date_index ON public.projects USING btree (premiere_date);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: users_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_tokens_context_token_index ON public.users_tokens USING btree (context, token);


--
-- Name: users_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_tokens_user_id_index ON public.users_tokens USING btree (user_id);


--
-- Name: users_uid_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_uid_index ON public.users USING btree (uid);


--
-- Name: admins_tokens admins_tokens_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins_tokens
    ADD CONSTRAINT admins_tokens_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.admins(id) ON DELETE CASCADE;


--
-- Name: creators_tokens creators_tokens_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators_tokens
    ADD CONSTRAINT creators_tokens_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.creators(id) ON DELETE CASCADE;


--
-- Name: films films_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT films_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: live_streams live_streams_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.live_streams
    ADD CONSTRAINT live_streams_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: ownership_records ownership_records_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ownership_records
    ADD CONSTRAINT ownership_records_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: ownership_records ownership_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ownership_records
    ADD CONSTRAINT ownership_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: premieres premieres_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.premieres
    ADD CONSTRAINT premieres_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_approval_queue project_approval_queue_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_approval_queue
    ADD CONSTRAINT project_approval_queue_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_reviews project_reviews_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_reviews
    ADD CONSTRAINT project_reviews_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects projects_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.creators(id) ON DELETE RESTRICT;


--
-- Name: users_tokens users_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20240307000000);
INSERT INTO public."schema_migrations" (version) VALUES (20240318000000);
INSERT INTO public."schema_migrations" (version) VALUES (20240319000000);
INSERT INTO public."schema_migrations" (version) VALUES (20240320000000);
INSERT INTO public."schema_migrations" (version) VALUES (20240601235959);
INSERT INTO public."schema_migrations" (version) VALUES (20250523190103);
INSERT INTO public."schema_migrations" (version) VALUES (20250523191909);
INSERT INTO public."schema_migrations" (version) VALUES (20250523192158);
INSERT INTO public."schema_migrations" (version) VALUES (20250523202526);
INSERT INTO public."schema_migrations" (version) VALUES (20250527043801);
INSERT INTO public."schema_migrations" (version) VALUES (20250528213613);
INSERT INTO public."schema_migrations" (version) VALUES (20250601213246);
INSERT INTO public."schema_migrations" (version) VALUES (20250601213751);
INSERT INTO public."schema_migrations" (version) VALUES (20250601223503);
INSERT INTO public."schema_migrations" (version) VALUES (20250601224500);
INSERT INTO public."schema_migrations" (version) VALUES (20250601225000);
INSERT INTO public."schema_migrations" (version) VALUES (20250601225500);
INSERT INTO public."schema_migrations" (version) VALUES (20250603030421);
INSERT INTO public."schema_migrations" (version) VALUES (20250604214532);
INSERT INTO public."schema_migrations" (version) VALUES (20250604221455);
INSERT INTO public."schema_migrations" (version) VALUES (20250605233827);
INSERT INTO public."schema_migrations" (version) VALUES (20250605234235);
INSERT INTO public."schema_migrations" (version) VALUES (20250617005324);
INSERT INTO public."schema_migrations" (version) VALUES (20250620060317);
INSERT INTO public."schema_migrations" (version) VALUES (20250620060339);
INSERT INTO public."schema_migrations" (version) VALUES (20250621025557);
INSERT INTO public."schema_migrations" (version) VALUES (20250621061622);
INSERT INTO public."schema_migrations" (version) VALUES (20250622042450);
INSERT INTO public."schema_migrations" (version) VALUES (20250622072256);
INSERT INTO public."schema_migrations" (version) VALUES (20250624065830);
INSERT INTO public."schema_migrations" (version) VALUES (20250624111502);
INSERT INTO public."schema_migrations" (version) VALUES (20250624221317);
INSERT INTO public."schema_migrations" (version) VALUES (20250624222220);
INSERT INTO public."schema_migrations" (version) VALUES (20250624222749);
INSERT INTO public."schema_migrations" (version) VALUES (20250624230458);
INSERT INTO public."schema_migrations" (version) VALUES (20250626052137);
INSERT INTO public."schema_migrations" (version) VALUES (20250626055033);
INSERT INTO public."schema_migrations" (version) VALUES (20250629054819);
INSERT INTO public."schema_migrations" (version) VALUES (20250703192143);
