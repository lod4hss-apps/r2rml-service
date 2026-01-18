--
-- PostgreSQL database dump
--

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.3

-- Started on 2026-01-16 16:05:41

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
-- TOC entry 76 (class 2615 OID 1448684)
-- Name: rdf; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA rdf;


--
-- TOC entry 2481 (class 1255 OID 2285965)
-- Name: get_ontop_entity_preview(integer); Type: FUNCTION; Schema: rdf; Owner: -
--

CREATE FUNCTION rdf.get_ontop_entity_preview(idp integer) RETURNS TABLE(pk_entity integer, entity_label text, class_uri text)
    LANGUAGE sql
    AS $$
SELECT pk_entity,
	entity_label,
	cls.top_level_namespace_uri || cls.identifier_in_namespace AS class_uri
FROM pgwar.entity_preview ep
JOIN che.class_with_namespace cls
ON ep.fk_class = cls.pk_class
WHERE ep.fk_project = idp;
$$;


--
-- TOC entry 2480 (class 1255 OID 2270843)
-- Name: get_ontop_project_statements(integer); Type: FUNCTION; Schema: rdf; Owner: -
--

CREATE FUNCTION rdf.get_ontop_project_statements(fk_project integer) RETURNS TABLE(pk_entity integer, fk_project integer, fk_subject_info integer, fk_property integer, fk_object_info integer, fk_object_tables_cell bigint, ord_num_of_domain numeric, ord_num_of_range numeric, object_label text, tmsp_last_modification timestamp with time zone, property_standard_label text)
    LANGUAGE sql
    AS $$
SELECT
    ps.pk_entity,
    ps.fk_project,
    ps.fk_subject_info,
    ps.fk_property,
    ps.fk_object_info,
    ps.fk_object_tables_cell,
    ps.ord_num_of_domain,
    ps.ord_num_of_range,

    -- Traitement conditionnel pour extraire la date de object_label,
    -- en gérant correctement les dates avant J.C. (commençant par "-").
    CASE
        WHEN ps.fk_property IN (71, 72, 150, 151, 152, 153) THEN
            CASE
                -- Extrait une date complète (ex: '2024-06-07' ou '-0450-01-25')
                WHEN ps.object_label LIKE '%(1 day)%' THEN substring(ps.object_label FROM '(-?\d{4}-\d{2}-\d{2})')
                
                -- Extrait l'année et le mois (ex: '2024-06' ou '-0450-01')
                WHEN ps.object_label LIKE '%(1 month)%' THEN substring(ps.object_label FROM '(-?\d{4}-\d{2})')
                
                -- Extrait l'année (ex: '2024' ou '-0450')
                WHEN ps.object_label LIKE '%(1 year)%' THEN substring(ps.object_label FROM '(-?\d{4})')
                
                ELSE ps.object_label
            END
        ELSE
            ps.object_label
    END AS object_label,

    ps.tmsp_last_modification,
    prop.property_standard_label

FROM pgwar.project_statements ps
JOIN che.property_with_namespace prop
  ON ps.fk_property = prop.pk_property
WHERE ps.fk_project = get_ontop_project_statements.fk_project;
$$;


--
-- TOC entry 1328 (class 1259 OID 1456626)
-- Name: class_old; Type: FOREIGN TABLE; Schema: rdf; Owner: -
--

CREATE FOREIGN TABLE rdf.class_old (
    pk_class integer NOT NULL,
    identifier_in_namespace text,
    importer_xml_field xml,
    importer_text_field text,
    creator integer,
    modifier integer,
    creation_time timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) with time zone NOT NULL,
    modification_time timestamp(0) without time zone,
    standard_label character varying(500),
    notes text,
    sys_period tstzrange DEFAULT tstzrange(now(), NULL::timestamp with time zone) NOT NULL,
    fk_system_type integer,
    fk_ongoing_namespace integer,
    identifier_in_uri text,
    is_recursive boolean DEFAULT false
)
SERVER ontome
OPTIONS (
    schema_name 'che',
    table_name 'class'
);


--
-- TOC entry 1327 (class 1259 OID 1456625)
-- Name: class_pk_class_seq; Type: SEQUENCE; Schema: rdf; Owner: -
--

CREATE SEQUENCE rdf.class_pk_class_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 8927 (class 0 OID 0)
-- Dependencies: 1327
-- Name: class_pk_class_seq; Type: SEQUENCE OWNED BY; Schema: rdf; Owner: -
--

