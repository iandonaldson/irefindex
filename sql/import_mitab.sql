begin;

\copy mitab_uid from '<directory>/mitab_uid.txt'
-- \copy mitab_alternatives from '<directory>/mitab_alternatives.txt'
\copy mitab_aliases from '<directory>/mitab_alias.txt'
\copy mitab_method_names from '<directory>/mitab_method.txt'
\copy mitab_authors from '<directory>/mitab_authors.txt'
\copy mitab_pubmed from '<directory>/mitab_pmids.txt'
\copy mitab_interaction_type_names from '<directory>/mitab_interactionType.txt'
\copy mitab_sources from '<directory>/mitab_sourcedb.txt'
\copy mitab_interaction_identifiers from '<directory>/mitab_interactionIdentifiers.txt'
-- \copy mitab_confidence from '<directory>/mitab_confidence.txt'

commit;
