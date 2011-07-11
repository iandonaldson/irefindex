begin;

-- Several workarounds are required before adding constraints.

-- Remove useless records.

delete from xml_names where name is null;
delete from xml_xref where refvalue is null;

-- Remove duplicate OPHID experiment references.

create temporary table tmp_experiments as
    select distinct source, filename, experimentid, interactionid
    from xml_experiments
    where source = 'OPHID';

delete from xml_experiments where source = 'OPHID';
insert into xml_experiments select * from tmp_experiments;

-- Now the constraints can be added.

alter table xml_experiments add primary key (source, filename, experimentid, interactionid);
analyze xml_experiments;

alter table xml_interactors add primary key (source, filename, interactorid, participantid, interactionid);
analyze xml_interactors;

alter table xml_names alter column name set not null;
analyze xml_names;

alter table xml_xref alter column refvalue set not null;
analyze xml_xref;

analyze xml_organisms;

commit;