ALTER SEQUENCE rdf.class_pk_class_seq OWNED BY rdf.class_old.pk_class;


--
-- TOC entry 1334 (class 1259 OID 1462649)
-- Name: class_version; Type: FOREIGN TABLE; Schema: rdf; Owner: -
--

CREATE FOREIGN TABLE rdf.class_version (
    pk_class_version integer NOT NULL,
    standard_label character varying(500),
    fk_class integer,
    fk_namespace_for_version integer,
    creator integer,
    modifier integer,
    creation_time timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) with time zone NOT NULL,
    modification_time timestamp(0) without time zone,
    notes text,
    importer_xml_field xml,
    importer_text_field text,
    validation_status integer
)
SERVER ontome
OPTIONS (
    schema_name 'che',
    table_name 'class_version'
);


--
-- TOC entry 1333 (class 1259 OID 1462648)
-- Name: class_version_pk_class_version_seq; Type: SEQUENCE; Schema: rdf; Owner: -
--

CREATE SEQUENCE rdf.class_version_pk_class_version_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 8928 (class 0 OID 0)
-- Dependencies: 1333
-- Name: class_version_pk_class_version_seq; Type: SEQUENCE OWNED BY; Schema: rdf; Owner: -
--

ALTER SEQUENCE rdf.class_version_pk_class_version_seq OWNED BY rdf.class_version.pk_class_version;


--
-- TOC entry 1332 (class 1259 OID 1462629)
-- Name: namespace; Type: FOREIGN TABLE; Schema: rdf; Owner: -
--

CREATE FOREIGN TABLE rdf.namespace (
    pk_namespace integer NOT NULL,
    namespace_uri text,
    notes text,
    importer_integer integer,
    fk_is_version_of integer,
    creator integer,
    modifier integer,
    creation_time timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) with time zone NOT NULL,
    modification_time timestamp(0) without time zone,
    sys_period tstzrange DEFAULT tstzrange(now(), NULL::timestamp with time zone) NOT NULL,
    is_top_level_namespace boolean,
    fk_top_level_namespace integer,
    fk_project_for_top_level_namespace integer,
    is_ongoing boolean,
    class_prefix character varying(10),
    current_class_number integer,
    property_prefix character varying(10),
    current_property_number integer,
    standard_label text,
    deprecated_at timestamp(0) without time zone,
    original_namespace_uri text,
    published_at timestamp(0) without time zone,
    has_publication boolean,
    is_external_namespace boolean,
    root_namespace_prefix character varying(10),
    is_visible boolean DEFAULT false,
    uri_parameter integer DEFAULT 0
)
SERVER ontome
OPTIONS (
    schema_name 'che',
    table_name 'namespace'
);


--
-- TOC entry 1331 (class 1259 OID 1462628)
-- Name: namespace_pk_namespace_seq; Type: SEQUENCE; Schema: rdf; Owner: -
--

CREATE SEQUENCE rdf.namespace_pk_namespace_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 8929 (class 0 OID 0)
-- Dependencies: 1331
-- Name: namespace_pk_namespace_seq; Type: SEQUENCE OWNED BY; Schema: rdf; Owner: -
--

ALTER SEQUENCE rdf.namespace_pk_namespace_seq OWNED BY rdf.namespace.pk_namespace;


--
-- TOC entry 1330 (class 1259 OID 1462608)
-- Name: property; Type: FOREIGN TABLE; Schema: rdf; Owner: -
--

CREATE FOREIGN TABLE rdf.property (
    pk_property integer NOT NULL,
    identifier_in_namespace text,
    has_domain integer,
    has_range integer,
    importer_xml_field xml,
    importer_text_field text,
    creator integer,
    modifier integer,
    creation_time timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) with time zone NOT NULL,
    modification_time timestamp(0) without time zone,
    domain_instances_min_quantifier smallint,
    range_instances_min_quantifier smallint,
    notes text,
    standard_label character varying(500),
    sys_period tstzrange DEFAULT tstzrange(now(), NULL::timestamp with time zone) NOT NULL,
    domain_instances_max_quantifier smallint,
    range_instances_max_quantifier smallint,
    fk_property_of_origin integer,
    fk_ongoing_namespace integer,
    is_domain_identification boolean DEFAULT false NOT NULL,
    identifier_in_uri text,
    is_recursive boolean DEFAULT false
)
SERVER ontome
OPTIONS (
    schema_name 'che',
    table_name 'property'
);


