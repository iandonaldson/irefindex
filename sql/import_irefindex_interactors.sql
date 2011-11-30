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
            or dblabel in ('SP', 'refseq', 'flybase', 'sgd', 'protein genbank identifier')
            or dblabel like 'entrezgene%'
            or dblabel like '%pdb'
            );

create index tmp_xref_interactors_refvalue on tmp_xref_interactors (refvalue);

insert into xml_xref_sequences

    -- UniProt accession matches.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'uniprotkb' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from tmp_xref_interactors as X
    inner join uniprot_accessions as A
        on (X.dblabel like 'uniprot%' or X.dblabel = 'SP')
        and X.refvalue = A.accession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid
    union all

    -- UniProt isoform matches.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'uniprotkb/isoform' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from tmp_xref_interactors as X
    inner join uniprot_isoforms as I
        on (X.dblabel like 'uniprot%' or X.dblabel = 'SP')
        and X.refvalue = I.accession
    inner join uniprot_proteins as P
        on I.uniprotid = P.uniprotid
    union all

    -- UniProt accession matches for unexpected isoforms.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'uniprotkb' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from tmp_xref_interactors as X
    inner join uniprot_accessions as A
        on (X.dblabel like 'uniprot%' or X.dblabel = 'SP')
        and position('-' in X.refvalue) <> 0
        and substring(X.refvalue from 1 for position('-' in X.refvalue) - 1) = A.accession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid
    left outer join uniprot_isoforms as I
        on (X.dblabel like 'uniprot%' or X.dblabel = 'SP')
        and X.refvalue = I.accession
    where I.uniprotid is null
    union all

    -- RefSeq accession matches.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'refseq' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from tmp_xref_interactors as X
    inner join refseq_proteins as P
        on X.dblabel = 'refseq'
        and X.refvalue = P.accession
    union all

    -- RefSeq accession matches using versioning.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'refseq' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from tmp_xref_interactors as X
    inner join refseq_proteins as P
        on X.dblabel = 'refseq'
        and X.refvalue = P.version
    union all

    -- GenBank protein identifier matches.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'refseq/genbank' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from tmp_xref_interactors as X
    inner join refseq_proteins as P
        on X.dblabel = 'protein genbank identifier'
        and X.refvalue = cast(P.gi as varchar)
    union all

    -- RefSeq accession matches via Entrez Gene.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'refseq/entrezgene' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from tmp_xref_interactors as X
    inner join gene2refseq as G
        on X.dblabel like 'entrezgene%'
        and cast(X.refvalue as integer) = G.geneid
    inner join refseq_proteins as P
        on G.accession = P.accession
    union all

    -- PDB accession matches via MMDB.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'pdb/mmdb' as sequencelink,
        M.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from tmp_xref_interactors as X
    inner join mmdb_pdb_accessions as M
        on X.dblabel like '%pdb'
        and X.refvalue = M.accession
    inner join pdb_proteins as P
        on M.accession = P.accession
        and M.chain = P.chain
    union all

    -- UniProt matches via FlyBase accessions.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'uniprotkb/flybase' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from tmp_xref_interactors as X
    inner join fly_accessions as A
        on X.dblabel = 'flybase'
        and X.refvalue = A.flyaccession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid
    union all

    -- UniProt matches via Yeast accessions.

    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, X.refvalue, X.taxid, X.sequence,
        'uniprotkb/sgd' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from tmp_xref_interactors as X
    inner join yeast_accessions as A
        on X.dblabel = 'sgd'
        and X.refvalue = A.sgdxref
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid;

create index xml_xref_sequences_index on xml_xref_sequences(source, filename, entry, interactorid);
analyze xml_xref_sequences;

insert into xml_xref_sequences
    select I.source, I.filename, I.entry, I.interactorid, I.reftype, I.dblabel, I.refvalue, I.taxid, I.sequence,
        null as sequencelink,
        null as reftaxid, null as refsequence, null as refdate
    from tmp_xref_interactors as I
    left outer join xml_xref_sequences as X
        on (I.source, I.filename, I.entry, I.interactorid) = (X.source, X.filename, X.entry, X.interactorid)
    where X.source is null;

commit;
