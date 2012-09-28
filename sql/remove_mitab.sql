begin;

delete from mitab_aliases where source = '<source>';
delete from mitab_alternatives where source = '<source>';
delete from mitab_authors where source = '<source>';
delete from mitab_confidence where source = '<source>';
delete from mitab_interaction_identifiers where source = '<source>';
delete from mitab_interaction_type_names where source = '<source>';
delete from mitab_method_names where source = '<source>';
delete from mitab_pubmed where source = '<source>';
delete from mitab_sources where source = '<source>';

commit;
