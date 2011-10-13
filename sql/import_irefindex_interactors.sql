begin;

-- Get interactor cross-references of interest.

create temporary table tmp_xref_interactors as
    select distinct X.source, X.filename, X.entry, X.parentid as interactorid, reftype, dblabel, refvalue, taxid, sequence
    from xml_xref as X
    left outer join xml_organisms as O
        on X.source = O.source
        and X.filename = O.filename
        and X.entry = O.entry
        and X.parentid = O.parentid
        and X.scope = O.scope
    left outer join xml_sequences as S
        on X.source = S.source
        and X.filename = S.filename
        and X.entry = S.entry
        and X.parentid = S.parentid
        and X.scope = S.scope
    where X.scope = 'interactor'
        and property = 'interactor'
        and reftype in ('primaryRef', 'secondaryRef')
        and (dblabel like 'uniprot%'
            or dblabel in ('refseq', 'flybase', 'sgd')
            or dblabel like 'entrezgene%'
            or dblabel like '%pdb'
            );

create index tmp_xref_interactors_refvalue on tmp_xref_interactors (refvalue);

insert into xml_xref_sequences

    -- UniProt accession matches.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate, cast(null as integer) as gi
    from tmp_xref_interactors as X
    inner join uniprot_accessions as A
        on X.dblabel like 'uniprot%'
        and X.refvalue = A.accession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid
    union all

    -- RefSeq accession matches.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate, cast(null as integer) as gi
    from tmp_xref_interactors as X
    inner join refseq_proteins as P
        on X.dblabel = 'refseq'
        and X.refvalue = P.accession
    union all

    -- RefSeq accession matches via Entrez Gene.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate, cast(null as integer) as gi
    from tmp_xref_interactors as X
    inner join gene2refseq as G
        on X.dblabel like 'entrezgene%'
        and cast(X.refvalue as integer) = G.geneid
    inner join refseq_proteins as P
        on G.accession = P.accession
    union all

    -- PDB accession matches via MMDB.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        M.taxid as reftaxid, P.sequence as refsequence, null as refdate, P.gi
    from tmp_xref_interactors as X
    inner join mmdb_pdb_accessions as M
        on X.dblabel like '%pdb'
        and X.refvalue = M.accession
    inner join pdb_proteins as P
        on M.accession = P.accession
        and M.gi = P.gi
    union all

    -- UniProt matches via FlyBase accessions.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate, cast(null as integer) as gi
    from tmp_xref_interactors as X
    inner join fly_accessions as A
        on X.dblabel = 'flybase'
        and X.refvalue = A.flyaccession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid
    union all

    -- UniProt matches via Yeast accessions.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate, cast(null as integer) as gi
    from tmp_xref_interactors as X
    inner join yeast_accessions as A
        on X.dblabel = 'sgd'
        and X.refvalue = A.sgdxref
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid;

commit;
