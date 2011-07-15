begin;

-- NOTE: Tables based on the schema.

create temporary table tmp_interactors (
    source varchar not null,
    filename varchar not null,
    interactorid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit interactor reference
    participantid varchar not null, -- integer for PSI MI XML 2.5
    interactionid varchar not null -- integer for PSI MI XML 2.5
);

create temporary table tmp_names (
    source varchar not null,
    filename varchar not null,
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
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit reference
    taxid integer not null
);

\copy xml_experiments from '<directory>/experiment.txt'
\copy tmp_interactors from '<directory>/interactor.txt'
\copy tmp_names from '<directory>/names.txt'
\copy tmp_xref from '<directory>/xref.txt'
\copy tmp_organisms from '<directory>/organisms.txt'

-- Assume that interactor identifiers will use one refclass scheme or the other,
-- not both at the same time.

insert into xml_interactors
    select source, filename, interactorid, participantid, interactionid
    from tmp_interactors;

-- Select names which use the active refclass scheme for interactors, plus all
-- other name definitions.

insert into xml_names
    select distinct N.source, N.filename, N.scope, N.parentid, property, nametype, typelabel, typecode, name
    from tmp_names as N
    inner join tmp_interactors as I
        on N.source = I.source
        and N.filename = I.filename
        and N.parentid = I.interactorid
        and N.refclass = I.refclass
    where N.scope = 'interactor'
    union all
    select N.source, N.filename, N.scope, N.parentid, property, nametype, typelabel, typecode, name
    from tmp_names as N
    where N.scope <> 'interactor';

-- Select references which use the active refclass scheme for interactors, plus
-- all other name definitions.

insert into xml_xref
    select distinct X.source, X.filename, X.scope, X.parentid, property, reftype, refvalue, dblabel, dbcode, reftypelabel, reftypecode
    from tmp_xref as X
    inner join tmp_interactors as I
        on X.source = I.source
        and X.filename = I.filename
        and X.parentid = I.interactorid
        and X.refclass = I.refclass
    where X.scope = 'interactor'
    union all
    select X.source, X.filename, X.scope, X.parentid, property, reftype, refvalue, dblabel, dbcode, reftypelabel, reftypecode
    from tmp_xref as X
    where X.scope <> 'interactor';

-- Select organism definitions which use the active refclass scheme for
-- interactors, plus all other name definitions.

insert into xml_organisms
    select distinct O.source, O.filename, O.scope, O.parentid, taxid
    from tmp_organisms as O
    inner join tmp_interactors as I
        on O.source = I.source
        and O.filename = I.filename
        and O.parentid = I.interactorid
        and O.refclass = I.refclass
    where O.scope = 'interactor'
    union all
    select O.source, O.filename, O.scope, O.parentid, taxid
    from tmp_organisms as O
    where O.scope <> 'interactor';

commit;
