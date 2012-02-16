begin;

-- Several workarounds are required before adding constraints.

-- Remove useless records.

delete from xml_names where name is null;
delete from xml_xref where refvalue is null;

-- Now the constraints can be added.

analyze xml_experiments;

alter table xml_interactors add primary key (source, filename, entry, interactorid, participantid, interactionid);
analyze xml_interactors;

alter table xml_names alter column name set not null;
analyze xml_names;

alter table xml_xref alter column refvalue set not null;
analyze xml_xref;

analyze xml_organisms;

-- Add an interaction summary table.

insert into xml_interactions
    select interactionid, count(distinct interactorid) as participants
    from xml_interactors
    group by interactionid;

analyze xml_interactions;

commit;
