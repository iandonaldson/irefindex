drop table bind_interactors;
drop table bind_complexes;
drop table bind_references;
drop table bind_complex_references;
drop table bind_labels;

-- Remove BIND-related records from the common representation.

begin;

delete from xml_interactors where source = 'BIND';
delete from xml_organisms where source = 'BIND';
delete from xml_xref where source = 'BIND';
delete from xml_names where source = 'BIND';
delete from xml_sequences where source = 'BIND';
delete from xml_experiments where source = 'BIND';

commit;
