begin;

create temporary table tmp_gene2related as
    select distinct A.geneid, B.related
    from gene2related as A
    inner join gene2related as B
        on A.related = B.geneid;

alter table tmp_gene2related add primary key(geneid, related);
analyze tmp_gene2related;

create temporary table tmp_updated as
    select count(X.geneid)
    from (
        select geneid, count(related) as n
        from tmp_gene2related
        group by geneid
        ) as X
    left outer join (
        select geneid, count(related) as n
        from gene2related
        group by geneid
        ) as Y
        on X.geneid = Y.geneid
        and X.n = Y.n
    where Y.geneid is null;

\copy tmp_updated to '<directory>/canonical_updates'

truncate table gene2related;
insert into gene2related select * from tmp_gene2related;

commit;
