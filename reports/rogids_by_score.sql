-- Show ROG identifier (and thus distinct interactor) scoring details for each
-- data source.

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

create temporary table tmp_rogids_by_score_and_source as
    select score, source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total
    from irefindex_assignment_scores
    group by score, source
    order by score, source;

\copy tmp_rogids_by_score_and_source to '<directory>/rogids_by_score_and_source'

-- Make a grid that can be displayed using...
-- column -s ',' -t rogids_by_score_and_source_as_grid

create temporary table tmp_rogids_by_score_and_source_as_grid as
    select array_to_string(array_cat(array[cast('-' as varchar)], array_accum(source)), ',')
    from (
        select distinct source
        from tmp_rogids_by_score_and_source
        order by source
        ) as X
    union all (
        select array_to_string(array_cat(array[cast(score as varchar)], array_accum(coalesce(cast(total as varchar), '-'))), ',')
        from (

            -- Select the totals for all possible combination.

            select S2.source, S2.score, total
            from tmp_rogids_by_score_and_source as S1
            right outer join (

                -- Get all possible source, score combinations.

                select distinct S1.source, S2.score
                from tmp_rogids_by_score_and_source as S1
                cross join tmp_rogids_by_score_and_source as S2

                ) as S2
                on S1.source = S2.source
                and S1.score = S2.score

            order by S2.source

            ) as X
        group by score
        order by score
        );

\copy tmp_rogids_by_score_and_source_as_grid to '<directory>/rogids_by_score_and_source_as_grid'

rollback;
