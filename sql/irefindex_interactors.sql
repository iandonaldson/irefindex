begin;

-- Get interactor cross-references of interest.

create temporary table tmp_xref_interactors as
    select distinct X.source, X.filename, X.entry, X.parentid as interactorid, reftype, dblabel, refvalue, taxid
    from xml_xref as X
    left outer join xml_organisms as O
        on X.source = O.source
        and X.filename = O.filename
        and X.entry = O.entry
        and X.parentid = O.parentid
        and X.scope = O.scope
    where X.scope = 'interactor'
        and property = 'interactor'
        and reftype in ('primaryRef', 'secondaryRef')
        and (dblabel like 'uniprot%'
            or dblabel = 'refseq'
            or dblabel like 'entrezgene%'
            or dblabel like '%pdb'
            );

create index tmp_xref_interactors_refvalue on tmp_xref_interactors (refvalue);

create table xml_xref_sequences as

    -- UniProt accession matches.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.taxid, P.sequence
    from tmp_xref_interactors as X
    inner join uniprot_accessions as A
        on X.dblabel like 'uniprot%'
        and X.refvalue = A.accession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid
        and X.taxid = P.taxid
    union all

    -- RefSeq accession matches.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.taxid, P.sequence
    from tmp_xref_interactors as X
    inner join refseq_proteins as P
        on X.dblabel = 'refseq'
        and X.refvalue = P.accession
        and X.taxid = P.taxid
    union all

    -- RefSeq accession matches via Entrez Gene.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.taxid, P.sequence
    from tmp_xref_interactors as X
    inner join gene2refseq as G
        on X.dblabel like 'entrezgene%'
        and cast(X.refvalue as integer) = G.geneid
    inner join refseq_proteins as P
        on G.accession = P.accession
        and X.taxid = P.taxid
    union all

    -- PDB accession matches via MMDB.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.taxid, P.sequence
    from tmp_xref_interactors as X
    inner join mmdb_pdb_accessions as M
        on X.dblabel like '%pdb'
        and X.refvalue = M.accession
        and X.taxid = M.taxid
    inner join pdb_proteins as P
        on M.accession = P.accession
        and M.gi = P.gi;

commit;
