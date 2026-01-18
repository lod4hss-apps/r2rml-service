--
-- PostgreSQL database dump
--

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.3

-- Started on 2026-01-16 16:07:02

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
-- TOC entry 21 (class 2615 OID 946533)
-- Name: pgwar; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgwar;


--
-- TOC entry 2369 (class 1255 OID 948070)
-- Name: after_delete_object_info(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_delete_object_info() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
    DELETE FROM pgwar.statement 
    WHERE fk_object_info = OLD.pk_entity;
    RETURN OLD;
END;
$$;


--
-- TOC entry 2370 (class 1255 OID 948071)
-- Name: after_delete_object_tables_cell(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_delete_object_tables_cell() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
    DELETE FROM pgwar.statement 
    WHERE fk_object_tables_cell = OLD.pk_cell;
    RETURN OLD;
END;
$$;


--
-- TOC entry 2371 (class 1255 OID 948072)
-- Name: after_delete_pgw_statement(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_delete_pgw_statement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM pgwar.project_statements
    WHERE pk_entity = OLD.pk_entity;
    RETURN NEW;
END;
$$;


--
-- TOC entry 2372 (class 1255 OID 948073)
-- Name: after_delete_resource(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_delete_resource() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM pgwar.entity_preview
    WHERE pk_entity = OLD.pk_entity;
    RETURN NEW;
END;
$$;


--
-- TOC entry 2373 (class 1255 OID 948074)
-- Name: after_delete_statement(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_delete_statement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM pgwar.statement
    WHERE pk_entity = OLD.pk_entity;
    
    RETURN OLD;
END;
$$;


--
-- TOC entry 2374 (class 1255 OID 948075)
-- Name: after_modify_info_proj_rel(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_modify_info_proj_rel() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    info_proj_rel projects.info_proj_rel;
    is_upsert boolean;
    statement pgwar.statement;
BEGIN
    info_proj_rel := COALESCE(NEW,OLD);
    
    SELECT (NEW.is_in_project IS TRUE AND TG_OP != 'DELETE') INTO is_upsert;
    
    PERFORM pgwar.update_from_info_proj_rel(info_proj_rel, is_upsert);

    RETURN NEW;
END;
$$;


--
-- TOC entry 2375 (class 1255 OID 948076)
-- Name: after_upsert_object_info(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_upsert_object_info() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
    PERFORM pgwar.upsert_statement((stmt.pk_entity,stmt.fk_subject_info,stmt.fk_property,stmt.fk_object_info,stmt.fk_object_tables_cell,
        pgwar.get_value_label(NEW),
        pgwar.get_value_object(NEW)
      )::pgwar.statement)
    FROM information.statement stmt
    WHERE fk_object_info = NEW.pk_entity;
    RETURN NEW;
END;
$$;


--
-- TOC entry 2376 (class 1255 OID 948077)
-- Name: after_upsert_object_tables_cell(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_upsert_object_tables_cell() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
    PERFORM pgwar.upsert_statement((stmt.pk_entity,stmt.fk_subject_info,stmt.fk_property,stmt.fk_object_info,stmt.fk_object_tables_cell,
        pgwar.get_value_label(NEW),
        pgwar.get_value_object(NEW)
      )::pgwar.statement)
    FROM information.statement stmt
    WHERE fk_object_tables_cell = NEW.pk_cell;
    RETURN NEW;
END;
$$;


--
-- TOC entry 2377 (class 1255 OID 948078)
-- Name: after_upsert_pgw_statement(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_upsert_pgw_statement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- if it is in at least one project ...
    IF EXISTS(
        SELECT
            pk_entity
        FROM
            projects.info_proj_rel
        WHERE
            fk_entity = NEW.pk_entity
          AND is_in_project IS TRUE) THEN
        -- ... insert missing project statements or update existing, in case statement differs
        PERFORM
            pgwar.upsert_project_statements((
                NEW.pk_entity,
                fk_project,
                NEW.fk_subject_info,
                NEW.fk_property,
                NEW.fk_object_info,
                NEW.fk_object_tables_cell,
                ord_num_of_domain::numeric,
                ord_num_of_range::numeric,
                NEW.object_label,
                NEW.object_value,
                NULL)::pgwar.project_statements
            )
        FROM
            projects.info_proj_rel
        WHERE
            fk_entity = NEW.pk_entity
          AND is_in_project IS TRUE;
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 2378 (class 1255 OID 948079)
-- Name: after_upsert_resource(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_upsert_resource() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- insert project entities
    INSERT INTO pgwar.entity_preview(pk_entity, fk_project, fk_class, tmsp_fk_class_modification)
    SELECT newtab.pk_entity, ipr.fk_project, newtab.fk_class, CURRENT_TIMESTAMP
    FROM newtab,
         projects.info_proj_rel ipr
    WHERE ipr.fk_entity = newtab.pk_entity
    AND ipr.is_in_project IS TRUE
    ON CONFLICT(pk_entity, fk_project)
        DO UPDATE SET
            -- ... or update the fk_class
            fk_class = EXCLUDED.fk_class,
            tmsp_fk_class_modification = CURRENT_TIMESTAMP
        WHERE
            -- ... where it is distinct from previous value
            entity_preview.fk_class IS DISTINCT FROM EXCLUDED.fk_class;

    -- insert community entities
    INSERT INTO pgwar.entity_preview(pk_entity, fk_project, fk_class, tmsp_fk_class_modification)
    SELECT DISTINCT ON (newtab.pk_entity) 
        newtab.pk_entity, 0, newtab.fk_class, CURRENT_TIMESTAMP
    FROM newtab,
         projects.info_proj_rel ipr
    WHERE ipr.fk_entity = newtab.pk_entity
    AND ipr.is_in_project IS TRUE
    ON CONFLICT(pk_entity, fk_project)
        DO UPDATE SET
            -- ... or update the fk_class
            fk_class = EXCLUDED.fk_class,
            tmsp_fk_class_modification = CURRENT_TIMESTAMP
        WHERE
            -- ... where it is distinct from previous value
            entity_preview.fk_class IS DISTINCT FROM EXCLUDED.fk_class;

    -- delete potentially unallowed community entities
    DELETE FROM pgwar.entity_preview ep
    USING newtab
    WHERE (newtab.community_visibility ->> 'toolbox')::bool IS FALSE
    AND newtab.pk_entity = ep.pk_entity
    AND ep.fk_project = 0;

    RETURN NEW;
END;
$$;


--
-- TOC entry 2379 (class 1255 OID 948080)
-- Name: after_upsert_statement(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.after_upsert_statement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM pgwar.update_from_statement(NEW);

    RETURN NEW;
END;
$$;


--
-- TOC entry 2380 (class 1255 OID 948081)
-- Name: entity_preview_ts_vector(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.entity_preview_ts_vector() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN NEW.ts_vector = (
                SELECT
                setweight(to_tsvector(coalesce(NEW.entity_label, '')), 'A') ||
                setweight(to_tsvector(coalesce(NEW.type_label, '')), 'B') ||
                setweight(to_tsvector(coalesce(NEW.class_label, '')), 'B') ||
                setweight(to_tsvector(coalesce(NEW.full_text, '')), 'C')
            );
        RETURN NEW;
        END;            
$$;


--
-- TOC entry 2381 (class 1255 OID 948082)
-- Name: entity_previews_notify_update(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.entity_previews_notify_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    notification text;
BEGIN


SELECT DISTINCT new_table.tmsp_last_modification::text into notification
FROM new_table,
       old_table
WHERE  new_table.pk_entity = old_table.pk_entity
AND    new_table.fk_project = old_table.fk_project
AND    new_table.tmsp_last_modification is not null
AND (
  new_table.fk_class IS DISTINCT FROM old_table.fk_class OR
  new_table.class_label IS DISTINCT FROM old_table.class_label OR
  new_table.entity_label IS DISTINCT FROM old_table.entity_label OR
  new_table.entity_type IS DISTINCT FROM old_table.entity_type OR
  new_table.type_label IS DISTINCT FROM old_table.type_label OR
  new_table.fk_type IS DISTINCT FROM old_table.fk_type
)
LIMIT 1;

  if notification is not null then
                PERFORM pg_notify('entity_previews_updated'::text, notification);
  end if;

RETURN NEW;
END;
$$;


--
-- TOC entry 2382 (class 1255 OID 948083)
-- Name: entity_previews_notify_upsert(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.entity_previews_notify_upsert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    notification text;
BEGIN


    SELECT DISTINCT tmsp_last_modification::text into notification
    FROM new_table
    WHERE tmsp_last_modification is not null
    LIMIT 1;

    IF notification IS NOT NULL THEN
        PERFORM pg_notify('entity_previews_updated'::text, notification);
    END IF;

RETURN NEW;
END;
$$;


--
-- TOC entry 2383 (class 1255 OID 948084)
-- Name: field_change_notify_upsert(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.field_change_notify_upsert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    item json;
BEGIN
    FOR item in SELECT row_to_json(new_table) FROM new_table
        LOOP
            PERFORM pg_notify('field_change'::text, item::text);
        end LOOP;
    RETURN NEW;
END;
$$;


--
-- TOC entry 2384 (class 1255 OID 948085)
-- Name: get_and_update_project_entity_label(integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_and_update_project_entity_label(entity_id integer, project_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS(
        SELECT
            pk_entity
        FROM
            pgwar.entity_preview
        WHERE
            pk_entity = entity_id
            AND fk_project = project_id) THEN
         PERFORM pgwar.update_entity_label_of_entity_preview(entity_id, project_id, pgwar.get_project_entity_label(entity_id, project_id));
     END IF;
END;
$$;


--
-- TOC entry 2385 (class 1255 OID 948086)
-- Name: get_entity_label_config(integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_entity_label_config(class_id integer, project_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    label_config jsonb;
BEGIN
   
    SELECT config INTO label_config
    FROM projects.entity_label_config 
    WHERE fk_class = class_id
    AND fk_project = project_id;

    IF label_config IS NULL THEN
        SELECT config INTO label_config
        FROM projects.entity_label_config 
        WHERE fk_class = class_id
        AND fk_project = 375669;
    END IF;  
    
    RETURN label_config;
END;
$$;


--
-- TOC entry 2386 (class 1255 OID 948087)
-- Name: get_label_of_incoming_field(integer, integer, integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_label_of_incoming_field(entity_id integer, project_id integer, property_id integer, limit_count integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    label text;
BEGIN
    SELECT string_agg(labels.label, ', ') INTO label 
    FROM pgwar.get_target_labels_of_incoming_field(entity_id, project_id, property_id, limit_count) AS labels;
    RETURN label;
END;
$$;


--
-- TOC entry 2387 (class 1255 OID 948088)
-- Name: get_label_of_outgoing_field(integer, integer, integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_label_of_outgoing_field(entity_id integer, project_id integer, property_id integer, limit_count integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    label text;
BEGIN
    SELECT string_agg(labels.label, ', ') INTO label 
    FROM pgwar.get_target_labels_of_outgoing_field(entity_id, project_id, property_id, limit_count) AS labels;
    RETURN label;
END;
$$;


--
-- TOC entry 2388 (class 1255 OID 948089)
-- Name: get_outdated_full_texts(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_outdated_full_texts(max_limit integer) RETURNS TABLE(pk_entity integer, fk_project integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_set RECORD;
    result_set RECORD;
    pair_count int;
    updated_count int;
BEGIN
    pair_count := 0;

    -- Drop the temporary table if it already exists within transaction
    DROP TABLE IF EXISTS temp_unique_pairs;
    
    -- Initialize the temporary table to store unique pairs
    CREATE TEMP TABLE temp_unique_pairs (
        pk_entity integer,
        fk_project integer,
        CONSTRAINT unique_pairs_pk_project UNIQUE (pk_entity, fk_project)
    ) ON COMMIT DROP;

    -- Execute functions sequentially and add unique pairs
    FOR current_set IN SELECT unnest(array[
        'pgwar.get_outdated_full_texts_in_subjects_of_stmt',
        'pgwar.get_outdated_full_texts_in_objects_of_stmt',
        'pgwar.get_outdated_full_texts_in_subjects_of_stmt_del',
        'pgwar.get_outdated_full_texts_in_objects_of_stmt_del',
        'pgwar.get_outdated_full_texts_in_subjects_of_stmt_by_dfh_prop',
        'pgwar.get_outdated_full_texts_in_objects_of_stmt_by_dfh_prop'
    ]) AS function_name
    LOOP
        EXECUTE 'INSERT INTO temp_unique_pairs (pk_entity, fk_project) ' ||
                'SELECT pk_entity, fk_project ' ||
                'FROM ' || current_set.function_name || '(' || max_limit || ') ' ||
                'ON CONFLICT DO NOTHING';

        -- Update the pair count
        SELECT COUNT(*) INTO pair_count FROM temp_unique_pairs;
				
        -- Check if the limit has been reached
        IF pair_count >= max_limit THEN
            EXIT;
        END IF;
    END LOOP;

    RETURN QUERY
	SELECT t.pk_entity, t.fk_project
    FROM temp_unique_pairs t
	LIMIT max_limit;
    
END;
$$;


--
-- TOC entry 2389 (class 1255 OID 948090)
-- Name: get_outdated_full_texts_in_objects_of_stmt(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_outdated_full_texts_in_objects_of_stmt(max_limit integer) RETURNS TABLE(pk_entity integer, fk_project integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    -- find objects of modified statements
    SELECT DISTINCT s.pk_entity, s.fk_project
    FROM (
        SELECT pstmt.fk_object_info as pk_entity, pstmt.fk_project
        FROM pgwar.v_statements_combined pstmt
        LEFT JOIN pgwar.entity_full_text ftxt 
            ON pstmt.fk_object_info = ftxt.pk_entity
            AND pstmt.fk_project = ftxt.fk_project
        WHERE pstmt.object_value IS NULL
        AND (ftxt.tmsp_last_modification IS NULL
        OR ftxt.tmsp_last_modification < pstmt.tmsp_last_modification)
        ORDER BY pstmt.tmsp_last_modification DESC
        LIMIT max_limit
    ) AS s;
END;
$$;


--
-- TOC entry 2390 (class 1255 OID 948091)
-- Name: get_outdated_full_texts_in_objects_of_stmt_by_dfh_prop(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_outdated_full_texts_in_objects_of_stmt_by_dfh_prop(max_limit integer) RETURNS TABLE(pk_entity integer, fk_project integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
BEGIN
    -- Step 1: Retrieve filtered ftxt records
    CREATE TEMP TABLE tmp_filtered_ftxt AS
    SELECT ftxt.pk_entity, ftxt.fk_project
    FROM pgwar.entity_full_text ftxt
             JOIN data_for_history.api_property dfh_prop
                  ON ftxt.tmsp_last_modification < dfh_prop.tmsp_last_dfh_update;

    -- Step 2: Use the result from the temporary table to find outdated full texts
    FOR rec IN
        SELECT DISTINCT
            pstmt.fk_object_info AS pk_entity,
            pstmt.fk_project,
            dfh_prop.tmsp_last_modification  -- Include this in the SELECT list for ordering
        FROM
            pgwar.v_statements_combined pstmt
                JOIN tmp_filtered_ftxt ftxt
                     ON pstmt.fk_object_info = ftxt.pk_entity
                         AND pstmt.fk_project = ftxt.fk_project
                JOIN data_for_history.api_property dfh_prop
                     ON dfh_prop.dfh_pk_property = pstmt.fk_property
        WHERE pstmt.object_value IS NULL
        ORDER BY dfh_prop.tmsp_last_modification DESC
        LIMIT max_limit
        LOOP
            -- Assign values to the OUT parameters
            pk_entity := rec.pk_entity;
            fk_project := rec.fk_project;

            -- Return the record
            RETURN NEXT;
        END LOOP;

    -- Clean up the temporary table
    DROP TABLE tmp_filtered_ftxt;

END;
$$;


--
-- TOC entry 2391 (class 1255 OID 948092)
-- Name: get_outdated_full_texts_in_objects_of_stmt_del(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_outdated_full_texts_in_objects_of_stmt_del(max_limit integer) RETURNS TABLE(pk_entity integer, fk_project integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    -- find objects of deleted statements
    SELECT DISTINCT s.pk_entity, s.fk_project
    FROM (
        SELECT pstmt.fk_object_info as pk_entity, pstmt.fk_project
        FROM pgwar.v_statements_deleted_combined pstmt
        LEFT JOIN pgwar.entity_full_text ftxt 
            ON pstmt.fk_object_info = ftxt.pk_entity
            AND pstmt.fk_project = ftxt.fk_project
        WHERE  pstmt.object_value IS NULL
        AND (ftxt.tmsp_last_modification IS NULL
            OR ftxt.tmsp_last_modification < pstmt.tmsp_deletion)
        ORDER BY pstmt.tmsp_deletion DESC
        LIMIT max_limit
    ) AS s;
END;
$$;


--
-- TOC entry 2392 (class 1255 OID 948093)
-- Name: get_outdated_full_texts_in_subjects_of_stmt(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_outdated_full_texts_in_subjects_of_stmt(max_limit integer) RETURNS TABLE(pk_entity integer, fk_project integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    -- find subjects of modified statements
    SELECT DISTINCT s.pk_entity, s.fk_project
    FROM (
        SELECT pstmt.fk_subject_info as pk_entity, pstmt.fk_project
        FROM pgwar.v_statements_combined pstmt
        LEFT JOIN pgwar.entity_full_text ftxt 
            ON pstmt.fk_subject_info = ftxt.pk_entity
            AND pstmt.fk_project = ftxt.fk_project
        WHERE ftxt.tmsp_last_modification IS NULL
        OR ftxt.tmsp_last_modification < pstmt.tmsp_last_modification
        ORDER BY pstmt.tmsp_last_modification DESC
        LIMIT max_limit
    ) AS s;
END;
$$;


--
-- TOC entry 2393 (class 1255 OID 948094)
-- Name: get_outdated_full_texts_in_subjects_of_stmt_by_dfh_prop(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_outdated_full_texts_in_subjects_of_stmt_by_dfh_prop(max_limit integer) RETURNS TABLE(pk_entity integer, fk_project integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
BEGIN
    -- Step 1: Retrieve filtered ftxt records
    CREATE TEMP TABLE tmp_filtered_ftxt AS
    SELECT ftxt.pk_entity, ftxt.fk_project
    FROM pgwar.entity_full_text ftxt
    JOIN data_for_history.api_property dfh_prop
        ON ftxt.tmsp_last_modification < dfh_prop.tmsp_last_dfh_update;

    -- Step 2: Use the result from the temporary table to find outdated full texts
    FOR rec IN
        SELECT DISTINCT
            pstmt.fk_subject_info AS pk_entity,
            pstmt.fk_project,
            dfh_prop.tmsp_last_modification  -- Include this in the SELECT list for ordering
        FROM
            pgwar.v_statements_combined pstmt
                JOIN tmp_filtered_ftxt ftxt
                     ON pstmt.fk_subject_info = ftxt.pk_entity
                         AND pstmt.fk_project = ftxt.fk_project
                JOIN data_for_history.api_property dfh_prop
                     ON dfh_prop.dfh_pk_property = pstmt.fk_property
        ORDER BY dfh_prop.tmsp_last_modification DESC
        LIMIT max_limit
        LOOP
            -- Assign values to the OUT parameters
            pk_entity := rec.pk_entity;
            fk_project := rec.fk_project;

            -- Return the record
            RETURN NEXT;
        END LOOP;

    -- Clean up the temporary table
    DROP TABLE tmp_filtered_ftxt;

END;
$$;


--
-- TOC entry 2394 (class 1255 OID 948095)
-- Name: get_outdated_full_texts_in_subjects_of_stmt_del(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_outdated_full_texts_in_subjects_of_stmt_del(max_limit integer) RETURNS TABLE(pk_entity integer, fk_project integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    -- find subjects of deleted statements
    SELECT DISTINCT s.pk_entity, s.fk_project
    FROM (
        SELECT pstmt.fk_subject_info as pk_entity, pstmt.fk_project
        FROM pgwar.v_statements_deleted_combined pstmt
        LEFT JOIN pgwar.entity_full_text ftxt 
            ON pstmt.fk_subject_info = ftxt.pk_entity
            AND pstmt.fk_project = ftxt.fk_project
        WHERE ftxt.tmsp_last_modification IS NULL
        OR ftxt.tmsp_last_modification < pstmt.tmsp_deletion
        ORDER BY pstmt.tmsp_deletion DESC
        LIMIT max_limit
    ) AS s;
END;
$$;


--
-- TOC entry 2395 (class 1255 OID 948096)
-- Name: get_project_entity_label(integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_project_entity_label(entity_id integer, project_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    class_id int;
    label text;
BEGIN
    -- get class_id
    SELECT fk_class INTO class_id
    FROM information.resource
    WHERE pk_entity = entity_id;   
    -- get label
    SELECT pgwar.get_project_entity_label(entity_id, project_id, class_id) INTO label;

    RETURN label;
END;
$$;


--
-- TOC entry 2396 (class 1255 OID 948097)
-- Name: get_project_entity_label(integer, integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_project_entity_label(entity_id integer, project_id integer, class_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    label_config jsonb;
    label text;
BEGIN
    -- get label config
    SELECT pgwar.get_entity_label_config(class_id, project_id) INTO label_config;   
    -- get label
    SELECT pgwar.get_project_entity_label(entity_id, project_id, label_config) INTO label;

    RETURN label;
END;
$$;


--
-- TOC entry 2397 (class 1255 OID 948098)
-- Name: get_project_entity_label(integer, integer, jsonb); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_project_entity_label(entity_id integer, project_id integer, label_config jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    label text;
BEGIN
    -- join labels of fields
	SELECT substring(string_agg(
        -- get label per field
        pgwar.get_target_label_of_field(entity_id, project_id, part->'field'),
        -- separator
         ', '
    ), 1, 100) INTO label
	FROM 
    -- expand fields
    jsonb_array_elements(label_config->'labelParts') part;

    RETURN label;
END;
$$;


--
-- TOC entry 2398 (class 1255 OID 948099)
-- Name: get_project_full_text(integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_project_full_text(project_id integer, entity_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    full_text text := '';
    lang_code text;
    fk_property int;
    field_string text;
    label text;
BEGIN
    -- get language code of the project language
    lang_code := pgwar.get_project_lang_code(project_id);

    -- Get distinct fk_property values into a temporary table or array
    FOR fk_property IN
        SELECT DISTINCT stmt.fk_property
        FROM pgwar.v_statements_combined AS stmt
        WHERE (fk_subject_info = entity_id OR fk_object_info = entity_id)
          AND fk_project = project_id
        LOOP
            -- Get field_string for outgoing fields
            SELECT pgwar.get_label_of_outgoing_field(entity_id, project_id, fk_property, 5) INTO label;
            IF label IS NOT NULL THEN
                SELECT
                    concat(
                        pgwar.get_property_label(fk_property, lang_code),
                        ': ',
                        label
                    ) INTO field_string;
            ELSE
                SELECT pgwar.get_label_of_incoming_field(entity_id, project_id, fk_property, 5) INTO label;
                IF label IS NOT NULL THEN
                    SELECT
                        concat(
                           pgwar.get_property_inverse_label(fk_property, lang_code),
                           ': ',
                           pgwar.get_label_of_incoming_field(entity_id, project_id, fk_property, 5)
                       ) INTO field_string;
                END IF;

            END IF;

            -- Concatenate field string if not null
            IF field_string IS NOT NULL THEN
                full_text := full_text || field_string || '\n ';
            END IF;
        END LOOP;

    RETURN full_text;
END;
$$;


--
-- TOC entry 2399 (class 1255 OID 948100)
-- Name: get_project_lang_code(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_project_lang_code(project_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    lang_code text;
BEGIN
    -- get language code of the project language
    SELECT trim(iso6391) INTO lang_code
    FROM information.language lang,
         projects.project pro
    WHERE pro.pk_entity = project_id
    AND pro.fk_language = lang.pk_entity
    LIMIT 1;

    RETURN lang_code;
    
END;
$$;


--
-- TOC entry 2400 (class 1255 OID 948101)
-- Name: get_property_inverse_label(integer, text); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_property_inverse_label(property_id integer, lang_code text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    label text;
BEGIN
    -- get newest inverse label in requested language
    SELECT dfh_property_inverse_label INTO label
    FROM data_for_history.api_property
    WHERE dfh_pk_property = property_id
    AND dfh_property_label_language = lang_code
    ORDER BY tmsp_last_dfh_update DESC
    LIMIT 1;

    IF label IS NOT NULL THEN RETURN label; END IF;

    -- get newest inverse label in english
    SELECT dfh_property_inverse_label INTO label
    FROM data_for_history.api_property
    WHERE dfh_pk_property = property_id
    AND dfh_property_label_language = 'en'
    ORDER BY tmsp_last_dfh_update DESC
    LIMIT 1;

    RETURN label;
    
END;
$$;


--
-- TOC entry 2401 (class 1255 OID 948102)
-- Name: get_property_label(integer, text); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_property_label(property_id integer, lang_code text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    label text;
BEGIN
    -- get newest label in requested language
    SELECT dfh_property_label INTO label
    FROM data_for_history.api_property
    WHERE dfh_pk_property = property_id
    AND dfh_property_label_language = lang_code
    ORDER BY tmsp_last_dfh_update DESC
    LIMIT 1;

    IF label IS NOT NULL THEN RETURN label; END IF;

    -- get newest label in english
    SELECT dfh_property_label INTO label
    FROM data_for_history.api_property
    WHERE dfh_pk_property = property_id
    AND dfh_property_label_language = 'en'
    ORDER BY tmsp_last_dfh_update DESC
    LIMIT 1;

    RETURN label;
    
END;
$$;


--
-- TOC entry 2402 (class 1255 OID 948103)
-- Name: get_target_label_of_field(integer, integer, jsonb); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_target_label_of_field(entity_id integer, project_id integer, field jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    is_outgoing bool;
    property_id int;
    limit_count int;
    label text;
BEGIN
	is_outgoing := (field->'isOutgoing')::bool;
    property_id := (field->'fkProperty')::int;
	limit_count := (field->'nrOfStatementsInLabel')::int;


    IF is_outgoing IS TRUE THEN
        SELECT pgwar.get_label_of_outgoing_field(entity_id, project_id, property_id, limit_count) INTO label;
    ELSE
        SELECT pgwar.get_label_of_incoming_field(entity_id, project_id, property_id, limit_count) INTO label;
    END IF;

    RETURN label;
END;
$$;


--
-- TOC entry 2403 (class 1255 OID 948104)
-- Name: get_target_labels_of_incoming_field(integer, integer, integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_target_labels_of_incoming_field(entity_id integer, project_id integer, property_id integer, limit_count integer) RETURNS TABLE(label character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    labels VARCHAR[];
    pstmt RECORD;
    proj_entity_label VARCHAR;
    comm_entity_label VARCHAR;
BEGIN
    labels := '{}';

    FOR pstmt IN
        SELECT *
        FROM pgwar.v_statements_combined
        WHERE
            fk_object_info = entity_id
            AND fk_project = project_id
            AND fk_property = property_id
        ORDER BY ord_num_of_domain ASC, tmsp_last_modification DESC
        LIMIT limit_count
    LOOP
        SELECT entity_label INTO proj_entity_label
        FROM pgwar.entity_preview
        WHERE fk_project = project_id AND pk_entity = pstmt.fk_subject_info;

        IF proj_entity_label IS NOT NULL THEN
            labels := array_append(labels, proj_entity_label);
        ELSE
            SELECT entity_label INTO comm_entity_label
            FROM pgwar.entity_preview
            WHERE fk_project = 0 AND pk_entity = pstmt.fk_subject_info;

            IF comm_entity_label IS NOT NULL THEN
                labels := array_append(labels, comm_entity_label);
            END IF;
        END IF;
    END LOOP;

    RETURN QUERY
    SELECT unnest(labels);
END;
$$;


--
-- TOC entry 2404 (class 1255 OID 948105)
-- Name: get_target_labels_of_outgoing_field(integer, integer, integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_target_labels_of_outgoing_field(entity_id integer, project_id integer, property_id integer, limit_count integer) RETURNS TABLE(label character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    labels VARCHAR[];
    pstmt RECORD;
    obj_label VARCHAR;
    proj_entity_label VARCHAR;
    comm_entity_label VARCHAR;
BEGIN
    labels := '{}';

    FOR pstmt IN
        SELECT *
        FROM pgwar.v_statements_combined
        WHERE
            fk_subject_info = entity_id
            AND fk_project = project_id
            AND fk_property = property_id
        ORDER BY ord_num_of_range ASC, tmsp_last_modification DESC
        LIMIT limit_count
    LOOP
        obj_label := pstmt.object_label;

        IF obj_label IS NOT NULL THEN
            labels := array_append(labels, obj_label);
        ELSE
            SELECT entity_label INTO proj_entity_label
            FROM pgwar.entity_preview
            WHERE fk_project = project_id AND pk_entity = pstmt.fk_object_info;

            IF proj_entity_label IS NOT NULL THEN
                labels := array_append(labels, proj_entity_label);
            ELSE
                SELECT entity_label INTO comm_entity_label
                FROM pgwar.entity_preview
                WHERE fk_project = 0 AND pk_entity = pstmt.fk_object_info;

                IF comm_entity_label IS NOT NULL THEN
                    labels := array_append(labels, comm_entity_label);
                END IF;
            END IF;
        END IF;
    END LOOP;

    RETURN QUERY
    SELECT unnest(labels);
END;
$$;


--
-- TOC entry 2405 (class 1255 OID 948120)
-- Name: get_value_label(information.appellation); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_label(appe information.appellation) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN appe.string;

END;

$$;


--
-- TOC entry 2406 (class 1255 OID 948128)
-- Name: get_value_label(information.dimension); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_label(dimension information.dimension) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN dimension.numeric_value;

END;

$$;


--
-- TOC entry 2407 (class 1255 OID 948137)
-- Name: get_value_label(information.lang_string); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_label(lang_string information.lang_string) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN lang_string.string;

END;

$$;


--
-- TOC entry 2408 (class 1255 OID 948145)
-- Name: get_value_label(information.language); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_label(language information.language) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN coalesce(
        language .notes,
        trim(language .pk_language)
    );

END;

$$;


--
-- TOC entry 2409 (class 1255 OID 948153)
-- Name: get_value_label(information.place); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_label(place information.place) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN format(
        'WGS84: %s°, %s°',
        ST_X(place.geo_point::geometry),
        ST_Y(place.geo_point::geometry)
    );

END;

$$;


--
-- TOC entry 2410 (class 1255 OID 948154)
-- Name: get_value_label(information.time_primitive); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_label(time_primitive information.time_primitive) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE date_string varchar;

BEGIN IF time_primitive.calendar = 'gregorian' THEN -- generate gregorian calendar string
SELECT to_char(
        (('J' || time_primitive.julian_day)::timestamp),
        'YYYY-MM-DD'
    ) INTO date_string;

ELSE -- generate julian calendar string
SELECT concat(
        to_char(t.year, 'fm0000'),
        '-',
        to_char(t.month, 'fm00'),
        '-',
        to_char(t.day, 'fm00')
    ) INTO date_string
FROM commons.julian_cal__year_month_day(time_primitive.julian_day) t;

END IF;

-- add duration
RETURN concat(
    date_string,
    ' (',
    time_primitive.duration,
    ')'
);

END;

$$;


--
-- TOC entry 2411 (class 1255 OID 948165)
-- Name: get_value_label(tables.cell); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_label(cell tables.cell) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN coalesce(cell.string_value, cell.numeric_value::text);

END;

$$;


--
-- TOC entry 2412 (class 1255 OID 948166)
-- Name: get_value_object(information.appellation); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_object(appe information.appellation) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN jsonb_build_object(
        'string',
        jsonb_build_object(
            'pkEntity',
            appe.pk_entity,
            'fkClass',
            appe.fk_class,
            'string',
            appe.string
        )
    );

END;

$$;


--
-- TOC entry 2413 (class 1255 OID 948167)
-- Name: get_value_object(information.dimension); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_object(dimension information.dimension) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN jsonb_build_object(
        'dimension',
        jsonb_build_object(
            'pkEntity',
            dimension.pk_entity,
            'fkClass',
            dimension.fk_class,
            'numericValue',
            dimension.numeric_value,
            'fkMeasurementUnit',
            dimension.fk_measurement_unit
        )
    );

END;

$$;


--
-- TOC entry 2414 (class 1255 OID 948168)
-- Name: get_value_object(information.lang_string); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_object(lang_string information.lang_string) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN jsonb_build_object(
        'langString',
        jsonb_build_object(
            'pkEntity',
            lang_string.pk_entity,
            'fkClass',
            lang_string.fk_class,
            'string',
            lang_string.string,
            'fkLanguage',
            lang_string.fk_language
        )
    );

END;

$$;


--
-- TOC entry 2415 (class 1255 OID 948169)
-- Name: get_value_object(information.language); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_object(language information.language) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN jsonb_build_object(
        'language',
        jsonb_build_object(
            'pkEntity',
            language .pk_entity,
            'fkClass',
            language .fk_class,
            'label',
            language .notes,
            'iso6391',
            trim(language .iso6391),
            'iso6392b',
            trim(language .iso6392b),
            'iso6392t',
            trim(language .iso6392t)
        )
    );

END;

$$;


--
-- TOC entry 2416 (class 1255 OID 948170)
-- Name: get_value_object(information.place); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_object(place information.place) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN jsonb_build_object(
        'geometry',
        jsonb_build_object(
            'pkEntity',
            place.pk_entity,
            'fkClass',
            place.fk_class,
            'geoJSON',
            ST_AsGeoJSON(place.geo_point::geometry)::jsonb
        )
    );

END;

$$;


--
-- TOC entry 2417 (class 1255 OID 948171)
-- Name: get_value_object(information.time_primitive); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_object(time_primitive information.time_primitive) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN jsonb_build_object(
        'timePrimitive',
        commons.time_primitive__pretty_json(time_primitive)
    );

END;

$$;


--
-- TOC entry 2418 (class 1255 OID 948172)
-- Name: get_value_object(tables.cell); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.get_value_object(cell tables.cell) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN jsonb_build_object(
        'cell',
        jsonb_build_object(
            'pkCell',
            cell.pk_cell,
            'fkClass',
            cell.fk_class,
            'numericValue',
            cell.numeric_value,
            'stringValue',
            cell.string_value,
            'fkRow',
            cell.fk_row,
            'fkColumn',
            cell.fk_column
        )
    );

END;

$$;


--
-- TOC entry 2419 (class 1255 OID 948173)
-- Name: handle_community_statements_delete(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.handle_community_statements_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert or update the deleted row in pgwar.community_statements_deleted
    INSERT INTO pgwar.community_statements_deleted (pk_entity, fk_subject_info, fk_property, fk_object_info, object_value, tmsp_deletion)
    VALUES (OLD.pk_entity, OLD.fk_subject_info, OLD.fk_property, OLD.fk_object_info, OLD.object_value, CURRENT_TIMESTAMP)
    ON CONFLICT (pk_entity)
    DO UPDATE SET 
        fk_subject_info = EXCLUDED.fk_subject_info,
        fk_property = EXCLUDED.fk_property,
        fk_object_info = EXCLUDED.fk_object_info,
        object_value = EXCLUDED.object_value,
        tmsp_deletion = CURRENT_TIMESTAMP;

    RETURN OLD;
END;
$$;


--
-- TOC entry 2420 (class 1255 OID 948174)
-- Name: handle_project_statements_delete(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.handle_project_statements_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert or update the deleted row in pgwar.project_statements_deleted
    INSERT INTO pgwar.project_statements_deleted (pk_entity, fk_project, fk_subject_info, fk_property, fk_object_info, object_value, tmsp_deletion)
    VALUES (OLD.pk_entity, OLD.fk_project, OLD.fk_subject_info, OLD.fk_property, OLD.fk_object_info, OLD.object_value, CURRENT_TIMESTAMP)
    ON CONFLICT (pk_entity, fk_project)
    DO UPDATE SET 
        fk_subject_info = EXCLUDED.fk_subject_info,
        fk_property = EXCLUDED.fk_property,
        fk_object_info = EXCLUDED.fk_object_info,
        object_value = EXCLUDED.object_value,
        tmsp_deletion = EXCLUDED.tmsp_deletion;

    RETURN OLD;
END;
$$;


--
-- TOC entry 2421 (class 1255 OID 948175)
-- Name: update_community_statements_from_deletes(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_community_statements_from_deletes() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text;
BEGIN
    _job_name := 'update-community-statements-from-deletes';

    -- initialize offset, if needed
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2000-01-01 00:00:00.000000+00');
    END IF;

    -- identify updated project statements
    WITH deleted_p_stmts AS (
        SELECT 
            pk_entity, 
		    max(tmsp_deletion) new_offset_tmsp
        FROM (
            SELECT pk_entity, tmsp_deletion
            FROM 
                pgwar.project_statements_deleted
            WHERE tmsp_deletion > (
                SELECT offset_tmsp
                FROM pgwar.offsets
                WHERE job_name = 'update-community-statements-from-deletes'
            )
            ORDER BY tmsp_deletion ASC
        ) AS modified
        GROUP BY pk_entity
    ),
    insert_community_statements AS (
        -- insert or update community statements
        INSERT INTO pgwar.community_statements (
            pk_entity, 
            fk_subject_info,
            fk_property,
            fk_object_info,
            fk_object_tables_cell,
            ord_num_of_domain,
            ord_num_of_range,
            object_label,
            object_value,
            tmsp_last_modification
        )
        SELECT 
            p_stmt.pk_entity, 
            p_stmt.fk_subject_info,
            p_stmt.fk_property,
            p_stmt.fk_object_info,
            p_stmt.fk_object_tables_cell,
            avg(p_stmt.ord_num_of_domain) AS ord_num_of_domain,
            avg(p_stmt.ord_num_of_range) AS ord_num_of_range,
            p_stmt.object_label,
            p_stmt.object_value,
            deleted_p_stmts.new_offset_tmsp AS tmsp_last_modification
        FROM pgwar.project_statements p_stmt,
            deleted_p_stmts
        WHERE p_stmt.pk_entity = deleted_p_stmts.pk_entity
        GROUP BY 
            p_stmt.pk_entity, 
            p_stmt.fk_subject_info,
            p_stmt.fk_property,
            p_stmt.fk_object_info,
            p_stmt.fk_object_tables_cell,
            p_stmt.object_label,
            p_stmt.object_value,
            deleted_p_stmts.new_offset_tmsp
        ON CONFLICT (pk_entity)
        DO UPDATE SET
            fk_subject_info = EXCLUDED.fk_subject_info,
            fk_property = EXCLUDED.fk_property,
            fk_object_info = EXCLUDED.fk_object_info,
            fk_object_tables_cell = EXCLUDED.fk_object_tables_cell,
            ord_num_of_domain = EXCLUDED.ord_num_of_domain,
            ord_num_of_range = EXCLUDED.ord_num_of_range,
            object_label = EXCLUDED.object_label,
            object_value = EXCLUDED.object_value,
            tmsp_last_modification = EXCLUDED.tmsp_last_modification
        -- return the tmsp_last_modification which equals new_offset_tmsp
        RETURNING tmsp_last_modification
    ),
    delete_community_statements AS (
        DELETE FROM pgwar.community_statements
        WHERE pk_entity IN (SELECT pk_entity FROM deleted_p_stmts)
        AND pk_entity NOT IN (
            SELECT DISTINCT ps.pk_entity 
            FROM pgwar.project_statements ps,
            deleted_p_stmts d
            WHERE ps.pk_entity = d.pk_entity
        )
    )
    -- set the offset
    UPDATE pgwar.offsets
    SET offset_tmsp = new_offset.tmsp_last_modification
    FROM (
        SELECT tmsp_last_modification
        FROM insert_community_statements
        LIMIT 1
    ) new_offset
	WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2422 (class 1255 OID 948176)
-- Name: update_community_statements_from_upserts(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_community_statements_from_upserts() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text;
BEGIN
    _job_name := 'update-community-statements-from-upserts';

    -- initialize offset, if needed
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2000-01-01 00:00:00.000000+00');
    END IF;

    -- identify updated project statements
    WITH
    upserted_p_stmts AS (
        SELECT pk_entity,
               max(tmsp_last_modification) new_offset_tmsp
        FROM (
             SELECT pk_entity, tmsp_last_modification
             FROM
                 pgwar.project_statements
             WHERE tmsp_last_modification > (
                 SELECT offset_tmsp
                 FROM pgwar.offsets
                 WHERE job_name = 'update-community-statements-from-upserts'
             )
             ORDER BY tmsp_last_modification ASC
        ) AS modified
        GROUP BY pk_entity
    ),
    insert_community_statements AS (
        -- insert or update community statements
        INSERT INTO pgwar.community_statements (
            pk_entity, 
            fk_subject_info,
            fk_property,
            fk_object_info,
            fk_object_tables_cell,
            ord_num_of_domain,
            ord_num_of_range,
            object_label,
            object_value,
            tmsp_last_modification
        )
        SELECT 
            p_stmt.pk_entity, 
            p_stmt.fk_subject_info,
            p_stmt.fk_property,
            p_stmt.fk_object_info,
            p_stmt.fk_object_tables_cell,
            avg(p_stmt.ord_num_of_domain) AS ord_num_of_domain,
            avg(p_stmt.ord_num_of_range) AS ord_num_of_range,
            p_stmt.object_label,
            p_stmt.object_value,
            upserted_p_stmts.new_offset_tmsp AS tmsp_last_modification
        FROM pgwar.project_statements p_stmt,
            upserted_p_stmts
        WHERE p_stmt.pk_entity = upserted_p_stmts.pk_entity
        GROUP BY 
            p_stmt.pk_entity, 
            p_stmt.fk_subject_info,
            p_stmt.fk_property,
            p_stmt.fk_object_info,
            p_stmt.fk_object_tables_cell,
            p_stmt.object_label,
            p_stmt.object_value,
            upserted_p_stmts.new_offset_tmsp
        ON CONFLICT (pk_entity)
        DO UPDATE SET
            fk_subject_info = EXCLUDED.fk_subject_info,
            fk_property = EXCLUDED.fk_property,
            fk_object_info = EXCLUDED.fk_object_info,
            fk_object_tables_cell = EXCLUDED.fk_object_tables_cell,
            ord_num_of_domain = EXCLUDED.ord_num_of_domain,
            ord_num_of_range = EXCLUDED.ord_num_of_range,
            object_label = EXCLUDED.object_label,
            object_value = EXCLUDED.object_value,
            tmsp_last_modification = EXCLUDED.tmsp_last_modification
        -- return the tmsp_last_modification which equals new_offset_tmsp
        RETURNING tmsp_last_modification
    )
    -- set the offset
    UPDATE pgwar.offsets
    SET offset_tmsp = new_offset.tmsp_last_modification
    FROM (
        SELECT tmsp_last_modification
        FROM insert_community_statements
        LIMIT 1
    ) new_offset
	WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2423 (class 1255 OID 948177)
-- Name: update_entity_class(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_class() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text;
BEGIN
    _job_name := 'update-entity-class';

    -- initialize offset, if needed
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2000-01-01 00:00:00.000000+00');
    END IF;

    -- get current offset
    WITH _offset AS (
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ),
     project_lang AS (
    -- select project/community id and its language
        SELECT 
            proj.pk_entity as fk_project,
            COALESCE(TRIM(iso6391), 'en') lang_code, -- language code or english
            proj.tmsp_last_modification AS project_modified,
            lang.tmsp_last_modification AS language_modified
        FROM projects.project proj
        LEFT JOIN information.language lang ON proj.fk_language = lang.pk_entity
        WHERE lang.pk_entity = proj.fk_language
        UNION 
        SELECT 0, 'en', NULL, NULL -- add a row for community in english
    ),
    class_metadata AS (
        -- get the class labels and entity type
        SELECT DISTINCT ON (cla.dfh_pk_class, cla.dfh_class_label_language)
                cla.dfh_pk_class AS fk_class,
                cla.dfh_class_label AS class_label,
                cla.dfh_class_label_language as lang_code,
                cla.tmsp_last_modification as class_modified,
                CASE WHEN 70 = ANY (cla.dfh_parent_classes || cla.dfh_ancestor_classes) 
                    THEN 'peIt' 
                    ELSE  'teEn'
                END entity_type,
                cla.dfh_parent_classes,
                cla.dfh_ancestor_classes
        FROM 	data_for_history.api_class cla
        ORDER BY 
                cla.dfh_pk_class, 
                cla.dfh_class_label_language, 
                cla.removed_from_api ASC, -- prioritize false over true
                cla.tmsp_last_modification DESC -- prioritize newer labels
            
    ),
    entity_preview_with_class_metadata AS (
        -- join entity previews with class metadata 
        SELECT 
                    ep.pk_entity,
                    ep.fk_project,
                    ep.fk_class,
                    COALESCE(meta.class_label, meta_en.class_label) AS class_label,
                    COALESCE(meta.entity_type, meta_en.entity_type) AS entity_type,
                    COALESCE(meta.dfh_parent_classes, meta_en.dfh_parent_classes) AS dfh_parent_classes,
                    COALESCE(meta.dfh_ancestor_classes, meta_en.dfh_ancestor_classes) AS dfh_ancestor_classes,
                    COALESCE(meta.class_modified, meta_en.class_modified) AS class_modified,
                    project_lang.project_modified,
                    project_lang.language_modified,
                    ep.tmsp_fk_class_modification
        FROM 		project_lang
        JOIN		pgwar.entity_preview ep ON project_lang.fk_project = ep.fk_project
        LEFT JOIN 	class_metadata meta ON ep.fk_class = meta.fk_class AND meta.lang_code = project_lang.lang_code
        LEFT JOIN 	class_metadata meta_en ON ep.fk_class = meta_en.fk_class AND meta_en.lang_code = 'en'
    )
    UPDATE  pgwar.entity_preview ep
    SET     class_label = meta.class_label,
            entity_type = meta.entity_type,
            parent_classes = to_jsonb(meta.dfh_parent_classes),
            ancestor_classes = to_jsonb(meta.dfh_ancestor_classes)
    FROM 	entity_preview_with_class_metadata meta,
            _offset
    WHERE   ep.pk_entity = meta.pk_entity
    AND     ep.fk_project = meta.fk_project
    AND (
            meta.class_modified > _offset.offset_tmsp OR
            meta.project_modified > _offset.offset_tmsp OR
            meta.language_modified > _offset.offset_tmsp OR
            meta.tmsp_fk_class_modification > _offset.offset_tmsp
        );
    

    -- set the offset
    UPDATE pgwar.offsets
    SET offset_tmsp = CURRENT_TIMESTAMP
	WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2424 (class 1255 OID 948178)
-- Name: update_entity_label_of_entity_preview(integer, integer, text); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_label_of_entity_preview(entity_id integer, project_id integer, new_label text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE pgwar.entity_preview
    SET entity_label = new_label,
        tmsp_entity_label_modification = CURRENT_TIMESTAMP
    WHERE pk_entity = entity_id
      AND fk_project = project_id
      AND entity_label IS DISTINCT FROM new_label;
END;
$$;


--
-- TOC entry 2425 (class 1255 OID 948179)
-- Name: update_entity_label_on_config_change(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_label_on_config_change() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text; -- Variable to store the job name
    _current_offset timestamp; -- Variable to store the current offset timestam
    project_id int;
    class_id int;
BEGIN
    _job_name := 'update-entity-label-on-config-change'; -- Initialize the job name

    -- Check if the offset for the job is already initialized
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        -- If not, initialize it with a default value
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2024-10-17 00:00:00.000000+00');
    END IF;

    -- Retrieve the current offset timestamp for the job
    SELECT offset_tmsp INTO _current_offset
    FROM pgwar.offsets
    WHERE job_name = _job_name;

    -- Get project_id and class_id from the entity_label_config table
    FOR project_id, class_id IN
        SELECT fk_project, fk_class
        FROM projects.entity_label_config
        WHERE tmsp_last_modification > _current_offset
        LOOP
            IF project_id = 375669 THEN
                -- Perform update of entity labels that depend on the default config of project 375669
                WITH new_labels AS (
                    SELECT  ep.pk_entity,
                            ep.fk_project,
                            pgwar.get_project_entity_label(ep.pk_entity, ep.fk_project) AS entity_label
                    FROM pgwar.entity_preview ep
                             LEFT JOIN projects.entity_label_config c
                                       ON c.fk_class = ep.fk_class
                                           AND c.fk_project = ep.fk_project
                    WHERE ep.fk_class = class_id
                      AND ep.fk_project != 0 -- all projects except 0
                      AND c.config IS NULL -- take only rows that have no own project config
                )
                UPDATE pgwar.entity_preview ep
                SET entity_label = new_labels.entity_label
                FROM new_labels
                WHERE new_labels.pk_entity = ep.pk_entity
                  AND new_labels.fk_project = ep.fk_project
                  AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;
            ELSE
                -- Update the project entity labels
                WITH new_labels AS (
                    SELECT  ep.pk_entity,
                            ep.fk_project,
                            pgwar.get_project_entity_label(ep.pk_entity, ep.fk_project) AS entity_label
                    FROM pgwar.entity_preview ep
                    WHERE ep.fk_project != 0 AND ep.fk_project = project_id -- all projects except 0
                )
                UPDATE pgwar.entity_preview ep
                SET entity_label = new_labels.entity_label
                FROM new_labels
                WHERE ep.pk_entity = new_labels.pk_entity
                  AND ep.fk_project = new_labels.fk_project
                  AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;
            END IF;
        END LOOP;

    -- Update the offset table with the current timestamp to mark the job completion time
    UPDATE pgwar.offsets
    SET offset_tmsp = CURRENT_TIMESTAMP
    WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2426 (class 1255 OID 948180)
-- Name: update_entity_label_on_project_statement_delete(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_label_on_project_statement_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    WITH new_labels AS (
        -- get new labels of subject entities
        SELECT  oldtab.fk_subject_info AS pk_entity, 
                oldtab.fk_project, 
                pgwar.get_project_entity_label(oldtab.fk_subject_info, oldtab.fk_project) AS entity_label
        FROM oldtab
        UNION
        -- get new labels of object entities
        SELECT  oldtab.fk_object_info AS pk_entity,
                oldtab.fk_project, 
                pgwar.get_project_entity_label(oldtab.fk_object_info, oldtab.fk_project) AS entity_label
        FROM oldtab
        WHERE oldtab.object_label IS NULL
    )
    UPDATE pgwar.entity_preview ep
    SET entity_label = new_labels.entity_label
    FROM new_labels
    WHERE new_labels.pk_entity = ep.pk_entity
    AND new_labels.fk_project = ep.fk_project
    AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;

    
    RETURN NULL;
END;
$$;


--
-- TOC entry 2427 (class 1255 OID 948181)
-- Name: update_entity_label_on_project_statement_upsert(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_label_on_project_statement_upsert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    IF EXISTS(
        SELECT ep.pk_entity, ep.fk_project
		FROM pgwar.entity_preview ep,
		newtab stmt
		WHERE stmt.fk_subject_info = ep.pk_entity
		AND stmt.fk_project = ep.fk_project
    ) THEN
        -- Update the label for the subject entity
        WITH new_labels AS (
            SELECT  newtab.fk_subject_info AS pk_entity,
                    newtab.fk_project,
                    pgwar.get_project_entity_label(newtab.fk_subject_info, newtab.fk_project) AS entity_label
            FROM newtab
        )
        UPDATE pgwar.entity_preview ep
        SET entity_label = new_labels.entity_label
        FROM new_labels 
        WHERE new_labels.pk_entity = ep.pk_entity
        AND new_labels.fk_project = ep.fk_project
        AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;
    END IF;

    IF EXISTS(
        SELECT ep.pk_entity, ep.fk_project
        FROM pgwar.entity_preview ep,
        newtab stmt
        WHERE stmt.fk_object_info = ep.pk_entity
        AND stmt.fk_project = ep.fk_project
    ) THEN
        -- Update the entity labels of the related object entities
        WITH new_labels AS (
            SELECT  newtab.fk_object_info AS pk_entity,
                    newtab.fk_project,
                    pgwar.get_project_entity_label(newtab.fk_object_info, newtab.fk_project) AS entity_label
            FROM newtab
            WHERE newtab.object_label IS NULL
        )
        UPDATE pgwar.entity_preview ep
        SET entity_label = new_labels.entity_label
        FROM new_labels 
        WHERE new_labels.pk_entity = ep.pk_entity
        AND new_labels.fk_project = ep.fk_project
        AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;

    END IF;
    
    RETURN NULL;
END;
$$;


--
-- TOC entry 2428 (class 1255 OID 948182)
-- Name: update_entity_labels_after_delete(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_labels_after_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    is_not_empty BOOLEAN;
BEGIN
    -- Check if the table is not empty using EXISTS
    SELECT EXISTS(SELECT 1 FROM oldtab) INTO is_not_empty;
    
    IF is_not_empty THEN
    
        WITH new_labels AS (

            -- Create entity labels of the related object entities
            SELECT  stmt.fk_object_info AS pk_entity, 
                    oldtab.fk_project, 
                    pgwar.get_project_entity_label(stmt.fk_object_info, oldtab.fk_project) AS entity_label
            FROM pgwar.project_statements stmt,
                oldtab
            WHERE oldtab.entity_label IS NOT NULL 
            AND oldtab.fk_project != 0
            AND stmt.fk_subject_info = oldtab.pk_entity
            AND stmt.fk_project = oldtab.fk_project
            AND stmt.object_label IS NULL
            UNION ALL

            -- Create entity labels of the related subject entities
            SELECT  stmt.fk_subject_info AS pk_entity, 
                    oldtab.fk_project, 
                    pgwar.get_project_entity_label(stmt.fk_subject_info, oldtab.fk_project) AS entity_label
            FROM pgwar.project_statements stmt,
                oldtab
            WHERE oldtab.entity_label IS NOT NULL 
            AND oldtab.fk_project != 0
            AND stmt.fk_object_info = oldtab.pk_entity
            AND stmt.fk_project = oldtab.fk_project
            AND stmt.object_label IS NULL
        )
        -- Update the project entity labels
        UPDATE pgwar.entity_preview ep
        SET entity_label = new_labels.entity_label
        FROM new_labels
        WHERE ep.pk_entity = new_labels.pk_entity
        AND ep.fk_project = new_labels.fk_project
        AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;



        -- Update community entity labels
        WITH uniq_entities AS (
            SELECT DISTINCT pk_entity
            FROM oldtab
            WHERE oldtab.fk_project != 0 
        )
        UPDATE pgwar.entity_preview ep
        SET entity_label = el.entity_label
        FROM uniq_entities,
            pgwar.v_community_entity_label el
        WHERE uniq_entities.pk_entity = el.pk_entity
        AND uniq_entities.pk_entity = ep.pk_entity
        AND ep.fk_project = 0
        AND ep.entity_label IS DISTINCT FROM el.entity_label;

	END IF;

   
    RETURN NULL;
END;
$$;


--
-- TOC entry 2429 (class 1255 OID 948183)
-- Name: update_entity_labels_after_insert(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_labels_after_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    WITH new_labels AS (

        -- create entity labels of inserted entity
        SELECT  newtab.pk_entity, 
                newtab.fk_project, 
                pgwar.get_project_entity_label(newtab.pk_entity, newtab.fk_project) AS entity_label
        FROM newtab
        WHERE newtab.fk_project != 0
    )
    -- Update the project entity labels
    UPDATE pgwar.entity_preview ep
    SET entity_label = new_labels.entity_label
    FROM new_labels
    WHERE ep.pk_entity = new_labels.pk_entity
    AND ep.fk_project = new_labels.fk_project
    AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;



    -- Update community entity labels
    WITH uniq_entities AS (
        SELECT DISTINCT pk_entity
        FROM newtab
        WHERE newtab.fk_project != 0 
    )
    UPDATE pgwar.entity_preview ep
    SET entity_label = el.entity_label
    FROM uniq_entities,
         pgwar.v_community_entity_label el
    WHERE uniq_entities.pk_entity = el.pk_entity
    AND uniq_entities.pk_entity = ep.pk_entity
    AND ep.fk_project = 0
    AND ep.entity_label IS DISTINCT FROM el.entity_label;

    RETURN NULL;
END;
$$;


--
-- TOC entry 2430 (class 1255 OID 948184)
-- Name: update_entity_labels_after_update(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_labels_after_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    is_not_empty BOOLEAN;
    to_update_community INTEGER[];
BEGIN

    IF pg_trigger_depth() > 100 THEN
        RETURN NULL; 
    END IF;

    -- Check if the table is not empty using EXISTS
    SELECT EXISTS(SELECT 1 FROM newtab) INTO is_not_empty;
    
    IF is_not_empty THEN
    
        -- Create new entity labels after modifying entity preview fk_class
    	WITH fk_class_modified AS (
			SELECT 
				ep.pk_entity,
				ep.fk_project,
				pgwar.get_project_entity_label(ep.pk_entity, ep.fk_project) AS entity_label
			FROM
				pgwar.entity_preview ep
			JOIN
				newtab ON ep.pk_entity = newtab.pk_entity AND ep.fk_project = newtab.fk_project
			JOIN
				oldtab ON oldtab.pk_entity = newtab.pk_entity AND oldtab.fk_project = newtab.fk_project
			WHERE
				ep.fk_project != 0
				AND oldtab.fk_class IS DISTINCT FROM newtab.fk_class -- fk_class changed ! 
		)
        UPDATE pgwar.entity_preview ep
        SET entity_label = fk_class_modified.entity_label
        FROM fk_class_modified
        WHERE ep.pk_entity = fk_class_modified.pk_entity
        AND ep.fk_project = fk_class_modified.fk_project
        AND ep.entity_label IS DISTINCT FROM fk_class_modified.entity_label;

        WITH label_changed AS (
                    SELECT 
                        newtab.pk_entity,
                        newtab.fk_project
                    FROM
                        newtab
                        JOIN oldtab 
                            ON  oldtab.pk_entity = newtab.pk_entity AND
                                oldtab.fk_project = newtab.fk_project AND
                                oldtab.entity_label IS DISTINCT FROM newtab.entity_label -- entity_label changed ! 
                    WHERE  
                        newtab.fk_project != 0
                ),
                new_labels AS (
                    -- Create entity labels of the related object entities
                    SELECT  stmt.fk_object_info AS pk_entity, 
                            label_changed.fk_project, 
                            pgwar.get_project_entity_label(stmt.fk_object_info, label_changed.fk_project) AS entity_label
                    FROM pgwar.project_statements stmt,
                        label_changed
                    WHERE stmt.fk_subject_info = label_changed.pk_entity
                    AND stmt.fk_project = label_changed.fk_project
                    AND stmt.object_label IS NULL
                )
                    -- Update the project entity labels
                    UPDATE pgwar.entity_preview ep
                    SET entity_label = new_labels.entity_label
                    FROM new_labels
                    WHERE ep.pk_entity = new_labels.pk_entity
                    AND ep.fk_project = new_labels.fk_project
                    AND ep.entity_label IS DISTINCT FROM new_labels.entity_label
            ;


        WITH label_changed AS (
                    SELECT 
                        newtab.pk_entity,
                        newtab.fk_project
                    FROM
                        newtab
                        JOIN oldtab 
                            ON  oldtab.pk_entity = newtab.pk_entity AND
                                oldtab.fk_project = newtab.fk_project AND
                                oldtab.entity_label IS DISTINCT FROM newtab.entity_label -- entity_label changed ! 
                    WHERE  
                        newtab.fk_project != 0
                ),
                new_labels AS (
                    -- Create entity labels of the related subject entities
                    SELECT  stmt.fk_subject_info AS pk_entity, 
                            label_changed.fk_project, 
                            pgwar.get_project_entity_label(stmt.fk_subject_info, label_changed.fk_project) AS entity_label
                    FROM pgwar.project_statements stmt,
                        label_changed
                    WHERE stmt.fk_object_info = label_changed.pk_entity
                    AND stmt.fk_project = label_changed.fk_project
                    AND stmt.object_label IS NULL
                )   -- Update the project entity labels
                    UPDATE pgwar.entity_preview ep
                    SET entity_label = new_labels.entity_label
                    FROM new_labels
                    WHERE ep.pk_entity = new_labels.pk_entity
                    AND ep.fk_project = new_labels.fk_project
                    AND ep.entity_label IS DISTINCT FROM new_labels.entity_label
                ;

        -- get ids that need update of community label
        SELECT array_agg(pk_entity) INTO to_update_community
        FROM (
            SELECT newtab.pk_entity
            FROM
                newtab
                JOIN oldtab 
                    ON  oldtab.pk_entity = newtab.pk_entity AND
                        oldtab.fk_project = newtab.fk_project AND
                        oldtab.entity_label IS DISTINCT FROM newtab.entity_label -- entity_label changed ! 
            WHERE  
                newtab.fk_project != 0
            GROUP BY newtab.pk_entity
        ) as changed;

        UPDATE pgwar.entity_preview ep
        SET entity_label = el.entity_label
        FROM unnest(to_update_community) as changed_pk_entity(pk_entity),
            pgwar.v_community_entity_label el
        WHERE changed_pk_entity.pk_entity = el.pk_entity
        AND changed_pk_entity.pk_entity = ep.pk_entity
        AND ep.fk_project = 0
        AND ep.entity_label IS DISTINCT FROM el.entity_label;

	END IF;

   
    RETURN NULL;
END;
$$;


--
-- TOC entry 2431 (class 1255 OID 948185)
-- Name: update_entity_preview_entity_label(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_preview_entity_label() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text;
    _current_offset timestamp;
BEGIN
    _job_name := 'update-entity-label';
    -- initialize offset, if needed
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2000-01-01 00:00:00.000000+00');
    END IF;

    -- Get the current offset timestamp
    SELECT offset_tmsp INTO _current_offset
    FROM pgwar.offsets
    WHERE job_name = _job_name;

    -- Retrieve and update entity labels for rows inserted/updated after the last offset
    WITH new_labels AS (
        -- Select entities that were inserted or updated after the last offset
        SELECT  ep.pk_entity,
                ep.fk_project,
                pgwar.get_project_entity_label(ep.pk_entity, ep.fk_project) AS entity_label
        FROM pgwar.entity_preview ep
        WHERE ep.fk_project != 0
          AND (ep.tmsp_entity_label_modification > _current_offset OR ep.tmsp_fk_class_modification > _current_offset OR ep.tmsp_entity_label_modification IS NULL)
    )
    -- Update the project entity labels
    UPDATE pgwar.entity_preview ep
    SET entity_label = new_labels.entity_label,
        tmsp_entity_label_modification = CURRENT_TIMESTAMP
    FROM new_labels
    WHERE ep.pk_entity = new_labels.pk_entity
      AND ep.fk_project = new_labels.fk_project
      AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;

    -- Update community entity labels
    WITH uniq_entities AS (
        SELECT DISTINCT ep.pk_entity
        FROM pgwar.entity_preview ep
        WHERE ep.fk_project != 0
          AND (ep.tmsp_entity_label_modification > _current_offset OR ep.tmsp_fk_class_modification > _current_offset OR ep.tmsp_entity_label_modification IS NULL)
    )
    UPDATE pgwar.entity_preview ep
    SET entity_label = el.entity_label,
        tmsp_entity_label_modification = CURRENT_TIMESTAMP
    FROM uniq_entities,
         pgwar.v_community_entity_label el
    WHERE uniq_entities.pk_entity = el.pk_entity
      AND uniq_entities.pk_entity = ep.pk_entity
      AND ep.fk_project = 0
      AND ep.entity_label IS DISTINCT FROM el.entity_label;

    -- Update the offset table with the current timestamp to mark the job completion time
    UPDATE pgwar.offsets
    SET offset_tmsp = CURRENT_TIMESTAMP
    WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2432 (class 1255 OID 948186)
-- Name: update_entity_preview_entity_label_after_stmt_delete(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_preview_entity_label_after_stmt_delete() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text;
    _current_offset timestamp;
BEGIN
    _job_name := 'update-entity-label-after-stmt-delete';
    -- initialize offset, if needed
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2000-01-01 00:00:00.000000+00');
    END IF;

    -- Get the current offset timestamp
    SELECT offset_tmsp INTO _current_offset
    FROM pgwar.offsets
    WHERE job_name = _job_name;

    -- Retrieve and update entity labels for rows inserted/updated after the last offset
    WITH new_labels AS (
        -- Select entities that have a deleted statement after the last offset
        SELECT 	ep.pk_entity,
                  ep.fk_project,
                  pgwar.get_project_entity_label(ep.pk_entity, ep.fk_project) AS entity_label
        FROM pgwar.entity_preview ep
                 JOIN pgwar.project_statements ps ON ps.fk_subject_info = ep.pk_entity AND ep.fk_project = ps.fk_project
                 JOIN pgwar.v_statements_deleted_combined sdc ON sdc.fk_object_info = ps.fk_object_info AND ps.fk_project = sdc.fk_project
        WHERE sdc.tmsp_deletion > _current_offset
    )
    -- Update the project entity labels
    UPDATE pgwar.entity_preview ep
    SET entity_label = new_labels.entity_label,
        tmsp_entity_label_modification = CURRENT_TIMESTAMP
    FROM new_labels
    WHERE ep.pk_entity = new_labels.pk_entity
      AND ep.fk_project = new_labels.fk_project
      AND ep.entity_label IS DISTINCT FROM new_labels.entity_label;

    -- Update community entity labels
    WITH uniq_entities AS (
        SELECT DISTINCT ep.pk_entity
        FROM pgwar.entity_preview ep
                 JOIN pgwar.project_statements ps ON ps.fk_subject_info = ep.pk_entity AND ep.fk_project = ps.fk_project
                 JOIN pgwar.v_statements_deleted_combined sdc ON sdc.fk_object_info = ps.fk_object_info AND ps.fk_project = sdc.fk_project
        WHERE sdc.tmsp_deletion > _current_offset AND ep.fk_project != 0
    )
    UPDATE pgwar.entity_preview ep
    SET entity_label = el.entity_label,
        tmsp_entity_label_modification = CURRENT_TIMESTAMP
    FROM uniq_entities,
         pgwar.v_community_entity_label el
    WHERE uniq_entities.pk_entity = el.pk_entity
      AND uniq_entities.pk_entity = ep.pk_entity
      AND ep.fk_project = 0
      AND ep.entity_label IS DISTINCT FROM el.entity_label;

    -- Update the offset table with the current timestamp to mark the job completion time
    UPDATE pgwar.offsets
    SET offset_tmsp = CURRENT_TIMESTAMP
    WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2433 (class 1255 OID 948187)
-- Name: update_entity_preview_full_text(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_entity_preview_full_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    UPDATE pgwar.entity_preview ep
    SET full_text = newtab.full_text
    FROM newtab
    WHERE ep.pk_entity = newtab.pk_entity
    AND ep.fk_project = newtab.fk_project
    AND ep.full_text IS DISTINCT FROM newtab.full_text;

    RETURN NULL;
END;
$$;


--
-- TOC entry 2434 (class 1255 OID 948188)
-- Name: update_field_change_on_project_statements_modification(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_field_change_on_project_statements_modification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    proj_stmt pgwar.project_statements;
BEGIN

    proj_stmt := COALESCE(NEW, OLD);
    --if project statement is a statement with literal
    IF proj_stmt.object_value IS NOT NULL THEN
        PERFORM
            pgwar.upsert_field_change((
                proj_stmt.fk_project,
                proj_stmt.fk_subject_info,
                NULL,
                proj_stmt.fk_property,
                true,
                proj_stmt.tmsp_last_modification
            )::pgwar.field_change);
        --else if project statement is a statement with entity
    ELSE
        PERFORM
            pgwar.upsert_field_change((
                proj_stmt.fk_project,
                proj_stmt.fk_subject_info,
                NULL,
                proj_stmt.fk_property,
                true,
                proj_stmt.tmsp_last_modification
            )::pgwar.field_change);

        PERFORM
            pgwar.upsert_field_change((
                proj_stmt.fk_project,
                proj_stmt.fk_object_info,
                proj_stmt.fk_object_tables_cell,
                proj_stmt.fk_property,
                false,
                proj_stmt.tmsp_last_modification
            )::pgwar.field_change);
    END IF;
    RETURN NULL;
END;
$$;


--
-- TOC entry 2435 (class 1255 OID 948189)
-- Name: update_fk_type(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_fk_type() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text;
    _current_offset timestamp;
BEGIN
    _job_name := 'update-fk-type';
    -- Function logic goes here

     -- initialize offset, if needed
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2000-01-01 00:00:00.000000+00');
    END IF;

    -- get current offset
    SELECT offset_tmsp INTO _current_offset
    FROM pgwar.offsets
    WHERE job_name = _job_name;

    WITH hastypeprop AS (
        -- Select distinct domain class, property ID, and last modification timestamp
        -- from the api_property table where the property or its parent/ancestor properties
        -- contain the value 2
        SELECT DISTINCT ON (prop.dfh_pk_property)
            prop.dfh_property_domain, 
            prop.dfh_pk_property,
            prop.tmsp_last_modification 
        FROM data_for_history.api_property prop
        WHERE 
            2 = ANY(prop.dfh_pk_property || (prop.dfh_parent_properties || prop.dfh_ancestor_properties))
        ORDER BY 
            prop.dfh_pk_property, 
            prop.tmsp_last_modification DESC
    ),

    entity_preview_with_hastypeprop AS (
        -- Join entity_preview with hastypeprop to get entity ID, project ID, and the
        -- last modification timestamps of both the fk_class of the entity_preview
        -- and the property.
        SELECT 
            ep.pk_entity,
            ep.fk_project,
            ep.tmsp_fk_class_modification,
            prop.dfh_pk_property,
            prop.tmsp_last_modification AS prop_modified
        FROM 
            pgwar.entity_preview ep,
            hastypeprop prop
        WHERE 
            prop.dfh_property_domain = ep.fk_class
    ),

    with_hastypestmt AS (
        -- Join v_statements_combined with entity_preview_with_hastypeprop to get the
        -- fk_type and the last modification timestamp of the has-type statement
        -- distinct by entity ID, project ID
        SELECT DISTINCT ON (typeprop.pk_entity, typeprop.fk_project)
            typeprop.pk_entity,
            typeprop.fk_project,
            stmt.fk_object_info AS fk_type,
            stmt.tmsp_last_modification AS stmt_modified
        FROM 
            pgwar.v_statements_combined stmt,
            entity_preview_with_hastypeprop typeprop
        WHERE 
            typeprop.pk_entity = stmt.fk_subject_info
            AND typeprop.fk_project = stmt.fk_project
            AND typeprop.dfh_pk_property = stmt.fk_property
        ORDER BY 
            typeprop.pk_entity,
            typeprop.fk_project,
            stmt.ord_num_of_range ASC,
            stmt.tmsp_last_modification DESC
    ),

    with_hastypestmt_del AS (
        -- Join v_statements_deleted_combined with entity_preview_with_hastypeprop to get the
        -- deletion timestamp of of the has-type statement
        -- distinct by entity ID, project ID
        SELECT DISTINCT ON (typeprop.pk_entity, typeprop.fk_project)
            typeprop.pk_entity,
            typeprop.fk_project,
            stmt.tmsp_deletion AS stmt_deleted
        FROM 
            pgwar.v_statements_deleted_combined stmt,
            entity_preview_with_hastypeprop typeprop
        WHERE 
            typeprop.pk_entity = stmt.fk_subject_info
            AND typeprop.fk_project = stmt.fk_project
            AND typeprop.dfh_pk_property = stmt.fk_property
        ORDER BY 
            typeprop.pk_entity,
            typeprop.fk_project,
            stmt.tmsp_deletion DESC
    )

    -- Final selection combining the previous CTE results with a LEFT JOIN to include
    -- all relevant project-entities, the statement with fk_type and timestamps.
    -- The WHERE clause ensures that only records modified after the _current_offset 
    -- and fk_type disctinct from the current fk_type are used for updating
    -- the pgwar.entity_preview table
    UPDATE pgwar.entity_preview ep
    SET fk_type = stmt.fk_type,
        tmsp_fk_type_modification = CURRENT_TIMESTAMP
    FROM 
        entity_preview_with_hastypeprop ep_prop
    LEFT JOIN 
        with_hastypestmt stmt 
        ON ep_prop.pk_entity = stmt.pk_entity 
        AND ep_prop.fk_project = stmt.fk_project 
    LEFT JOIN 
        with_hastypestmt_del stmtdel 
        ON ep_prop.pk_entity = stmtdel.pk_entity 
        AND ep_prop.fk_project = stmtdel.fk_project 
    WHERE
        ep.fk_type IS DISTINCT FROM stmt.fk_type 
    AND
        ep.pk_entity = ep_prop.pk_entity 
    AND
        ep.fk_project = ep_prop.fk_project
    AND (
            ep_prop.tmsp_fk_class_modification > _current_offset OR
            ep_prop.prop_modified > _current_offset OR
            stmt.stmt_modified > _current_offset OR
            stmtdel.stmt_deleted > _current_offset
        );

    -- set the offset
    UPDATE pgwar.offsets
    SET offset_tmsp = CURRENT_TIMESTAMP
	WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2436 (class 1255 OID 948207)
-- Name: update_from_info_proj_rel(projects.info_proj_rel, boolean); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_from_info_proj_rel(new_old projects.info_proj_rel, is_upsert boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    entity information.resource;
    statement pgwar.statement;
BEGIN

    -- get the referenced pgwar.statement
    SELECT *
    INTO statement
    FROM pgwar.statement stmt
    WHERE stmt.pk_entity = NEW_OLD.fk_entity;

    -- if pgwar.statement is referenced by info_proj_rel.fk_entity
    IF statement.pk_entity IS NOT NULL THEN
       
        -- if upsert ...
        IF is_upsert IS TRUE THEN
            -- ... upsert the project statements
            PERFORM
                pgwar.upsert_project_statements((
                        NEW_OLD.fk_entity,
                        NEW_OLD.fk_project,
                        statement.fk_subject_info,
                        statement.fk_property,
                        statement.fk_object_info,
                        statement.fk_object_tables_cell,
                        NEW_OLD.ord_num_of_domain::numeric,
                        NEW_OLD.ord_num_of_range::numeric,
                        statement.object_label,
                        statement.object_value,
                        NULL)::pgwar.project_statements
                );
        ELSE
            -- ... delete the project_statements
            DELETE FROM pgwar.project_statements
            WHERE pk_entity = NEW_OLD.fk_entity
              AND fk_project = NEW_OLD.fk_project;
        END IF;
    ELSE

        -- get the referenced information.resource
        SELECT * 
        INTO entity
        FROM information.resource
        WHERE pk_entity = NEW_OLD.fk_entity;
        -- if the referenced item is an entity
        IF entity.pk_entity IS NOT NULL THEN

            -- if upsert ...
            IF is_upsert IS TRUE THEN
                -- ... upsert the project entity
                PERFORM
                    pgwar.upsert_entity_preview_fk_class(NEW_OLD.fk_entity, NEW_OLD.fk_project, entity.fk_class);
                -- if allowed ...
                IF (entity.community_visibility ->> 'toolbox')::bool IS TRUE THEN
                    -- ... upsert the community entity
                    PERFORM
                        pgwar.upsert_entity_preview_fk_class(NEW_OLD.fk_entity, 0, entity.fk_class);
                END IF;
            ELSE
                -- ... delete the project entity
                DELETE FROM pgwar.entity_preview
                WHERE pk_entity = NEW_OLD.fk_entity
                    AND fk_project = NEW_OLD.fk_project;
                -- ... check if community entity has to be deleted
                IF NOT EXISTS (
                    SELECT
                        pk_entity
                    FROM
                        projects.info_proj_rel
                    WHERE
                        fk_entity = NEW_OLD.fk_entity
                        AND is_in_project IS TRUE) THEN
                    -- ... delete the community entity
                    DELETE FROM pgwar.entity_preview
                    WHERE pk_entity = NEW_OLD.fk_entity
                        AND fk_project = 0;
                END IF;
            END IF;
        END IF;

    END IF;
END;
$$;


--
-- TOC entry 2437 (class 1255 OID 948215)
-- Name: update_from_resource(information.resource); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_from_resource(new_res information.resource) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN


    -- if it is in at least one project ...
    IF EXISTS(
        SELECT
            pk_entity
        FROM
            projects.info_proj_rel
        WHERE
            fk_entity = NEW_RES.pk_entity
            AND is_in_project IS TRUE) THEN
        -- ... insert missing project entities or update existing, in case fk_class differs
        PERFORM
            pgwar.upsert_entity_preview_fk_class(fk_entity, fk_project, NEW_RES.fk_class)
        FROM
            projects.info_proj_rel
        WHERE
            fk_entity = NEW_RES.pk_entity
            AND is_in_project IS TRUE;
        -- ... insert missing community entity or update existing, in case fk_class differs
        PERFORM
            pgwar.upsert_entity_preview_fk_class(NEW_RES.pk_entity, 0, NEW_RES.fk_class);
    END IF;
        -- if hidden for toolbox community ...
        IF(NEW_RES.community_visibility ->> 'toolbox')::bool IS FALSE THEN
            -- ... delete potentially unallowed community entities
            DELETE FROM pgwar.entity_preview
            WHERE fk_project = 0
                AND pk_entity = NEW_RES.pk_entity;
    END IF;
END;
$$;


--
-- TOC entry 2438 (class 1255 OID 948233)
-- Name: update_from_statement(information.statement); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_from_statement(new_stmt information.statement) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    entity information.resource;
    appellation information.appellation;
    dimension information.dimension;
    lang_string information.lang_string;
    language information.language;
    place information.place;
    time_primitive information.time_primitive;
    cell tables.cell;
BEGIN

    -- get the referenced appellation...
    SELECT * INTO appellation FROM information.appellation WHERE pk_entity = NEW_STMT.fk_object_info;
    -- ...if not null...
    IF appellation.pk_entity IS NOT NULL THEN
      -- create a pgwar.statement
      PERFORM pgwar.upsert_statement((NEW_STMT.pk_entity,NEW_STMT.fk_subject_info,NEW_STMT.fk_property,NEW_STMT.fk_object_info,NEW_STMT.fk_object_tables_cell,
        pgwar.get_value_label(appellation),
        pgwar.get_value_object(appellation)
      )::pgwar.statement);
      -- return!
      RETURN;
    END IF;

    -- get the referenced dimension...
    SELECT * INTO dimension FROM information.dimension WHERE pk_entity = NEW_STMT.fk_object_info;
    -- ...if not null...
    IF dimension.pk_entity IS NOT NULL THEN
      -- create a pgwar.statement
      PERFORM pgwar.upsert_statement((NEW_STMT.pk_entity,NEW_STMT.fk_subject_info,NEW_STMT.fk_property,NEW_STMT.fk_object_info,NEW_STMT.fk_object_tables_cell,
        pgwar.get_value_label(dimension),
        pgwar.get_value_object(dimension)
      )::pgwar.statement);
      -- return!
      RETURN;
    END IF;

    -- get the referenced lang_string...
    SELECT * INTO lang_string FROM information.lang_string WHERE pk_entity = NEW_STMT.fk_object_info;
    -- ...if not null...
    IF lang_string.pk_entity IS NOT NULL THEN
      -- create a pgwar.statement
      PERFORM pgwar.upsert_statement((NEW_STMT.pk_entity,NEW_STMT.fk_subject_info,NEW_STMT.fk_property,NEW_STMT.fk_object_info,NEW_STMT.fk_object_tables_cell,
        pgwar.get_value_label(lang_string),
        pgwar.get_value_object(lang_string)
      )::pgwar.statement);
      -- return!
      RETURN;
    END IF;

    -- get the referenced dimension...
    SELECT * INTO language FROM information.language WHERE pk_entity = NEW_STMT.fk_object_info;
    -- ...if not null...
    IF language.pk_entity IS NOT NULL THEN
      -- create a pgwar.statement
      PERFORM pgwar.upsert_statement((NEW_STMT.pk_entity,NEW_STMT.fk_subject_info,NEW_STMT.fk_property,NEW_STMT.fk_object_info,NEW_STMT.fk_object_tables_cell,
        pgwar.get_value_label(language),
        pgwar.get_value_object(language)
      )::pgwar.statement);
      -- return!
      RETURN;
    END IF;

    -- get the referenced place...
    SELECT * INTO place FROM information.place WHERE pk_entity = NEW_STMT.fk_object_info;
    -- ...if not null...
    IF place.pk_entity IS NOT NULL THEN
      -- create a pgwar.statement
      PERFORM pgwar.upsert_statement((NEW_STMT.pk_entity,NEW_STMT.fk_subject_info,NEW_STMT.fk_property,NEW_STMT.fk_object_info,NEW_STMT.fk_object_tables_cell,
        pgwar.get_value_label(place),
        pgwar.get_value_object(place)
      )::pgwar.statement);
      -- return!
      RETURN;
    END IF;

    -- get the referenced time_primitive...
    SELECT * INTO time_primitive FROM information.time_primitive WHERE pk_entity = NEW_STMT.fk_object_info;
    -- ...if not null...
    IF time_primitive.pk_entity IS NOT NULL THEN
      -- create a pgwar.statement
      PERFORM pgwar.upsert_statement((NEW_STMT.pk_entity,NEW_STMT.fk_subject_info,NEW_STMT.fk_property,NEW_STMT.fk_object_info,NEW_STMT.fk_object_tables_cell,
        pgwar.get_value_label(time_primitive),
        pgwar.get_value_object(time_primitive)
      )::pgwar.statement);
      -- return!
      RETURN;
    END IF;

    -- get the referenced cell...
    SELECT * INTO cell FROM tables.cell WHERE pk_cell = NEW_STMT.fk_object_tables_cell;
    -- ...if not null...
    IF cell.pk_cell IS NOT NULL THEN
      -- create a pgwar.statement
      PERFORM pgwar.upsert_statement((NEW_STMT.pk_entity,NEW_STMT.fk_subject_info,NEW_STMT.fk_property,NEW_STMT.fk_object_info,NEW_STMT.fk_object_tables_cell,
        pgwar.get_value_label(cell),
        pgwar.get_value_object(cell)
      )::pgwar.statement);
      -- return!
      RETURN;
    END IF;

    

    -- get the referenced entity...
    SELECT * INTO entity FROM information.resource WHERE pk_entity = NEW_STMT.fk_object_info;
    -- ...if not null...
    IF entity.pk_entity IS NOT NULL THEN
      -- create a pgwar.statement
      PERFORM pgwar.upsert_statement((NEW_STMT.pk_entity,NEW_STMT.fk_subject_info,NEW_STMT.fk_property,NEW_STMT.fk_object_info,NEW_STMT.fk_object_tables_cell,NULL,NULL)::pgwar.statement);
      -- return!
      RETURN;
    END IF;

END;
$$;


--
-- TOC entry 2439 (class 1255 OID 948234)
-- Name: update_full_texts(integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_full_texts(max_limit integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    updated_count int;
BEGIN

    -- Insert or update pgwar.entity_full_text from the outdated full texts
   	INSERT INTO pgwar.entity_full_text (pk_entity, fk_project, full_text)
	SELECT pk_entity, fk_project, pgwar.get_project_full_text(fk_project, pk_entity)
	FROM pgwar.get_outdated_full_texts(max_limit)
	ON CONFLICT (pk_entity, fk_project)
	DO UPDATE
    SET full_text = EXCLUDED.full_text
	WHERE entity_full_text.full_text IS DISTINCT FROM EXCLUDED.full_text;
	
    -- Get the number of rows updated
    GET DIAGNOSTICS updated_count = ROW_COUNT;

    -- Return the result message
    RETURN 'Number of rows updated: ' || updated_count;
END;
$$;


--
-- TOC entry 2440 (class 1255 OID 948235)
-- Name: update_time_span(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_time_span() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text; -- Variable to store the job name
    _current_offset timestamp; -- Variable to store the current offset timestamp
BEGIN
    _job_name := 'update-time_span'; -- Initialize the job name

    -- Check if the offset for the job is already initialized
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        -- If not, initialize it with a default value
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2000-01-01 00:00:00.000000+00');
    END IF;

    -- Retrieve the current offset timestamp for the job
    SELECT offset_tmsp INTO _current_offset
    FROM pgwar.offsets
    WHERE job_name = _job_name;

        

    WITH ranked_statements AS (
        -- Assign a row number to each statement within the partition of fk_project, fk_subject_info, and fk_property,
        -- ordered by the columns you want to prioritize (e.g., timestamps or some other criteria).
        SELECT
            stmt.fk_project,
            stmt.fk_subject_info,
            stmt.fk_property,
            stmt.object_value,
            stmt.tmsp_last_modification AS stmt_modified,
            ROW_NUMBER() OVER (
                PARTITION BY stmt.fk_project, stmt.fk_subject_info, stmt.fk_property
                ORDER BY stmt.ord_num_of_range ASC, stmt.tmsp_last_modification DESC) AS rn
        FROM
            pgwar.v_statements_combined stmt
        WHERE
            stmt.fk_property IN (71,72,150,151,152,153)
    ),
    time_spans AS (
    -- Select only the first row (rn = 1) from each partition and aggregate results into JSON objects.
        SELECT
            fk_project,
            fk_subject_info,
            jsonb_object_agg(
                -- key
                CASE
                    WHEN fk_property = 71 THEN 'p81'
                    WHEN fk_property = 72 THEN 'p82'
                    WHEN fk_property = 150 THEN 'p81a'
                    WHEN fk_property = 151 THEN 'p81b'
                    WHEN fk_property = 152 THEN 'p82a'
                    WHEN fk_property = 153 THEN 'p82b'
                    ELSE fk_property::text -- Handle other properties if necessary
                END,
                -- value
                jsonb_build_object(
                    'calendar', object_value->'timePrimitive'->'calendar',
                    'duration', object_value->'timePrimitive'->'duration',
                    'julianDay', object_value->'timePrimitive'->'julianDay'
                )
            ) AS time_span,
            max(stmt_modified) AS most_recent_stmt_modification,
            min(( object_value->'timePrimitive'->'julianDay')::bigint * 24 * 60 * 60) AS first_second,
            max((( object_value->'timePrimitive'->'julianDay')::bigint +
                CASE
                    WHEN object_value->'timePrimitive'->'duration' = '"1 day"' THEN 1
                    WHEN object_value->'timePrimitive'->'duration' = '"1 month"' THEN 30
                    ELSE 365
                END
            )* 24 * 60 * 60 ) AS last_second
        FROM
            ranked_statements
        WHERE
            rn = 1
        GROUP BY
            fk_project,
            fk_subject_info
    ),
    get_time_spans AS (
        SELECT *
        FROM time_spans
        WHERE most_recent_stmt_modification > '2000-01-01 00:00:00.000000+00'
    )
    UPDATE pgwar.entity_preview ep
    SET time_span = ts.time_span,
        first_second = ts.first_second,
        last_second = ts.last_second
    FROM get_time_spans ts
    WHERE ts.fk_project = ep.fk_project
    AND ts.fk_subject_info = ep.pk_entity
    AND ep.time_span IS DISTINCT FROM ts.time_span;


    -- Update the offset table with the current timestamp to mark the job completion time
    UPDATE pgwar.offsets
    SET offset_tmsp = CURRENT_TIMESTAMP
    WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2441 (class 1255 OID 948237)
-- Name: update_type_label(); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.update_type_label() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_name text; -- Variable to store the job name
    _current_offset timestamp; -- Variable to store the current offset timestamp
BEGIN
    _job_name := 'update-type-label'; -- Initialize the job name

    -- Check if the offset for the job is already initialized
    IF NOT EXISTS(
        SELECT offset_tmsp
        FROM pgwar.offsets
        WHERE job_name = _job_name
    ) THEN
        -- If not, initialize it with a default value
        INSERT INTO pgwar.offsets (job_name, offset_tmsp)
        VALUES (_job_name, '2000-01-01 00:00:00.000000+00');
    END IF;

    -- Retrieve the current offset timestamp for the job
    SELECT offset_tmsp INTO _current_offset
    FROM pgwar.offsets
    WHERE job_name = _job_name;

    -- Identify the records in the entity_preview table that need updating
    WITH to_update AS (
        SELECT 
            origin.pk_entity, -- Primary key of the entity from the origin table
            origin.fk_project, -- Foreign key of the project from the origin table
            target.entity_label AS type_label -- Target entity label that will become the type_label of origin
        FROM 
            pgwar.entity_preview origin -- Origin entity preview (having fk_type)
        LEFT JOIN
            pgwar.entity_preview target ON -- Left join with the same table to find the referenced type entity 
                origin.fk_type = target.pk_entity AND -- Match type entity on fk_type
                origin.fk_project = target.fk_project AND -- Match on project ID
                origin.type_label IS DISTINCT FROM target.entity_label -- Ensure the type label is different between origin and target
        WHERE 
            origin.tmsp_fk_type_modification > _current_offset -- Check if origin's fk_type changed since the last offset timestamp
            OR target.tmsp_entity_label_modification > _current_offset -- Check if the target's label changed since the last offset timestamp
    )
    -- Update the entity_preview table with the new type labels
    UPDATE pgwar.entity_preview ep
    SET type_label = to_update.type_label
    FROM to_update
    WHERE ep.pk_entity = to_update.pk_entity
    AND ep.fk_project = to_update.fk_project;

    -- Update the offset table with the current timestamp to mark the job completion time
    UPDATE pgwar.offsets
    SET offset_tmsp = CURRENT_TIMESTAMP
    WHERE job_name = _job_name;

END;
$$;


--
-- TOC entry 2442 (class 1255 OID 948238)
-- Name: upsert_entity_preview_fk_class(integer, integer, integer); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.upsert_entity_preview_fk_class(entity_id integer, project_id integer, class_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO pgwar.entity_preview(pk_entity, fk_project, fk_class, tmsp_fk_class_modification)
        VALUES(entity_id, project_id, class_id, CURRENT_TIMESTAMP)
    ON CONFLICT(pk_entity, fk_project)
        DO UPDATE SET
            -- ... or update the fk_class
            fk_class = EXCLUDED.fk_class,
            tmsp_fk_class_modification = CURRENT_TIMESTAMP
        WHERE
            -- ... where it is distinct from previous value
            entity_preview.fk_class IS DISTINCT FROM EXCLUDED.fk_class;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 329 (class 1259 OID 948239)
-- Name: field_change; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.field_change (
    fk_project integer NOT NULL,
    fk_source_info integer NOT NULL,
    fk_source_tables_cell bigint,
    fk_property integer NOT NULL,
    is_outgoing boolean NOT NULL,
    tmsp_last_modification timestamp with time zone
);


--
-- TOC entry 2443 (class 1255 OID 948242)
-- Name: upsert_field_change(pgwar.field_change); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.upsert_field_change(fc pgwar.field_change) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO pgwar.field_change(
        fk_project,
        fk_source_info,
        fk_source_tables_cell,
        fk_property,
        is_outgoing,
        tmsp_last_modification
    )
    VALUES(

        fc.fk_project,
        fc.fk_source_info,
        fc.fk_source_tables_cell,
        fc.fk_property,
        fc.is_outgoing,
        fc.tmsp_last_modification
    )
    ON CONFLICT(fk_project, fk_source_info, fk_source_tables_cell, fk_property, is_outgoing)
    DO UPDATE SET
        -- ... or update the pgwar.statement
        fk_project = EXCLUDED.fk_project,
        fk_source_info = EXCLUDED.fk_source_info,
        fk_source_tables_cell = EXCLUDED.fk_source_tables_cell,
        fk_property = EXCLUDED.fk_property,
        is_outgoing = EXCLUDED.is_outgoing,
        tmsp_last_modification = EXCLUDED.tmsp_last_modification
    WHERE
        -- ... where it is distinct from previous value
        field_change.fk_project IS DISTINCT FROM EXCLUDED.fk_project OR
        field_change.fk_source_info IS DISTINCT FROM EXCLUDED.fk_source_info OR
        field_change.fk_source_tables_cell IS DISTINCT FROM EXCLUDED.fk_source_tables_cell OR
        field_change.fk_property IS DISTINCT FROM EXCLUDED.fk_property OR
        field_change.is_outgoing IS DISTINCT FROM EXCLUDED.is_outgoing OR
        field_change.tmsp_last_modification IS DISTINCT FROM EXCLUDED.tmsp_last_modification;
END;
$$;


--
-- TOC entry 330 (class 1259 OID 948243)
-- Name: project_statements; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.project_statements (
    pk_entity integer NOT NULL,
    fk_project integer NOT NULL,
    fk_subject_info integer,
    fk_property integer NOT NULL,
    fk_object_info integer,
    fk_object_tables_cell bigint,
    ord_num_of_domain numeric,
    ord_num_of_range numeric,
    object_label character varying(100),
    object_value jsonb,
    tmsp_last_modification timestamp with time zone
);


--
-- TOC entry 2444 (class 1255 OID 948248)
-- Name: upsert_project_statements(pgwar.project_statements); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.upsert_project_statements(ps pgwar.project_statements) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO pgwar.project_statements(
        pk_entity,
        fk_project,
        fk_subject_info,
        fk_property,
        fk_object_info,
        fk_object_tables_cell,
        ord_num_of_domain,
        ord_num_of_range,
        object_label,
        object_value
    )
    VALUES(
        ps.pk_entity,
        ps.fk_project,
        ps.fk_subject_info,
        ps.fk_property,
        ps.fk_object_info,
        ps.fk_object_tables_cell,
        ps.ord_num_of_domain,
        ps.ord_num_of_range,
        ps.object_label,
        ps.object_value
    )
    ON CONFLICT(pk_entity, fk_project)
        DO UPDATE SET
        -- ... or update the pgwar.statement
        fk_subject_info = EXCLUDED.fk_subject_info,
        fk_property = EXCLUDED.fk_property,
        fk_object_info = EXCLUDED.fk_object_info,
        fk_object_tables_cell = EXCLUDED.fk_object_tables_cell,
        ord_num_of_domain = EXCLUDED.ord_num_of_domain,
        ord_num_of_range = EXCLUDED.ord_num_of_range,
        object_label = EXCLUDED.object_label,
        object_value = EXCLUDED.object_value
    WHERE
        -- ... where it is distinct from previous value
        project_statements.fk_subject_info IS DISTINCT FROM EXCLUDED.fk_subject_info OR
        project_statements.fk_property IS DISTINCT FROM EXCLUDED.fk_property OR
        project_statements.fk_object_info IS DISTINCT FROM EXCLUDED.fk_object_info OR
        project_statements.fk_object_tables_cell IS DISTINCT FROM EXCLUDED.fk_object_tables_cell OR
        project_statements.ord_num_of_domain IS DISTINCT FROM EXCLUDED.ord_num_of_domain OR
        project_statements.ord_num_of_range IS DISTINCT FROM EXCLUDED.ord_num_of_range OR
        project_statements.object_label IS DISTINCT FROM EXCLUDED.object_label OR
        project_statements.object_value IS DISTINCT FROM EXCLUDED.object_value;
END;
$$;


--
-- TOC entry 331 (class 1259 OID 948249)
-- Name: statement; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.statement (
    pk_entity integer NOT NULL,
    fk_subject_info integer NOT NULL,
    fk_property integer NOT NULL,
    fk_object_info integer,
    fk_object_tables_cell bigint,
    object_label character varying(100),
    object_value jsonb
);


--
-- TOC entry 2445 (class 1255 OID 948254)
-- Name: upsert_statement(pgwar.statement); Type: FUNCTION; Schema: pgwar; Owner: -
--

CREATE FUNCTION pgwar.upsert_statement(stmt pgwar.statement) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO pgwar.statement(pk_entity,fk_subject_info,fk_property,fk_object_info,fk_object_tables_cell,object_label,object_value)
        VALUES(
          stmt.pk_entity,
          stmt.fk_subject_info,
          stmt.fk_property,
          stmt.fk_object_info,
          stmt.fk_object_tables_cell,
          stmt.object_label,
          stmt.object_value
        )
    ON CONFLICT(pk_entity)
        DO UPDATE SET
            -- ... or update the fk_class
            fk_subject_info = EXCLUDED.fk_subject_info,
            fk_property = EXCLUDED.fk_property,
            fk_object_info = EXCLUDED.fk_object_info,
            fk_object_tables_cell = EXCLUDED.fk_object_tables_cell,
            object_label = EXCLUDED.object_label,
            object_value = EXCLUDED.object_value
        WHERE
            -- ... where it is distinct from previous value
            statement.fk_subject_info IS DISTINCT FROM EXCLUDED.fk_subject_info OR
            statement.fk_property IS DISTINCT FROM EXCLUDED.fk_property OR
            statement.fk_object_info IS DISTINCT FROM EXCLUDED.fk_object_info OR
            statement.fk_object_tables_cell IS DISTINCT FROM EXCLUDED.fk_object_tables_cell OR
            statement.object_label IS DISTINCT FROM EXCLUDED.object_label OR
            statement.object_value IS DISTINCT FROM EXCLUDED.object_value;
END;
$$;


--
-- TOC entry 340 (class 1259 OID 948318)
-- Name: entity_preview; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.entity_preview (
    pk_entity integer NOT NULL,
    fk_project integer DEFAULT 0 NOT NULL,
    fk_class integer NOT NULL,
    entity_type text,
    class_label character varying,
    entity_label text,
    full_text text,
    ts_vector tsvector,
    type_label text,
    fk_type integer,
    time_span jsonb,
    first_second bigint,
    last_second bigint,
    parent_classes jsonb,
    ancestor_classes jsonb,
    tmsp_fk_class_modification timestamp with time zone,
    tmsp_fk_type_modification timestamp with time zone,
    tmsp_entity_label_modification timestamp with time zone,
    tmsp_last_modification timestamp with time zone
);


--
-- TOC entry 454 (class 1259 OID 948980)
-- Name: community_statements; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.community_statements (
    pk_entity integer NOT NULL,
    fk_subject_info integer,
    fk_property integer NOT NULL,
    fk_object_info integer,
    fk_object_tables_cell bigint,
    ord_num_of_domain numeric,
    ord_num_of_range numeric,
    object_label character varying(100),
    object_value jsonb,
    tmsp_last_modification timestamp with time zone
);


--
-- TOC entry 455 (class 1259 OID 948985)
-- Name: community_statements_deleted; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.community_statements_deleted (
    pk_entity integer NOT NULL,
    fk_subject_info integer,
    fk_property integer NOT NULL,
    fk_object_info integer,
    object_value jsonb,
    tmsp_deletion timestamp with time zone
);


--
-- TOC entry 456 (class 1259 OID 948990)
-- Name: entity_full_text; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.entity_full_text (
    pk_entity integer NOT NULL,
    fk_project integer NOT NULL,
    full_text text,
    tmsp_last_modification timestamp with time zone
);


--
-- TOC entry 457 (class 1259 OID 948995)
-- Name: initialization; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.initialization (
    msg text,
    tmsp timestamp without time zone
);


--
-- TOC entry 458 (class 1259 OID 949000)
-- Name: offsets; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.offsets (
    job_name text NOT NULL,
    offset_tmsp timestamp with time zone
);


--
-- TOC entry 459 (class 1259 OID 949008)
-- Name: project_statements_deleted; Type: TABLE; Schema: pgwar; Owner: -
--

CREATE TABLE pgwar.project_statements_deleted (
    pk_entity integer NOT NULL,
    fk_project integer NOT NULL,
    fk_subject_info integer,
    fk_property integer NOT NULL,
    fk_object_info integer,
    object_value jsonb,
    tmsp_deletion timestamp with time zone
);


--
-- TOC entry 462 (class 1259 OID 949041)
-- Name: v_class_preview; Type: VIEW; Schema: pgwar; Owner: -
--

CREATE VIEW pgwar.v_class_preview AS
 WITH tw0 AS (
         SELECT project.pk_entity,
            project.fk_language
           FROM projects.project
        UNION ALL
         SELECT NULL::integer AS int4,
            18889
        ), tw1 AS (
         SELECT t2.fk_dfh_class AS fk_class,
            t1.pk_entity AS fk_project,
            t2.string AS label,
            1 AS rank,
            'project label'::text AS text
           FROM tw0 t1,
            projects.text_property t2
          WHERE ((t1.pk_entity = t2.fk_project) AND (t2.fk_dfh_class IS NOT NULL) AND (t2.fk_language = t1.fk_language))
        UNION ALL
         SELECT t2.fk_dfh_class AS fk_class,
            t1.pk_entity AS fk_project,
            t2.string AS label,
            2 AS rank,
            'default project label in default lang'::text AS text
           FROM tw0 t1,
            projects.text_property t2
          WHERE ((375669 = t2.fk_project) AND (t2.fk_dfh_class IS NOT NULL) AND (t2.fk_language = t1.fk_language))
        UNION ALL
         SELECT t3.fk_class,
            t1.pk_entity AS fk_project,
            t3.label,
            3 AS rank,
            'ontome label in default lang'::text AS text
           FROM tw0 t1,
            information.language t2,
            data_for_history.v_label t3
          WHERE ((t3.fk_class IS NOT NULL) AND (t1.fk_language = t2.pk_entity) AND ((t3.language)::bpchar = t2.iso6391) AND (t3.type = 'label'::text))
        UNION ALL
         SELECT t2.fk_dfh_class AS fk_class,
            t1.pk_entity AS fk_project,
            t2.string AS label,
            4 AS rank,
            'default project label in en'::text AS text
           FROM tw0 t1,
            projects.text_property t2
          WHERE ((375669 = t2.fk_project) AND (t2.fk_dfh_class IS NOT NULL) AND (t2.fk_language = 18889))
        UNION ALL
         SELECT t3.fk_class,
            t1.pk_entity AS fk_project,
            t3.label,
            5 AS rank,
            'ontome label in en'::text AS text
           FROM tw0 t1,
            data_for_history.v_label t3
          WHERE ((t3.fk_class IS NOT NULL) AND ((t3.language)::text = 'en'::text) AND (t3.type = 'label'::text))
        )
 SELECT DISTINCT ON (fk_project, fk_class) fk_class,
    fk_project,
    label
   FROM tw1
  ORDER BY fk_project, fk_class, rank;


--
-- TOC entry 463 (class 1259 OID 949046)
-- Name: v_community_entity_label; Type: VIEW; Schema: pgwar; Owner: -
--

CREATE VIEW pgwar.v_community_entity_label AS
 WITH entity_label_counts AS (
         SELECT ep.pk_entity,
            ep.entity_label,
            count(*) AS label_count
           FROM pgwar.entity_preview ep
          WHERE (ep.fk_project <> 0)
          GROUP BY ep.pk_entity, ep.entity_label
        ), ranked_entity_labels AS (
         SELECT entity_label_counts.pk_entity,
            entity_label_counts.entity_label,
            entity_label_counts.label_count,
            row_number() OVER (PARTITION BY entity_label_counts.pk_entity ORDER BY entity_label_counts.label_count DESC, entity_label_counts.entity_label) AS rn
           FROM entity_label_counts
        )
 SELECT pk_entity,
    entity_label
   FROM ranked_entity_labels
  WHERE (rn = 1);


--
-- TOC entry 464 (class 1259 OID 949051)
-- Name: v_property_preview; Type: VIEW; Schema: pgwar; Owner: -
--

CREATE VIEW pgwar.v_property_preview AS
 WITH tw0 AS (
         SELECT project.pk_entity,
            project.fk_language
           FROM projects.project
        UNION ALL
         SELECT NULL::integer AS int4,
            18889
        ), tw1 AS (
         SELECT t2.fk_dfh_property AS fk_property,
            t1.pk_entity AS fk_project,
            t2.string AS label,
            1 AS rank,
            'project label'::text AS text
           FROM tw0 t1,
            projects.text_property t2
          WHERE ((t1.pk_entity = t2.fk_project) AND (t2.fk_dfh_property IS NOT NULL) AND (t2.fk_language = t1.fk_language))
        UNION ALL
         SELECT t2.fk_dfh_property AS fk_property,
            t1.pk_entity AS fk_project,
            t2.string AS label,
            2 AS rank,
            'default project label in default lang'::text AS text
           FROM tw0 t1,
            projects.text_property t2
          WHERE ((375669 = t2.fk_project) AND (t2.fk_dfh_property IS NOT NULL) AND (t2.fk_language = t1.fk_language))
        UNION ALL
         SELECT t3.fk_property,
            t1.pk_entity AS fk_project,
            t3.label,
            3 AS rank,
            'ontome label in default lang'::text AS text
           FROM tw0 t1,
            information.language t2,
            data_for_history.v_label t3
          WHERE ((t3.fk_property IS NOT NULL) AND ((t3.language)::bpchar = t2.iso6391) AND (t3.type = 'label'::text))
        UNION ALL
         SELECT t2.fk_dfh_property AS fk_property,
            t1.pk_entity AS fk_project,
            t2.string AS label,
            4 AS rank,
            'default project label in en'::text AS text
           FROM tw0 t1,
            projects.text_property t2
          WHERE ((375669 = t2.fk_project) AND (t2.fk_dfh_property IS NOT NULL) AND (t2.fk_language = 18889))
        UNION ALL
         SELECT t3.fk_property,
            t1.pk_entity AS fk_project,
            t3.label,
            3 AS rank,
            'ontome label in en'::text AS text
           FROM tw0 t1,
            data_for_history.v_label t3
          WHERE ((t3.fk_property IS NOT NULL) AND ((t3.language)::text = 'en'::text) AND (t3.type = 'label'::text))
        )
 SELECT DISTINCT ON (fk_project, fk_property) fk_property,
    fk_project,
    label
   FROM tw1
  ORDER BY fk_project, fk_property, rank;


--
-- TOC entry 465 (class 1259 OID 949056)
-- Name: v_statements_combined; Type: VIEW; Schema: pgwar; Owner: -
--

CREATE VIEW pgwar.v_statements_combined AS
 SELECT community_statements.pk_entity,
    0 AS fk_project,
    community_statements.fk_subject_info,
    community_statements.fk_property,
    community_statements.fk_object_info,
    community_statements.fk_object_tables_cell,
    community_statements.ord_num_of_domain,
    community_statements.ord_num_of_range,
    community_statements.object_label,
    community_statements.object_value,
    community_statements.tmsp_last_modification
   FROM pgwar.community_statements
UNION ALL
 SELECT project_statements.pk_entity,
    project_statements.fk_project,
    project_statements.fk_subject_info,
    project_statements.fk_property,
    project_statements.fk_object_info,
    project_statements.fk_object_tables_cell,
    project_statements.ord_num_of_domain,
    project_statements.ord_num_of_range,
    project_statements.object_label,
    project_statements.object_value,
    project_statements.tmsp_last_modification
   FROM pgwar.project_statements;


--
-- TOC entry 466 (class 1259 OID 949061)
-- Name: v_statements_deleted_combined; Type: VIEW; Schema: pgwar; Owner: -
--

CREATE VIEW pgwar.v_statements_deleted_combined AS
 SELECT community_statements_deleted.pk_entity,
    0 AS fk_project,
    community_statements_deleted.fk_subject_info,
    community_statements_deleted.fk_property,
    community_statements_deleted.fk_object_info,
    community_statements_deleted.object_value,
    community_statements_deleted.tmsp_deletion
   FROM pgwar.community_statements_deleted
UNION ALL
 SELECT project_statements_deleted.pk_entity,
    project_statements_deleted.fk_project,
    project_statements_deleted.fk_subject_info,
    project_statements_deleted.fk_property,
    project_statements_deleted.fk_object_info,
    project_statements_deleted.object_value,
    project_statements_deleted.tmsp_deletion
   FROM pgwar.project_statements_deleted;


--
-- TOC entry 8749 (class 2606 OID 1046594)
-- Name: community_statements_deleted community_statements_deleted_pkey; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.community_statements_deleted
    ADD CONSTRAINT community_statements_deleted_pkey PRIMARY KEY (pk_entity);


--
-- TOC entry 8746 (class 2606 OID 1014542)
-- Name: community_statements community_statements_pkey; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.community_statements
    ADD CONSTRAINT community_statements_pkey PRIMARY KEY (pk_entity);


--
-- TOC entry 8751 (class 2606 OID 1027592)
-- Name: entity_full_text entity_full_text_pkey; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.entity_full_text
    ADD CONSTRAINT entity_full_text_pkey PRIMARY KEY (pk_entity, fk_project);


--
-- TOC entry 8739 (class 2606 OID 1005725)
-- Name: entity_preview entity_preview_pkey; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.entity_preview
    ADD CONSTRAINT entity_preview_pkey PRIMARY KEY (pk_entity, fk_project);


--
-- TOC entry 8721 (class 2606 OID 1030611)
-- Name: field_change field_change_fk_project_fk_source_info_fk_source_tables_cel_key; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.field_change
    ADD CONSTRAINT field_change_fk_project_fk_source_info_fk_source_tables_cel_key UNIQUE NULLS NOT DISTINCT (fk_project, fk_source_info, fk_source_tables_cell, fk_property, is_outgoing);


--
-- TOC entry 8754 (class 2606 OID 1044363)
-- Name: offsets offsets_pkey; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.offsets
    ADD CONSTRAINT offsets_pkey PRIMARY KEY (job_name);


--
-- TOC entry 8756 (class 2606 OID 1046592)
-- Name: project_statements_deleted project_statements_deleted_pkey; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.project_statements_deleted
    ADD CONSTRAINT project_statements_deleted_pkey PRIMARY KEY (pk_entity, fk_project);


--
-- TOC entry 8731 (class 2606 OID 1014521)
-- Name: project_statements project_statements_pkey; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.project_statements
    ADD CONSTRAINT project_statements_pkey PRIMARY KEY (pk_entity, fk_project);


--
-- TOC entry 8734 (class 2606 OID 1014510)
-- Name: statement statement_pkey; Type: CONSTRAINT; Schema: pgwar; Owner: -
--

ALTER TABLE ONLY pgwar.statement
    ADD CONSTRAINT statement_pkey PRIMARY KEY (pk_entity);


--
-- TOC entry 8740 (class 1259 OID 1014518)
-- Name: community_statements_fk_object_info_fk_property_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX community_statements_fk_object_info_fk_property_idx ON pgwar.community_statements USING btree (fk_object_info, fk_property);


--
-- TOC entry 8741 (class 1259 OID 1014519)
-- Name: community_statements_fk_object_info_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX community_statements_fk_object_info_idx ON pgwar.community_statements USING btree (fk_object_info);


--
-- TOC entry 8742 (class 1259 OID 1014524)
-- Name: community_statements_fk_property_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX community_statements_fk_property_idx ON pgwar.community_statements USING btree (fk_property);


--
-- TOC entry 8743 (class 1259 OID 1014525)
-- Name: community_statements_fk_subject_info_fk_property_dx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX community_statements_fk_subject_info_fk_property_dx ON pgwar.community_statements USING btree (fk_subject_info, fk_property);


--
-- TOC entry 8744 (class 1259 OID 1014533)
-- Name: community_statements_fk_subject_info_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX community_statements_fk_subject_info_idx ON pgwar.community_statements USING btree (fk_subject_info);


--
-- TOC entry 8747 (class 1259 OID 1014534)
-- Name: community_statements_tmsp_last_modification_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX community_statements_tmsp_last_modification_idx ON pgwar.community_statements USING btree (tmsp_last_modification DESC NULLS LAST);


--
-- TOC entry 8752 (class 1259 OID 1028135)
-- Name: entity_full_text_tmsp_last_modification_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX entity_full_text_tmsp_last_modification_idx ON pgwar.entity_full_text USING btree (tmsp_last_modification);


--
-- TOC entry 8735 (class 1259 OID 1005705)
-- Name: entity_preview_entity_label_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX entity_preview_entity_label_idx ON pgwar.entity_preview USING btree (entity_label);


--
-- TOC entry 8736 (class 1259 OID 1005711)
-- Name: entity_preview_fk_class_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX entity_preview_fk_class_idx ON pgwar.entity_preview USING btree (fk_class);


--
-- TOC entry 8737 (class 1259 OID 1005712)
-- Name: entity_preview_fk_project_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX entity_preview_fk_project_idx ON pgwar.entity_preview USING btree (fk_project);


--
-- TOC entry 8757 (class 1259 OID 1046595)
-- Name: project_statements_deleted_tmsp_deletion_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_deleted_tmsp_deletion_idx ON pgwar.project_statements_deleted USING btree (tmsp_deletion);


--
-- TOC entry 8722 (class 1259 OID 1014467)
-- Name: project_statements_fk_object_info_fk_project_fk_property_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_fk_object_info_fk_project_fk_property_idx ON pgwar.project_statements USING btree (fk_object_info, fk_project, fk_property);


--
-- TOC entry 8723 (class 1259 OID 1014495)
-- Name: project_statements_fk_object_info_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_fk_object_info_idx ON pgwar.project_statements USING btree (fk_object_info);


--
-- TOC entry 8724 (class 1259 OID 1014496)
-- Name: project_statements_fk_project_dx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_fk_project_dx ON pgwar.project_statements USING btree (fk_project);


--
-- TOC entry 8725 (class 1259 OID 1014499)
-- Name: project_statements_fk_project_fk_property_dx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_fk_project_fk_property_dx ON pgwar.project_statements USING btree (fk_project, fk_property);


--
-- TOC entry 8726 (class 1259 OID 1014500)
-- Name: project_statements_fk_property_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_fk_property_idx ON pgwar.project_statements USING btree (fk_property);


--
-- TOC entry 8727 (class 1259 OID 1014501)
-- Name: project_statements_fk_subject_info_fk_project_fk_property_dx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_fk_subject_info_fk_project_fk_property_dx ON pgwar.project_statements USING btree (fk_subject_info, fk_project, fk_property);


--
-- TOC entry 8728 (class 1259 OID 1014504)
-- Name: project_statements_fk_subject_info_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_fk_subject_info_idx ON pgwar.project_statements USING btree (fk_subject_info);


--
-- TOC entry 8729 (class 1259 OID 1014505)
-- Name: project_statements_outgoing_order_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_outgoing_order_idx ON pgwar.project_statements USING btree (ord_num_of_range, tmsp_last_modification DESC);


--
-- TOC entry 8732 (class 1259 OID 1014506)
-- Name: project_statements_tmsp_last_modification_idx; Type: INDEX; Schema: pgwar; Owner: -
--

CREATE INDEX project_statements_tmsp_last_modification_idx ON pgwar.project_statements USING btree (tmsp_last_modification);


--
-- TOC entry 8773 (class 2620 OID 1014543)
-- Name: community_statements after_delete_community_statements; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_delete_community_statements AFTER DELETE ON pgwar.community_statements FOR EACH ROW EXECUTE FUNCTION pgwar.handle_community_statements_delete();


--
-- TOC entry 8768 (class 2620 OID 1007803)
-- Name: entity_preview after_delete_entity_preview_01; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_delete_entity_preview_01 AFTER DELETE ON pgwar.entity_preview REFERENCING OLD TABLE AS oldtab FOR EACH STATEMENT EXECUTE FUNCTION pgwar.update_entity_labels_after_delete();


--
-- TOC entry 8766 (class 2620 OID 1014522)
-- Name: statement after_delete_pgw_statement; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_delete_pgw_statement AFTER DELETE ON pgwar.statement FOR EACH ROW EXECUTE FUNCTION pgwar.after_delete_pgw_statement();


--
-- TOC entry 8760 (class 2620 OID 1014526)
-- Name: project_statements after_delete_project_statement; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_delete_project_statement AFTER DELETE ON pgwar.project_statements REFERENCING OLD TABLE AS oldtab FOR EACH STATEMENT EXECUTE FUNCTION pgwar.update_entity_label_on_project_statement_delete();


--
-- TOC entry 8761 (class 2620 OID 1014527)
-- Name: project_statements after_delete_project_statements; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_delete_project_statements AFTER DELETE ON pgwar.project_statements FOR EACH ROW EXECUTE FUNCTION pgwar.handle_project_statements_delete();


--
-- TOC entry 8774 (class 2620 OID 1030298)
-- Name: entity_full_text after_insert_entity_full_text; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_insert_entity_full_text AFTER INSERT ON pgwar.entity_full_text REFERENCING NEW TABLE AS newtab FOR EACH STATEMENT EXECUTE FUNCTION pgwar.update_entity_preview_full_text();


--
-- TOC entry 8758 (class 2620 OID 1030652)
-- Name: field_change after_insert_field_change; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_insert_field_change AFTER INSERT ON pgwar.field_change REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION pgwar.field_change_notify_upsert();


--
-- TOC entry 8769 (class 2620 OID 1007804)
-- Name: entity_preview after_insert_on_entity_preview; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_insert_on_entity_preview AFTER INSERT ON pgwar.entity_preview REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION pgwar.entity_previews_notify_upsert();


--
-- TOC entry 8762 (class 2620 OID 1014528)
-- Name: project_statements after_insert_project_statement; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_insert_project_statement AFTER INSERT ON pgwar.project_statements REFERENCING NEW TABLE AS newtab FOR EACH STATEMENT EXECUTE FUNCTION pgwar.update_entity_label_on_project_statement_upsert();


--
-- TOC entry 8763 (class 2620 OID 1014529)
-- Name: project_statements after_modify_project_statements; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE CONSTRAINT TRIGGER after_modify_project_statements AFTER INSERT OR DELETE OR UPDATE ON pgwar.project_statements DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION pgwar.update_field_change_on_project_statements_modification();


--
-- TOC entry 8775 (class 2620 OID 1030308)
-- Name: entity_full_text after_update_entity_full_text; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_update_entity_full_text AFTER UPDATE ON pgwar.entity_full_text REFERENCING NEW TABLE AS newtab FOR EACH STATEMENT EXECUTE FUNCTION pgwar.update_entity_preview_full_text();


--
-- TOC entry 8759 (class 2620 OID 1030653)
-- Name: field_change after_update_field_change; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_update_field_change AFTER UPDATE ON pgwar.field_change REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION pgwar.field_change_notify_upsert();


--
-- TOC entry 8770 (class 2620 OID 1007805)
-- Name: entity_preview after_update_on_entity_preview; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_update_on_entity_preview AFTER UPDATE ON pgwar.entity_preview REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION pgwar.entity_previews_notify_update();

ALTER TABLE pgwar.entity_preview DISABLE TRIGGER after_update_on_entity_preview;


--
-- TOC entry 8764 (class 2620 OID 1014531)
-- Name: project_statements after_update_project_statement; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_update_project_statement AFTER UPDATE ON pgwar.project_statements REFERENCING NEW TABLE AS newtab FOR EACH STATEMENT EXECUTE FUNCTION pgwar.update_entity_label_on_project_statement_upsert();


--
-- TOC entry 8767 (class 2620 OID 1014523)
-- Name: statement after_upsert_pgw_statement; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER after_upsert_pgw_statement AFTER INSERT OR UPDATE ON pgwar.statement FOR EACH ROW EXECUTE FUNCTION pgwar.after_upsert_pgw_statement();


--
-- TOC entry 8776 (class 2620 OID 1030316)
-- Name: entity_full_text last_modification_tmsp; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER last_modification_tmsp BEFORE INSERT OR UPDATE ON pgwar.entity_full_text FOR EACH ROW EXECUTE FUNCTION commons.tmsp_last_modification();


--
-- TOC entry 8771 (class 2620 OID 1007806)
-- Name: entity_preview last_modification_tmsp; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER last_modification_tmsp BEFORE INSERT OR UPDATE ON pgwar.entity_preview FOR EACH ROW EXECUTE FUNCTION commons.tmsp_last_modification();


--
-- TOC entry 8765 (class 2620 OID 1014532)
-- Name: project_statements last_modification_tmsp; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER last_modification_tmsp BEFORE INSERT OR UPDATE ON pgwar.project_statements FOR EACH ROW EXECUTE FUNCTION commons.tmsp_last_modification();


--
-- TOC entry 8772 (class 2620 OID 1007807)
-- Name: entity_preview on_upsert_entity_preview_set_ts_vector; Type: TRIGGER; Schema: pgwar; Owner: -
--

CREATE TRIGGER on_upsert_entity_preview_set_ts_vector BEFORE INSERT OR UPDATE OF entity_label, type_label, class_label, full_text ON pgwar.entity_preview FOR EACH ROW EXECUTE FUNCTION pgwar.entity_preview_ts_vector();


-- Completed on 2026-01-16 16:07:06

--
-- PostgreSQL database dump complete
--

