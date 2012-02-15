-- Import data into the schema.

begin;

create temporary table tmp_genpept_proteins (
    accession varchar not null,
    db varchar not null,
    gi integer not null,
    organism varchar not null,
    "sequence" varchar not null
);

\copy tmp_genpept_proteins from '<directory>/genpept_proteins.txt.seq'
analyze tmp_genpept_proteins;

insert into genpept_proteins
    select accession, db, gi, case when taxids = 1 then taxid else null end, "sequence"
    from (
        select accession, db, gi, "sequence", count(distinct taxid) as taxids, min(taxid) as taxid
        from tmp_genpept_proteins
        left outer join taxonomy_names
            on organism = name
        group by accession, db, gi, "sequence"
        ) as X;

create index genpept_proteins_sequence on genpept_proteins(sequence);
create index genpept_proteins_gi on genpept_proteins(gi);
analyze genpept_proteins;

insert into genpept_accessions
    select accession, substring(accession from 1 for position('.' in accession) - 1)
    from genpept_proteins
    group by accession;

create index genpept_accessions_shortform on genpept_accessions(shortform);
analyze genpept_accessions;

commit;