--
-- TOC entry 1329 (class 1259 OID 1462607)
-- Name: property_pk_property_seq; Type: SEQUENCE; Schema: rdf; Owner: -
--

CREATE SEQUENCE rdf.property_pk_property_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 8930 (class 0 OID 0)
-- Dependencies: 1329
-- Name: property_pk_property_seq; Type: SEQUENCE OWNED BY; Schema: rdf; Owner: -
--

ALTER SEQUENCE rdf.property_pk_property_seq OWNED BY rdf.property.pk_property;


--
-- TOC entry 1336 (class 1259 OID 1462655)
-- Name: property_version; Type: FOREIGN TABLE; Schema: rdf; Owner: -
--

CREATE FOREIGN TABLE rdf.property_version (
    pk_property_version integer NOT NULL,
    standard_label character varying(500),
    fk_property integer,
    has_domain integer,
    has_range integer,
    domain_instances_min_quantifier smallint,
    range_instances_min_quantifier smallint,
    domain_instances_max_quantifier smallint,
    range_instances_max_quantifier smallint,
    fk_property_of_origin integer,
    fk_namespace_for_version integer,
    is_domain_identification boolean DEFAULT false NOT NULL,
    creator integer,
    modifier integer,
    creation_time timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) with time zone NOT NULL,
    modification_time timestamp(0) without time zone,
    notes text,
    importer_xml_field xml,
    importer_text_field text,
    fk_domain_namespace integer,
    fk_range_namespace integer,
    validation_status integer
)
SERVER ontome
OPTIONS (
    schema_name 'che',
    table_name 'property_version'
);


--
-- TOC entry 1335 (class 1259 OID 1462654)
-- Name: property_version_pk_property_version_seq; Type: SEQUENCE; Schema: rdf; Owner: -
--

CREATE SEQUENCE rdf.property_version_pk_property_version_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 8931 (class 0 OID 0)
-- Dependencies: 1335
-- Name: property_version_pk_property_version_seq; Type: SEQUENCE OWNED BY; Schema: rdf; Owner: -
--

ALTER SEQUENCE rdf.property_version_pk_property_version_seq OWNED BY rdf.property_version.pk_property_version;


--
-- TOC entry 1355 (class 1259 OID 2543733)
-- Name: v_ontop_entity_preview_corr; Type: VIEW; Schema: rdf; Owner: -
--

CREATE VIEW rdf.v_ontop_entity_preview_corr AS
 SELECT ep1.pk_entity,
    ep1.fk_class,
    (cls.top_level_namespace_uri || cls.identifier_in_namespace) AS class_uri,
    COALESCE(ep1.entity_label, ep2.entity_label) AS entity_label,
    ep1.fk_project
   FROM pgwar.entity_preview ep1,
    pgwar.entity_preview ep2,
    che.class_with_namespace cls
  WHERE ((ep2.fk_project = 0) AND (ep1.fk_project <> 0) AND (ep2.pk_entity = ep1.pk_entity) AND (ep1.fk_class <> ALL (ARRAY[52, 84, 689, 52, 689, 709, 711, 717])) AND (ep1.fk_class = cls.pk_class) AND (COALESCE(ep1.entity_label, ep2.entity_label) IS NOT NULL));


--
-- TOC entry 1357 (class 1259 OID 2545821)
-- Name: v_ontop_1483135_entity_preview; Type: VIEW; Schema: rdf; Owner: -
--

CREATE VIEW rdf.v_ontop_1483135_entity_preview AS
 SELECT pk_entity,
    class_uri,
    entity_label
   FROM rdf.v_ontop_entity_preview_corr
  WHERE (fk_project = 1483135);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 1347 (class 1259 OID 1712191)
-- Name: v_ontop_2270010_entity_preview; Type: MATERIALIZED VIEW; Schema: rdf; Owner: -
--

