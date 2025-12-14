--
-- PostgreSQL database dump
--

-- Dumped from database version 15.2
-- Dumped by pg_dump version 15.2

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: butaca_por_funcion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.butaca_por_funcion (
    id_funcion integer,
    nro_fila integer,
    nro_butaca integer,
    id_cliente integer,
    estado character(15)
);


ALTER TABLE public.butaca_por_funcion OWNER TO postgres;

--
-- Name: cliente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.cliente (
    id_cliente integer NOT NULL,
    nombre text,
    apellido text,
    dni integer,
    fecha_nacimiento date,
    telefono character(12),
    email text
);


ALTER TABLE public.cliente OWNER TO postgres;

--
-- Name: envio_email; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.envio_email (
    id_email integer NOT NULL,
    f_generacion timestamp without time zone,
    email_cliente text,
    asunto text,
    cuerpo text,
    f_envio timestamp without time zone,
    estado character(10)
);


ALTER TABLE public.envio_email OWNER TO postgres;

--
-- Name: error; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.error (
    id_error integer NOT NULL,
    id_sala integer,
    f_inicio_funcion timestamp without time zone,
    id_pelicula integer,
    id_funcion integer,
    nro_fila integer,
    nro_butaca integer,
    id_cliente integer,
    f_error timestamp without time zone,
    motivo character varying(80)
);


ALTER TABLE public.error OWNER TO postgres;

--
-- Name: funcion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.funcion (
    id_funcion integer NOT NULL,
    id_sala integer,
    fecha_inicio date,
    hora_inicio time without time zone,
    fecha_fin date,
    hora_fin time without time zone,
    id_pelicula integer,
    butacas_disponible integer
);


ALTER TABLE public.funcion OWNER TO postgres;

--
-- Name: pelicula; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.pelicula (
    id_pelicula integer NOT NULL,
    titulo text,
    duracion interval,
    director character varying(40),
    origen character varying(60),
    formato character(10)
);


ALTER TABLE public.pelicula OWNER TO postgres;

--
-- Name: sala_cine; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.sala_cine (
    id_sala integer NOT NULL,
    nombre text,
    formato character(10),
    nro_filas integer,
    nro_butacas_por_fila integer,
    capacidad_total integer
);

ALTER TABLE public.sala_cine OWNER TO postgres;

CREATE TABLE IF NOT EXISTS public.datos_de_prueba (
    id_orden           INTEGER      PRIMARY KEY,
    operacion          CHAR(20)     NOT NULL,
    id_sala            INTEGER,
    f_inicio_funcion   TIMESTAMP,
    id_pelicula        INTEGER,
    id_funcion         INTEGER,
    nro_fila           INTEGER,
    nro_butaca         INTEGER,
    id_cliente         INTEGER,
    CHECK (operacion IN ('nueva funcion',
                         'reserva butaca',
                         'compra butaca',
                         'anulacion reserva'))
);
ALTER TABLE public.datos_de_prueba OWNER TO postgres;
