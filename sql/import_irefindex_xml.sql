begin;

-- NOTE: Tables based on the schema.

create temporary table tmp_experiments (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null, -- integer for PSI MI XML 2.5
    interactionid varchar not null -- integer for PSI MI XML 2.5
);

create temporary table tmp_interactors (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit interactor reference
    participantid varchar not null, -- integer for PSI MI XML 2.5
    interactionid varchar not null -- integer for PSI MI XML 2.5
);

create temporary table tmp_names (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit reference
    property varchar not null,
    nametype varchar not null,
    typelabel varchar,
    typecode varchar,
    name varchar -- some names can actually be unspecified
);

create temporary table tmp_xref (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit reference
    property varchar not null,
    reftype varchar not null,
    refvalue varchar, -- MIPS omits some refvalues
    dblabel varchar,
    dbcode varchar,
    reftypelabel varchar,
    reftypecode varchar
);

create temporary table tmp_organisms (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit reference
    taxid integer not null
);

\copy tmp_experiments from '<directory>/experiment.txt'
\copy tmp_interactors from '<directory>/interactor.txt'
\copy tmp_names from '<directory>/names.txt'
\copy tmp_xref from '<directory>/xref.txt'
\copy tmp_organisms from '<directory>/organisms.txt'

-- De-duplicate experiment identifier usage (seen in OPHID).

insert into xml_experiments
    select distinct source, filename, entry, experimentid, interactionid
    from tmp_experiments;

-- Assume that interactor identifiers will use one refclass scheme or the other,
-- not both at the same time.

insert into xml_interactors
    select source, filename, entry, interactorid, participantid, interactionid
    from tmp_interactors;

-- Select names which use the active refclass scheme for interactors, plus all
-- other name definitions.

delete from tmp_names
where scope = 'interactor'
    and refclass not in (select distinct refclass from tmp_interactors);

insert into xml_names
    select source, filename, entry, scope, parentid, property, nametype, typelabel, typecode, name
    from tmp_names;

-- Select references which use the active refclass scheme for interactors, plus
-- all other name definitions.

delete from tmp_xref
where scope = 'interactor'
    and refclass not in (select distinct refclass from tmp_interactors);

insert into xml_xref
    select source, filename, entry, scope, parentid, property, reftype, refvalue, dblabel, dbcode, reftypelabel, reftypecode
    from tmp_xref;

-- Select organism definitions which use the active refclass scheme for
-- interactors, plus all other name definitions.

delete from tmp_organisms
where scope = 'interactor'
    and refclass not in (select distinct refclass from tmp_interactors);

insert into xml_organisms
    select source, filename, entry, scope, parentid, taxid
    from tmp_organisms;

commit;