CREATE MATERIALIZED VIEW rdf.v_ontop_2270010_entity_preview AS
 SELECT DISTINCT ep.pk_entity,
    ep.entity_label,
    ep.fk_class,
    ep.class_label,
    concat(n1.namespace_uri, cl.identifier_in_namespace) AS cl_uri
   FROM pgwar.entity_preview ep,
    che.class cl,
    che.class_version cv,
    che.namespace n,
    che.namespace n1
  WHERE ((ep.fk_project = 2270010) AND (cl.pk_class = ep.fk_class) AND (cv.fk_class = ep.fk_class) AND (n.pk_namespace = cv.fk_namespace_for_version) AND (n1.pk_namespace = n.fk_is_version_of))
  ORDER BY ep.pk_entity
  WITH NO DATA;


--
-- TOC entry 1348 (class 1259 OID 1712200)
-- Name: v_ontop_2270010_statement_preview; Type: MATERIALIZED VIEW; Schema: rdf; Owner: -
--

CREATE MATERIALIZED VIEW rdf.v_ontop_2270010_statement_preview AS
 SELECT DISTINCT ps.pk_entity,
    ps.fk_subject_info,
    ps.fk_object_info,
    ps.fk_property,
    ps.object_label,
    concat(n1.namespace_uri, p.identifier_in_namespace) AS p_uri
   FROM pgwar.project_statements ps,
    che.property p,
    che.property_version pv,
    che.namespace n,
    che.namespace n1
  WHERE ((ps.fk_project = 2270010) AND (ps.fk_property <> ALL (ARRAY[148, 150, 151])) AND (p.pk_property = ps.fk_property) AND (pv.fk_property = ps.fk_property) AND (n.pk_namespace = pv.fk_namespace_for_version) AND (n1.pk_namespace = n.fk_is_version_of))
  WITH NO DATA;


--
-- TOC entry 1349 (class 1259 OID 1712219)
-- Name: v_ontop_2270010_statement_value_preview; Type: MATERIALIZED VIEW; Schema: rdf; Owner: -
--

CREATE MATERIALIZED VIEW rdf.v_ontop_2270010_statement_value_preview AS
 SELECT DISTINCT ps.pk_entity,
    ps.fk_subject_info,
    ps.fk_object_info,
    ps.fk_property,
    ps.object_label,
    concat(n1.namespace_uri, p.identifier_in_namespace) AS p_uri
   FROM pgwar.project_statements ps,
    che.property p,
    che.property_version pv,
    che.namespace n,
    che.namespace n1
  WHERE ((ps.fk_project = 2270010) AND (ps.fk_property = ANY (ARRAY[148, 150, 151])) AND (p.pk_property = ps.fk_property) AND (pv.fk_property = ps.fk_property) AND (n.pk_namespace = pv.fk_namespace_for_version) AND (n1.pk_namespace = n.fk_is_version_of))
  WITH NO DATA;


--
-- TOC entry 1325 (class 1259 OID 1456350)
-- Name: v_ontop_6619613_entity_preview; Type: VIEW; Schema: rdf; Owner: -
--

CREATE VIEW rdf.v_ontop_6619613_entity_preview AS
 SELECT pk_entity,
    entity_label,
    fk_class,
    class_label
   FROM pgwar.entity_preview ep
  WHERE (fk_project = 6619613);


--
-- TOC entry 1326 (class 1259 OID 1456362)
-- Name: v_ontop_6619613_statement_preview; Type: VIEW; Schema: rdf; Owner: -
--

CREATE VIEW rdf.v_ontop_6619613_statement_preview AS
 SELECT DISTINCT pk_entity,
    fk_subject_info,
    fk_object_info,
    fk_property,
    object_label
   FROM pgwar.project_statements ps
  WHERE (fk_project = 6619613);


--
-- TOC entry 1354 (class 1259 OID 2412976)
-- Name: v_ontop_entity_preview; Type: VIEW; Schema: rdf; Owner: -
--

CREATE VIEW rdf.v_ontop_entity_preview AS
 SELECT ep.pk_entity,
    ep.entity_label,
    (cls.top_level_namespace_uri || cls.identifier_in_namespace) AS class_uri,
    ep.fk_project
   FROM (pgwar.entity_preview ep
     JOIN che.class_with_namespace cls ON ((ep.fk_class = cls.pk_class)));


--
-- TOC entry 1352 (class 1259 OID 2285971)
-- Name: v_ontop_entity_preview_2270010; Type: VIEW; Schema: rdf; Owner: -
--

