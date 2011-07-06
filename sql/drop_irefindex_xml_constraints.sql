begin;

alter table xml_experiments drop constraint xml_experiments_pkey;
analyze xml_experiments;

alter table xml_interactors drop constraint xml_interactors_pkey;
analyze xml_interactors;

alter table xml_participants drop constraint xml_participants_pkey;
analyze xml_participants;

alter table xml_names alter column name drop not null;
analyze xml_names;

commit;
