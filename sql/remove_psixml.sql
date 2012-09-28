begin;

delete from xml_experiments where source = '<source>';
delete from xml_interactors where source = '<source>';
delete from xml_names where source = '<source>';
delete from xml_xref where source = '<source>';
delete from xml_organisms where source = '<source>';
delete from xml_sequences where source = '<source>';

commit;
