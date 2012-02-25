begin;

create temporary table tmp_rogids_by_score as
    select source, filename, entry, interactorid,
        array_to_string(array[
            case when reftype = 'primaryRef' then 'P' else '' end,
            case when reftype = 'secondaryRef' then 'S' else '' end,
            case when sequencelink in ('uniprotkb/non-primary', 'uniprotkb/isoform-non-primary-unexpected') then 'U' else '' end,
            case when sequencelink = 'refseq/version-discarded' then 'V' else '' end,
            case when originaltaxid <> taxid then 'T' else '' end,
            case when sequencelink like 'entrezgene%' then 'G' else '' end,
            '', -- D score seems superfluous (adjustment to database name)
            '', -- M currently not tracked or generally implemented (typographical modification)
            case when method <> 'unambiguous' then '+' else '' end,
            case when method = 'matching sequence' then 'O' else '' end,
            case when method = 'matching taxonomy' then 'X' else '' end,
            '', -- ?
            case when method = 'arbitrary' then 'L' else '' end,
            '', -- E currently not tracked (missing interactor retrieved from eUtils)
            '', -- Y score not yet supported (refers to obsolete assignment)
            '', -- N score not yet supported (refers to new assignment)
            ''  -- Q currently not tracked ("see-also" reference type used)
            ], '') as score
    from irefindex_assignments as A;

create temporary table tmp_rogids_by_score_and_source as
    select score, source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total
    from tmp_rogids_by_score
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
