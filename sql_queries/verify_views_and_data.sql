
--manque le label pour le projet 1483135
select *
from pgwar.entity_preview ep 
where ep.pk_entity = 6492226 --6558492 --1644967 --8377516;

/*
 * Problème avec le warehouse : personnes en trop dans le projet ?
 */

select pk_entity, max(fk_class) as fk_class, max(entity_label) as label 
from pgwar.entity_preview  
where pk_entity = 6492226 --1644967 --1598759  --8377516
and fk_project in (0, 1483135)
group by pk_entity;


select *
from projects.info_proj_rel ipr 
where fk_entity = 6492226
limit 10;

select ep1.pk_entity, ep1.fk_class, 
coalesce (ep1.entity_label , ep2.entity_label, 'no label') as entity_label,
ep2.fk_class
from pgwar.entity_preview  ep1, pgwar.entity_preview ep2
where ep1.fk_project = 1483135
and ep2.fk_project = 0
and ep2.pk_entity = ep1.pk_entity
limit 10;



select ep1.pk_entity, ep1.fk_class, 
coalesce (ep1.entity_label , ep2.entity_label, 'no label') as entity_label,
ep1.fk_project
from pgwar.entity_preview  ep1, pgwar.entity_preview ep2
where ep1.fk_project = 1483135
and ep2.fk_project = 0
and ep2.pk_entity = ep1.pk_entity
and ep1.fk_class not in (52, 84, 689, 52, 689, 709, 711, 717)
limit 10;



select ep1.pk_entity, ep1.fk_class, cls.top_level_namespace_uri || cls.identifier_in_namespace AS class_uri,
coalesce (ep1.entity_label , ep2.entity_label, 'no label') as entity_label,
ep1.fk_project
from pgwar.entity_preview  ep1, 
	pgwar.entity_preview ep2,
	che.class_with_namespace cls
where ep2.fk_project = 0
and ep1.fk_project != 0
and ep2.pk_entity = ep1.pk_entity
and ep1.fk_class not in (52, 84, 689, 52, 689, 709, 711, 717)
and ep1.fk_class = cls.pk_class
limit 10;




create or replace view rdf.v_ontop_entity_preview_corr as
select ep1.pk_entity, ep1.fk_class, cls.top_level_namespace_uri || cls.identifier_in_namespace AS class_uri,
coalesce (ep1.entity_label , ep2.entity_label) as entity_label,
ep1.fk_project
from pgwar.entity_preview  ep1, 
	pgwar.entity_preview ep2,
	che.class_with_namespace cls
where ep2.fk_project = 0
and ep1.fk_project != 0
and ep2.pk_entity = ep1.pk_entity
and ep1.fk_class not in (52, 84, 689, 52, 689, 709, 711, 717)
and ep1.fk_class = cls.pk_class
and coalesce (ep1.entity_label , ep2.entity_label) is not null;
     
    
    
select pk_entity, class_uri, entity_label
from rdf.v_ontop_entity_preview_corr
where fk_project = 1483135
limit 10;

select count(*) as number
from rdf.v_ontop_entity_preview_corr
where fk_project = 1483135;

create view rdf.v_ontop_1483135_entity_preview as
select pk_entity, class_uri, entity_label
from rdf.v_ontop_entity_preview_corr
where fk_project = 1483135;



select count(*) as number
from rdf.v_ontop_1483135_entity_preview;
  
 
 

