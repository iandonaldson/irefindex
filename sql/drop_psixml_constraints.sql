begin;

alter table xml_interactors drop constraint xml_interactors_pkey;
analyze xml_interactors;

alter table xml_names alter column name drop not null;
analyze xml_names;

commit;
