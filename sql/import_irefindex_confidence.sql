begin;

create temporary table tmp_pubmed_interactions as
    select distinct refvalue as pmid, rigid
    from xml_experiments as E
    inner join xml_xref_experiment_pubmed as P
        on (E.source, E.filename, E.entry, E.experimentid) =
           (P.source, P.filename, P.entry, P.experimentid)
    inner join irefindex_rigids as I
        on (E.source, E.filename, E.entry, E.interactionid) =
           (I.source, I.filename, I.entry, I.interactionid);

create temporary table tmp_pubmed_count as
    select pmid, count(distinct rigid) as interactions
    from tmp_pubmed_interactions
    group by pmid;

analyze tmp_pubmed_interactions;
analyze tmp_pubmed_count;

insert into irefindex_confidence
    select rigid, 'lpr' as scoretype, min(interactions) as score
    from (
        select rigid, interactions
        from tmp_pubmed_interactions as A
        inner join tmp_pubmed_count as B
            on A.pmid = B.pmid
        ) as X
    group by rigid;

insert into irefindex_confidence
    select rigid, 'hpr' as scoretype, max(interactions) as score
    from (
        select rigid, interactions
        from tmp_pubmed_interactions as A
        inner join tmp_pubmed_count as B
            on A.pmid = B.pmid
        ) as X
    group by rigid;

insert into irefindex_confidence
    select rigid, 'np' as scoretype, count(distinct pmid) as score
    from tmp_pubmed_interactions
    group by rigid;

analyze irefindex_confidence;

commit;
