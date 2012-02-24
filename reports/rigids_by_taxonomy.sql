begin;

-- Show rigids grouped by the original taxonomy identifier.

create temporary table tmp_rigids_by_originaltaxid as
    select A.originaltaxid, name, count(distinct rigid) as rigids
    from irefindex_rigids as R1
    inner join xml_interactors as I
        on (R1.source, R1.filename, R1.entry, R1.interactionid) =
            (I.source, I.filename, I.entry, I.interactionid)
    inner join irefindex_rogids as R2
        on (I.source, I.filename, I.entry, I.interactorid) =
            (R2.source, R2.filename, R2.entry, R2.interactorid)
    inner join irefindex_assignments as A
        on (R2.source, R2.filename, R2.entry, R2.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    inner join taxonomy_names as N
        on A.originaltaxid = N.taxid
        and nameclass = 'scientific name'
    group by A.originaltaxid, name
    order by count(distinct rigid) desc;

\copy tmp_rogids_by_originaltaxid to '<directory>/rigids_by_originaltaxid'

-- Show the top 15 organisms in a form viewable using...
--
-- column -t -s $'\t' rigids_by_originaltaxid_top

create temporary table tmp_rigids_by_originaltaxid_top as
    select 'NCBI taxonomy identifier' as organism, 'Scientific name' as name, 'Number of interactions' as interactions
    union all
    select cast(originaltaxid as varchar), name, cast(rigids as varchar)
    from tmp_rigids_by_originaltaxid
    limit 15;

\copy tmp_rogids_by_originaltaxid_top to '<directory>/rigids_by_originaltaxid_top'

-- Show rigids grouped by the selected taxonomy identifier.

create temporary table tmp_rigids_by_taxid as
    select A.taxid, name, count(distinct rigid) as rigids
    from irefindex_rigids as R1
    inner join xml_interactors as I
        on (R1.source, R1.filename, R1.entry, R1.interactionid) =
            (I.source, I.filename, I.entry, I.interactionid)
    inner join irefindex_rogids as R2
        on (I.source, I.filename, I.entry, I.interactorid) =
            (R2.source, R2.filename, R2.entry, R2.interactorid)
    inner join irefindex_assignments as A
        on (R2.source, R2.filename, R2.entry, R2.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    inner join taxonomy_names as N
        on A.taxid = N.taxid
        and nameclass = 'scientific name'
    group by A.taxid, name
    order by count(distinct rigid) desc;

\copy tmp_rogids_by_taxid to '<directory>/rigids_by_taxid'

-- Show the top 15 organisms in a form viewable using...
--
-- column -t -s $'\t' rigids_by_taxid_top

create temporary table tmp_rigids_by_taxid_top as
    select 'NCBI taxonomy identifier' as organism, 'Scientific name' as name, 'Number of interactions' as interactions
    union all
    select cast(taxid as varchar), name, cast(rigids as varchar)
    from tmp_rigids_by_taxid
    limit 15;

\copy tmp_rogids_by_taxid_top to '<directory>/rigids_by_taxid_top'

rollback;