CREATE VIEW rdf.v_ontop_entity_preview_2270010 AS
 SELECT ep.pk_entity,
    ep.entity_label,
    (cls.top_level_namespace_uri || cls.identifier_in_namespace) AS class_uri
   FROM (pgwar.entity_preview ep
     JOIN che.class_with_namespace cls ON ((ep.fk_class = cls.pk_class)))
  WHERE (ep.fk_project = 2270010);


--
-- TOC entry 1353 (class 1259 OID 2412944)
-- Name: v_ontop_project_statements; Type: VIEW; Schema: rdf; Owner: -
--

CREATE VIEW rdf.v_ontop_project_statements AS
 SELECT ps.pk_entity,
    ps.fk_project,
    ps.fk_subject_info,
    ps.fk_property,
    ps.fk_object_info,
    ps.fk_object_tables_cell,
    ps.ord_num_of_domain,
    ps.ord_num_of_range,
        CASE
            WHEN (ps.fk_property = ANY (ARRAY[71, 72, 150, 151, 152, 153])) THEN
            CASE
                WHEN ((ps.object_label)::text ~~ '%(1 day)%'::text) THEN ("substring"((ps.object_label)::text, '(-?\d{4}-\d{2}-\d{2})'::text))::character varying
                WHEN ((ps.object_label)::text ~~ '%(1 month)%'::text) THEN ("substring"((ps.object_label)::text, '(-?\d{4}-\d{2})'::text))::character varying
                WHEN ((ps.object_label)::text ~~ '%(1 year)%'::text) THEN ("substring"((ps.object_label)::text, '(-?\d{4})'::text))::character varying
                ELSE ps.object_label
            END
            ELSE ps.object_label
        END AS object_label,
    ps.tmsp_last_modification,
    prop.property_standard_label
   FROM (pgwar.project_statements ps
     JOIN che.property_with_namespace prop ON ((ps.fk_property = prop.pk_property)));


--
-- TOC entry 1356 (class 1259 OID 2545716)
-- Name: v_ontop_project_statements_places; Type: VIEW; Schema: rdf; Owner: -
--

CREATE VIEW rdf.v_ontop_project_statements_places AS
 SELECT ps.fk_project,
    ps.fk_subject_info,
    ps.fk_property,
    (prop.top_level_namespace_uri || prop.identifier_in_namespace) AS property_uri,
    prop.property_standard_label,
    ps.fk_object_info,
    p.geo_point
   FROM ((pgwar.project_statements ps
     JOIN information.place p ON ((p.pk_entity = ps.fk_object_info)))
     JOIN che.property_with_namespace prop ON ((ps.fk_property = prop.pk_property)));


--
-- TOC entry 8720 (class 2604 OID 1456629)
-- Name: class_old pk_class; Type: DEFAULT; Schema: rdf; Owner: -
--

ALTER FOREIGN TABLE ONLY rdf.class_old ALTER COLUMN pk_class SET DEFAULT nextval('rdf.class_pk_class_seq'::regclass);


--
-- TOC entry 8734 (class 2604 OID 1462652)
-- Name: class_version pk_class_version; Type: DEFAULT; Schema: rdf; Owner: -
--

ALTER FOREIGN TABLE ONLY rdf.class_version ALTER COLUMN pk_class_version SET DEFAULT nextval('rdf.class_version_pk_class_version_seq'::regclass);


--
-- TOC entry 8729 (class 2604 OID 1462632)
-- Name: namespace pk_namespace; Type: DEFAULT; Schema: rdf; Owner: -
--

ALTER FOREIGN TABLE ONLY rdf.namespace ALTER COLUMN pk_namespace SET DEFAULT nextval('rdf.namespace_pk_namespace_seq'::regclass);


--
-- TOC entry 8724 (class 2604 OID 1462611)
-- Name: property pk_property; Type: DEFAULT; Schema: rdf; Owner: -
--

ALTER FOREIGN TABLE ONLY rdf.property ALTER COLUMN pk_property SET DEFAULT nextval('rdf.property_pk_property_seq'::regclass);


--
-- TOC entry 8736 (class 2604 OID 1462658)
-- Name: property_version pk_property_version; Type: DEFAULT; Schema: rdf; Owner: -
--

ALTER FOREIGN TABLE ONLY rdf.property_version ALTER COLUMN pk_property_version SET DEFAULT nextval('rdf.property_version_pk_property_version_seq'::regclass);


-- Completed on 2026-01-16 16:05:43

--
-- PostgreSQL database dump complete
--

