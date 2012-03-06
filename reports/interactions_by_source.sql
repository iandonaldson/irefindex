begin;

create temporary table tmp_interactions_available_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactionid]) as total
    from xml_interactors
    group by source
    order by source;

\copy tmp_interactions_available_by_source to '<directory>/interactions_available_by_source'

create temporary table tmp_interactions_having_assignments as
    select I.source, count(distinct array[I.source, I.filename, cast(I.entry as varchar), interactionid]) as total
    from xml_interactors as I
    inner join xml_xref_interactor_sequences as S
        on (I.source, I.filename, I.entry, I.interactorid) =
           (S.source, S.filename, S.entry, S.interactorid)
    group by I.source;

\copy tmp_interactions_available_by_source to '<directory>/interactions_having_assignments_by_source'

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
    select available.source, available.total as available_total,
        coalesce(suitable.total, 0) as suitable_total,
        coalesce(used.total, 0) as assigned_total,
        case when suitable.total <> 0 then
            round(
                cast(
                    cast(coalesce(used.total, 0) as real) / suitable.total * 100
                    as numeric
                    ), 2
                )
            else null
        end as assigned_coverage,
        coalesce(unique_rigids.total, 0) as unique_total,
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

-- Add headers.

create temporary table tmp_interaction_coverage_by_source as
    select 'Source' as source, 'Total records' as available_total, 'Protein-related interactions' as suitable_total,
        'PPI assigned to RIGID' as assigned_total, '%' as assigned_coverage,
        'Unique RIGIDs' as unique_total, '%' as unique_coverage
    union all
    select source, cast(available_total as varchar), cast(suitable_total as varchar),
        cast(assigned_total as varchar), cast(assigned_coverage as varchar),
        cast(unique_total as varchar), cast(unique_coverage as varchar)
    from tmp_interaction_coverage;

\copy tmp_interaction_coverage_by_source to '<directory>/interaction_coverage_by_source'

rollback;
