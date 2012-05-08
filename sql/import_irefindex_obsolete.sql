begin;

\copy irefindex_obsolete from '<directory>/obsolete'
analyze irefindex_obsolete;

commit;
