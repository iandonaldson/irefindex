-- Show interaction details for each data source.

-- Copyright (C) 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

create temporary table tmp_interactions_available_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactionid]) as total
    from xml_interactors
    group by source
    order by source;

\copy tmp_interactions_available_by_source to '<directory>/interactions_available_by_source'

create temporary table tmp_interactions_having_assignments as
    select I.source, count(*) as total
    from (

        -- Group interactors by interaction and make sure that only interactions
        -- where all interactors provide sequences are considered.

        select I.source, I.filename, I.entry, I.interactionid
        from xml_interactors as I
        left outer join xml_xref_interactor_sequences as S
            on (I.source, I.filename, I.entry, I.interactorid) =
               (S.source, S.filename, S.entry, S.interactorid)
        group by I.source, I.filename, I.entry, I.interactionid
        having count(I.interactorid) = count(S.interactorid)
        ) as I
    group by I.source;

\copy tmp_interactions_having_assignments to '<directory>/interactions_having_assignments_by_source'

create temporary table tmp_interaction_completeness_by_source as
    select source, complete, count(distinct array[filename, cast(entry as varchar), interactionid]) as total
    from irefindex_interactions_complete
    group by source, complete
    order by source, complete;

\copy tmp_interaction_completeness_by_source to '<directory>/interaction_completeness_by_source'

create temporary table tmp_rigids_unique_by_source as
    select source, count(distinct rigid) as total
    from irefindex_rigids
    group by source;

create temporary table tmp_interaction_coverage as
    select available.source,

        -- Available interactions.

        available.total as available_total,

        -- Suitable interactions.

        coalesce(suitable.total, 0) as suitable_total,

        -- Assigned/used RIGIDs for interactions.

        coalesce(used.total, 0) as assigned_total,

        -- Assigned/used RIGIDs as a percentage of suitable interactions.

        case when suitable.total <> 0 then
            round(
                cast(
                    cast(coalesce(used.total, 0) as real) / suitable.total * 100
                    as numeric
                    ), 2
                )
            else null
        end as assigned_coverage,

        -- Unique RIGIDs.

        coalesce(unique_rigids.total, 0) as unique_total,

        -- Unique coverage as a percentage of the number of assigned/used RIGIDs.

        case when used.total <> 0 then
            round(
                cast(
                    cast(coalesce(unique_rigids.total, 0) as real) / used.total * 100
                    as numeric
                    ), 2
                )
            else null
        end as unique_coverage

    from tmp_interactions_available_by_source as available
    left outer join tmp_interactions_having_assignments as suitable
        on available.source = suitable.source
    left outer join tmp_interaction_completeness_by_source as used
        on available.source = used.source
        and used.complete
    left outer join tmp_rigids_unique_by_source as unique_rigids
        on available.source = unique_rigids.source
    group by available.source, available.total, used.total, suitable.total, unique_rigids.total
    order by available.source;

-- Add headers and totals.

--select count(distinct rigid) from irefindex_rigids into distinctRigids;

create temporary table tmp_interaction_coverage_by_source as
    select 'Source' as source, 'Total records' as available_total, 'Protein-related interactions' as suitable_total,
        'PPI assigned to RIGID' as assigned_total, '%' as assigned_coverage,
        'Unique RIGIDs' as unique_total, '%' as unique_coverage
    union all
    select source, cast(available_total as varchar), cast(suitable_total as varchar),
        cast(assigned_total as varchar), cast(assigned_coverage as varchar),
        cast(unique_total as varchar), cast(unique_coverage as varchar)
    from tmp_interaction_coverage
    union all
    select 
       '(All)' as source, 
        cast(sum(available_total) as varchar), 
        cast(sum(suitable_total) as varchar),
        cast(sum(assigned_total) as varchar), 
        cast(round(cast(cast(sum(assigned_total) as real) / sum(suitable_total) * 100 as numeric), 2) as varchar),
        -- the next two values are set in the update step below
        '-',
        '-'
    from tmp_interaction_coverage;

update tmp_interaction_coverage_by_source
    set
    --distinct number of rigids in All 
    unique_total = (select count(distinct rigid) from irefindex_rigids),
    --distinct rigids as a percentage of all records assigned to rigids
    unique_coverage =
      cast(
        round( 
          cast(
            cast((select count(distinct rigid) from irefindex_rigids) as real) / 
            cast((select assigned_total from tmp_interaction_coverage_by_source where source = '(All)') as real) * 100
          as numeric)
        ,2)
       as varchar)
    where source = '(All)';

\copy tmp_interaction_coverage_by_source to '<directory>/interaction_coverage_by_source'

rollback;
