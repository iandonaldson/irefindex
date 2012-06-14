-- Import integer identifiers from previous iRefIndex releases.
-- For MySQL-based releases, see:
-- sql/mysql/export_irefindex_integer_rigids.sql
-- sql/mysql/export_irefindex_integer_rogids.sql

-- Copyright (C) 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
-- Original author: Paul Boddie <paul.boddie@biotek.uio.no>
--
-- This program is free software; you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program.  If not, see <http://www.gnu.org/licenses/>.

begin;

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

        -- Newly numbered interactions can be interactions provided by
        -- interaction records...

        select distinct N.rigid
        from irefindex_rigids as N
        left outer join tmp_rig2rigid as O
            on N.rigid = O.rigid
        where O.rigid is null
        union

        -- ...or canonical interactions not directly provided by interaction
        -- records.

        select distinct N.crigid
        from irefindex_rigids_canonical as N
        left outer join tmp_rig2rigid as O
            on N.crigid = O.rigid
        where O.rigid is null

        ) as X;

create index irefindex_rig2rigid_rigid on irefindex_rig2rigid(rigid);
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

        -- Newly numbered interactors can be interactors provided by interaction
        -- records.

        select distinct N.rogid
        from irefindex_rogids as N
        left outer join tmp_rog2rogid as O
            on N.rogid = O.rogid
        where O.rogid is null
        union

        -- ...or canonical interactors not directly provided by interaction
        -- records, but known from sequence database records not employed by
        -- interaction records.

        select distinct N.crogid
        from irefindex_rogids_canonical as N
        left outer join tmp_rog2rogid as O
            on N.crogid = O.rogid
        where O.rogid is null

        ) as X;

create index irefindex_rog2rogid_rogid on irefindex_rog2rogid(rogid);
analyze irefindex_rog2rogid;

commit;
