begin;

-- Connect the active genes to related genes via the full mapping.

create temporary table tmp_gene2related as
    select distinct A.geneid, B.related
    from irefindex_gene2related_active as A
    inner join irefindex_gene2related as B
        on A.related = B.geneid;

alter table tmp_gene2related add primary key(geneid, related);
analyze tmp_gene2related;

-- Check the distribution of groups and write out how many genes have been
-- moved to larger groups.

create temporary table tmp_updated as
    select count(X.geneid)
    from (
        select geneid, count(related) as n
        from tmp_gene2related
        group by geneid
        ) as X
    left outer join (
        select geneid, count(related) as n
        from irefindex_gene2related_active
        group by geneid
        ) as Y
        on X.geneid = Y.geneid
        and X.n = Y.n
    where Y.geneid is null;

\copy tmp_updated to '<directory>/canonical_updates'

-- Update the active genes mapping.

truncate table irefindex_gene2related_active;
insert into irefindex_gene2related_active select * from tmp_gene2related;

commit;
