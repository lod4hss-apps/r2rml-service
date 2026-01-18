
select *
from rdf.v_ontop_project_statements
limit 10;



SELECT ps.pk_entity,
    ps.fk_project,
    ps.fk_subject_info,
    ps.fk_property,
    ps.fk_object_info,
    ps.fk_object_tables_cell,
    ps.ord_num_of_domain,
    ps.ord_num_of_range,
        CASE
            WHEN ps.fk_property = ANY (ARRAY[71, 72, 150, 151, 152, 153]) THEN
            CASE
                WHEN ps.object_label::text ~~ '%(1 day)%'::text THEN "substring"(ps.object_label::text, '(-?\d{4}-\d{2}-\d{2})'::text)::character varying
                WHEN ps.object_label::text ~~ '%(1 month)%'::text THEN "substring"(ps.object_label::text, '(-?\d{4}-\d{2})'::text)::character varying
                WHEN ps.object_label::text ~~ '%(1 year)%'::text THEN "substring"(ps.object_label::text, '(-?\d{4})'::text)::character varying
                ELSE ps.object_label
            END
            ELSE ps.object_label
        END AS object_label,
    ps.tmsp_last_modification,
    prop.property_standard_label,
    prop.top_level_namespace_uri || prop.identifier_in_namespace AS property_uri
    FROM pgwar.project_statements ps
    JOIN che.property_with_namespace prop ON ps.fk_property = prop.pk_property
    LIMIT 10;

   
   
 
SELECT ps.pk_entity,
    ps.fk_project,
    ps.fk_subject_info,
    ps.fk_property,
    ps.fk_object_info,
    ps.fk_object_tables_cell,
    ps.ord_num_of_domain,
    ps.ord_num_of_range,
    ps.object_label,
ps.tmsp_last_modification,
prop.property_standard_label,
prop.top_level_namespace_uri || prop.identifier_in_namespace AS property_uri
FROM pgwar.project_statements ps
JOIN che.property_with_namespace prop ON ps.fk_property = prop.pk_property
where ps.fk_property != ANY (ARRAY[40,74, 71, 72, 148, 150, 151, 152, 153, 1109,1613, 1618,
	1621,1622,1623, 1647, 1648, 1742, 1875, 2314])
LIMIT 10;
   
   
   
   
/*
 * 
 * Properties: 
 * 148  crm:P167 was at (was place of) (1,1:1,1) → crm:E53 Place 
 * 
 * Autres projets (Parthenos)
 * 1109
 * 1875
 * 
 * ATTENTION 
 * Manque :  
 * crm:P168 place is defined by (defines place) (1,1:0,n) → crm:E94 Space Primitive 
 */
   
   
   
-- 1. get geo-coordinates
select p.*
from pgwar.project_statements ps 
	join information.place p on p.pk_entity = ps.fk_object_info 
limit 10;

-- 2. properties with geo-coordinates
select distinct ps.fk_property 
from pgwar.project_statements ps 
	join information.place p on p.pk_entity = ps.fk_object_info 
limit 100;



-- 3. properties with geo-coordinates in community project 1483135
select distinct ps.fk_property 
from pgwar.project_statements ps 
	join information.place p on p.pk_entity = ps.fk_object_info 
	where ps.fk_project = 1483135
limit 100;

-- 4. get geo-coordinates
select p.*
from pgwar.project_statements ps 
	join information.place p on p.pk_entity = ps.fk_object_info 
	where ps.fk_project = 1483135
limit 10;


-- 5. get geo-coordinates: relevant columns
select ps.fk_project, ps.fk_subject_info, ps.fk_property, ps.fk_object_info, p.geo_point 
from pgwar.project_statements ps 
	join information.place p on p.pk_entity = ps.fk_object_info 
	where ps.fk_project = 1483135
limit 10;


select *
from che.property_with_namespace
limit 10;

--
drop view rdf.v_ontop_project_statements_places;
create or replace view rdf.v_ontop_project_statements_places as
select ps.fk_project, ps.fk_subject_info, ps.fk_property, 
prop.top_level_namespace_uri || prop.identifier_in_namespace AS property_uri,
prop.property_standard_label, ps.fk_object_info, p.geo_point 
from pgwar.project_statements ps 
	join information.place p on p.pk_entity = ps.fk_object_info
	JOIN che.property_with_namespace prop ON ps.fk_property = prop.pk_property; 


--
select *
from rdf.v_ontop_project_statements_places
where fk_project = 1483135
limit 10;


select pk_entity, coalesce(entity_label, 'no label') entity_label, class_uri 
from rdf.v_ontop_entity_preview
where fk_project = 1483135
and class_uri not in ('http://www.cidoc-crm.org/cidoc-crm/E93')
--and length(entity_label) > 0
limit 10;


/*
52
689
709
711
717
 */

select distinct fk_class 
from information.dimension
order by fk_class ;



/*
 * 
 * 
 * 40  has dimension (is dimension of) – crm:P43
 * 74  had at most duration (was maximum duration of) – crm:P84
1613
1618
1621
1622
1623
1647
1648
1742
2314

 * 
 */


-- 1. get dimensions
select d.*
from pgwar.project_statements ps 
	join information.dimension d on d.pk_entity = ps.fk_object_info 
limit 10;

-- 2. properties with geo-coordinates
select distinct ps.fk_property 
from pgwar.project_statements ps 
	join information.dimension d on d.pk_entity = ps.fk_object_info  
order by fk_property	
limit 100;
    