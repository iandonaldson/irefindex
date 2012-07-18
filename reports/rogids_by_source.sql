-- Show ROG identifier (and thus distinct interactor) details for each data
-- source.

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

create temporary table tmp_rogids_by_source as
    select source, count(distinct rogid) as total
    from irefindex_rogids
    group by source order by source;

\copy tmp_rogids_by_source to '<directory>/rogids_by_source'

create temporary table tmp_source_rogids as
    select distinct rogid, source
    from irefindex_rogids;

analyze tmp_source_rogids;

create temporary table tmp_rogids_shared_by_sources as
    select R1.source as source1, R2.source as source2,
        count(distinct R1.rogid) as total
    from tmp_source_rogids as R1
    inner join tmp_source_rogids as R2
        on R1.rogid = R2.rogid
        and R1.source <= R2.source
    group by R1.source, R2.source
    order by R1.source, R2.source;

\copy tmp_rogids_shared_by_sources to '<directory>/rogids_shared_by_sources'

create temporary table tmp_rogids_unique_to_sources as
    select R1.source, count(distinct R1.rogid) as total
    from tmp_source_rogids as R1
    left outer join tmp_source_rogids as R2
        on R1.rogid = R2.rogid
        and R1.source <> R2.source
    where R2.rogid is null
    group by R1.source
    order by R1.source;

\copy tmp_rogids_unique_to_sources to '<directory>/rogids_unique_to_sources'

-- Make a grid that can be displayed using...
-- column -s ',' -t rogids_shared_as_grid

create temporary table tmp_rogids_shared_as_grid as

    -- Make a header containing a blank entry (encoded with '-') and source names.

    select array_to_string(array_cat(array[cast('-' as varchar)], array_accum(source)), ',')
    from tmp_rogids_by_source
    union all (

        -- Make each row with the source in the first column.

        select array_to_string(array_cat(array[source1], array_accum(coalesce(cast(total as varchar), '-'))), ',')
        from (
            select S.source1, S.source2, R.total
            from tmp_rogids_shared_by_sources as R
            right outer join (
                select S1.source as source1, S2.source as source2
                from tmp_rogids_by_source as S1
                cross join tmp_rogids_by_source as S2
                ) as S
                on R.source1 = S.source1
                and R.source2 = S.source2
            order by S.source1, S.source2
            ) as X
        group by source1
        order by source1
        )
    union all

    -- Make a row with unique identifier totals.

    select array_to_string(array_cat(array[cast('(Exclusive to source)' as varchar)], array_accum(coalesce(cast(total as varchar), '-'))), ',')
    from tmp_rogids_unique_to_sources;

\copy tmp_rogids_shared_as_grid to '<directory>/rogids_shared_as_grid'

rollback;
