begin;

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
