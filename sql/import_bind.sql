begin;

\copy bind_interactors from '<directory>/interactors.txt'
\copy bind_complexes from '<directory>/complexes.txt'
\copy bind_complex_references from '<directory>/complex_references.txt'
\copy bind_references from '<directory>/references.txt'
\copy bind_labels from '<directory>/labels.txt'

-- Remove non-protein interaction details.
-- NOTE: There are some records in BIND that have ill-formed formatting.
-- NOTE: For example, complex #257564.
-- NOTE: Such records are discarded here.

delete from bind_interactors where participantType not in ('gene', 'protein', 'DNA', 'RNA', 'complex');
delete from bind_complexes where participantType not in ('gene', 'protein', 'DNA', 'RNA', 'complex');

-- Fix database labels.

update bind_interactors set database = 'refseq'
    where database = 'GenBank'
        and accession ~ '^[A-Z]P_[0-9]*([.][0-9]*)?$';

update bind_complexes set database = 'refseq'
    where database = 'GenBank'
        and accession ~ '^[A-Z]P_[0-9]*([.][0-9]*)?$';

update bind_interactors set database = 'pdb'
    where database = 'GenBank'
        and accession ~ E'^[A-Z0-9]{4}\\|[A-Z0-9]$';

update bind_complexes set database = 'pdb'
    where database = 'GenBank'
        and accession ~ E'^[A-Z0-9]{4}\\|[A-Z0-9]$';

update bind_interactors set database = 'uniprotkb'
    where database = 'GenBank'
        and accession ~ '^[A-NR-Z][0-9][A-Z][A-Z0-9]{2}[0-9]$|^[OPQ][0-9][A-Z0-9]{3}[0-9]$';

update bind_complexes set database = 'uniprotkb'
    where database = 'GenBank'
        and accession ~ '^[A-NR-Z][0-9][A-Z][A-Z0-9]{2}[0-9]$|^[OPQ][0-9][A-Z0-9]{3}[0-9]$';

-- Add an implicit interactor identifier.

create temporary sequence bind_interactors_interactorid;

alter table bind_interactors add column interactorid integer;
alter table bind_complexes add column interactorid integer;

update bind_interactors set interactorid = nextval('bind_interactors_interactorid');
update bind_complexes set interactorid = nextval('bind_interactors_interactorid');

alter table bind_interactors alter column interactorid set not null;
alter table bind_complexes alter column interactorid set not null;

-- Add indexes.

create index bind_interactors_index on bind_interactors(bindid);
create index bind_complexes_index on bind_complexes(bindid);

analyze bind_interactors;
analyze bind_complexes;
analyze bind_complex_references;
analyze bind_references;
analyze bind_labels;

insert into xml_interactors

    -- Get the identifiers from each interactor.

    select 'BIND' as source, filename, 0 as entry, cast(interactorid as varchar) as interactorid,
        cast(participantid as varchar) as participantid, cast(bindid as varchar) as interactionid
    from bind_interactors
    union all

    -- Get the identifiers from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, cast(interactorid as varchar) as interactorid,
        cast(interactorid as varchar) as participantid, cast(bindid as varchar) as interactionid
    from bind_complexes;

insert into xml_xref

    -- Get the accession.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'primaryRef' as reftype, accession as refvalue, database as dblabel,
        null as dbcode, null as reftypelabel, null as reftypecode
    from bind_interactors
    where database <> 'BIND'
        and accession not in ('-', '', 'NA')
    union all

    -- Get the gi.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'secondaryRef' as reftype, cast(gi as varchar) as refvalue, 'genbank_protein_gi' as dblabel,
        null as dbcode, null as reftypelabel, null as reftypecode
    from bind_interactors
    union all

    -- Get the accession from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'primaryRef' as reftype, accession as refvalue, database as dblabel,
        null as dbcode, null as reftypelabel, null as reftypecode
    from bind_complexes
    where database <> 'BIND'
        and accession not in ('-', '', 'NA')
    union all

    -- Get the gi from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'secondaryRef' as reftype, cast(gi as varchar) as refvalue, 'genbank_protein_gi' as dblabel,
        null as dbcode, null as reftypelabel, null as reftypecode
    from bind_complexes
    union all

    -- Get the interaction identifier from the group of records representing an interaction.

    select distinct 'BIND' as source, filename, 0 as entry, 'interaction' as scope,
        cast(bindid as varchar) as parentid, 'interaction' as property,
        'primaryRef' as reftype, cast(bindid as varchar) as refvalue, 'bind' as dblabel,
        null as dbcode, null as reftypelabel, null as reftypecode
    from bind_interactors
    union all

    -- Get the interaction identifier from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interaction' as scope,
        cast(bindid as varchar) as parentid, 'interaction' as property,
        'primaryRef' as reftype, cast(bindid as varchar) as refvalue, 'bind' as dblabel,
        null as dbcode, null as reftypelabel, null as reftypecode
    from bind_complexes;

    -- NOTE: Also need PubMed, method, interaction type information.

insert into xml_names

    -- Get the short label from each interactor's group of labels.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'shortLabel' as nametype, null as typelabel, null as typecode, shortLabel as name
    from bind_interactors as I
    inner join bind_labels as L
        on I.bindid = L.bindid
        and I.participantid = L.participantid
    union all

    -- Get the aliases.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'alias' as nametype, null as typelabel, null as typecode, alias as name
    from bind_interactors as I
    inner join bind_labels as L
        on I.bindid = L.bindid
        and I.participantid = L.participantid
    union all

    -- Get the short label from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'shortLabel' as nametype, null as typelabel, null as typecode, shortLabel as name
    from bind_complexes
    union all

    -- Get the alias from each record representing a complex.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'alias' as nametype, null as typelabel, null as typecode, alias as name
    from bind_complexes;

    -- NOTE: Also need method, interaction type information.

insert into xml_organisms

    -- Get the taxid from each interactor.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, taxid
    from bind_interactors
    union all

    -- Get the taxid from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, taxid
    from bind_complexes;

-- insert into xml_experiments
--     select distinct source, filename, entry, experimentid, interactionid

commit;