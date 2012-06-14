-- Collect manifest information for the different data sources.

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

create temporary table tmp_manifest (
    name varchar not null,
    field varchar not null,
    value varchar not null,
    primary key(name, field)
);

\copy tmp_manifest from '<directory>/irefindex_manifest'

create temporary table tmp_formats (
    name varchar not null,
    format varchar not null,
    primary key(name)
);

\copy tmp_formats from '<directory>/dateformats.txt'

-- Convert dates according to the expected format for the source.

insert into irefindex_manifest
    select A.name, to_date(D.value, coalesce(F.format, 'YYYY-MM-DD HH24:MI:SS')), V.value
    from (
        select distinct name
        from tmp_manifest
        ) as A
    inner join tmp_manifest as D
        on A.name = D.name
        and D.field = 'DATE'
    left outer join tmp_formats as F
        on D.name = F.name

    -- Version/release information is optional.

    left outer join tmp_manifest as V
        on A.name = V.name
        and V.field = 'VERSION';

commit;
