begin;

create temporary table tmp_xref_interactors as
    select distinct source, filename, entry, parentid, reftype, dblabel, refvalue
    from xml_xref as X
    where scope = 'interactor'
        and property = 'interactor'
        and reftype in ('primaryRef', 'secondaryRef');

create table xml_xref_interactors as
    select I.source, I.filename, I.entry, I.interactorid, X.reftype, X.dblabel, X.refvalue
    from xml_interactors as I
    left outer join tmp_xref_interactors as X
        on I.source = X.source
        and I.filename = X.filename
        and I.entry = X.entry
        and I.interactorid = X.parentid
        and X.reftype in ('primaryRef', 'secondaryRef')
        and (X.dblabel like 'uniprot%' or X.dblabel = 'refseq' or X.dblabel like 'entrezgene%');

create table xml_xref_rogids as
    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, P.sequence
    from xml_xref_interactors as X
    inner join uniprot_accessions as A
        on X.dblabel like 'uniprot%'
        and X.refvalue = A.accession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid
    union
    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, P.sequence
    from xml_xref_interactors as X
    inner join refseq_proteins as P
        on X.dblabel = 'refseq'
        and X.refvalue = P.accession
    union
    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.dblabel, P.sequence
    from xml_xref_interactors as X
    inner join gene2refseq as G
        on X.dblabel like 'entrezgene%'
        and cast(X.refvalue as integer) = G.geneid
    inner join refseq_proteins as P
        on G.accession = P.accession;

-- NOTE: Need also entrezgene joins.

commit;
