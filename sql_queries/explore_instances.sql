

/*
* Instances per project
*/

select ep.fk_project, tp.string project_label, count(*) as number
from pgwar.entity_preview ep,
   projects.text_property tp
-- verify which field is to use and if error in data
where tp.fk_project = ep.fk_project 
-- where tp.fk_pro_project = ep.fk_project 	
and tp.fk_system_type = 639
group by ep.fk_project, tp.string
order by number desc;


select *
from projects.text_property tp 
where tp.fk_project = 6532536;


select ep.fk_project, ep.fk_class, count(*) as number
from pgwar.entity_preview ep 
group by ep.fk_project, ep.fk_class
order by number desc;