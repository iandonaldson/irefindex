begin;

alter table xml_experiments add primary key (source, filename, experimentid, interactionid);
analyze xml_experiments;

alter table xml_interactors add primary key (source, filename, interactorid, participantid);
analyze xml_interactors;

alter table xml_participants add primary key (source, filename, participantid, interactionid);
analyze xml_participants;

alter table xml_names alter column name set not null;
analyze xml_names;

analyze xml_xref;

analyze xml_organisms;

commit;
