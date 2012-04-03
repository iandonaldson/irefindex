begin;

-- Import integer identifiers from previous iRefIndex releases.
-- For MySQL-based releases, see:
-- sql/mysql/export_irefindex_integer_rigids.sql
-- sql/mysql/export_irefindex_integer_rogids.sql

create temporary table tmp_rig2rigid (
    rig integer not null,
    rigid varchar not null,
    primary key(rig)
);

create temporary table tmp_rog2rogid (
    rog integer not null,
    rogid varchar not null,
    primary key(rog)
);

\copy tmp_rig2rigid from '<directory>/rig2rigid'
\copy tmp_rog2rogid from '<directory>/rog2rogid'

analyze tmp_rig2rigid;
analyze tmp_rog2rogid;

-- Combine the previous release's RIG identifiers with this release's new
-- identifiers, numbering the new ones from the point at which the old ones
-- finished.

create temporary sequence tmp_rig;

select setval('tmp_rig', max(rig))
from tmp_rig2rigid;

insert into irefindex_rig2rigid
    select rig, rigid, true
    from tmp_rig2rigid
    union all
    select nextval('tmp_rig'), rigid, false
    from (
        select distinct N.rigid
        from irefindex_rigids as N
        left outer join tmp_rig2rigid as O
            on N.rigid = O.rigid
        ) as X;

analyze irefindex_rig2rigid;

-- Combine the previous release's ROG identifiers with this release's new
-- identifiers, numbering the new ones from the point at which the old ones
-- finished.

create temporary sequence tmp_rog;

select setval('tmp_rog', max(rog))
from tmp_rog2rogid;

insert into irefindex_rog2rogid
    select rog, rogid, true
    from tmp_rog2rogid
    union all
    select nextval('tmp_rog'), rogid, false
    from (
        select distinct N.rogid
        from irefindex_rogids as N
        left outer join tmp_rog2rogid as O
            on N.rogid = O.rogid
        ) as X;

analyze irefindex_rog2rogid;

commit;
