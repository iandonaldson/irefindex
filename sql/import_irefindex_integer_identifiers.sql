begin;

-- Import integer identifiers from previous iRefIndex releases.
-- For MySQL-based releases, see:
-- sql/mysql/export_irefindex_integer_rigids.sql
-- sql/mysql/export_irefindex_integer_rogids.sql

\copy irefindex_rig2rigid from '<directory>/rig2rigid'
\copy irefindex_rog2rogid from '<directory>/rog2rogid'

analyze irefindex_rig2rigid;
analyze irefindex_rog2rogid;

commit;
