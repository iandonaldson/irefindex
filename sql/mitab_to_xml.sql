-- Conversion from MITAB to PSI-MI XML-oriented data.
-- NOTE: An entry number is used to support multiple corresponding
-- NOTE: experiment-related values since MPIDB encodes information in this
-- NOTE: optimistic fashion.

begin;

-- A common sequence number for interactors.

create temporary sequence mitab_interactor;

-- A temporary table for interactors.
-- Experiments are defined on a per line basis in the revised MPIDB data files.
-- As a result, the source, filename and line columns act as experiment keys.

create temporary table tmp_mitab_interactors as
    select source, filename, interaction as interactionid, position as participantid,
        nextval('mitab_interactor') as interactorid, dbname, acc, taxid
    from mitab_uid;

-- Entity tables.

insert into xml_interactors
    select source, filename, 0 as entry, interactorid, participantid, interactionid
    from tmp_mitab_interactors;

insert into xml_experiments
    select source, filename, 0 as entry, line as experimentid, interaction as interactionid
    from mitab_interaction_identifiers;

insert into xml_organisms
    select source, filename, 0 as entry, 'interactor' as scope, interactorid as parentid, taxid
    from tmp_mitab_interactors;

-- Cross-references.

insert into xml_xref

    -- Interactor primary references.

    select source, filename, 0 as entry, 'interactor' as scope, interactorid as parentid,
        'interactor' as property, 'primaryRef' as reftype, acc as refvalue, dbname as dblabel
    from tmp_mitab_interactors
    union all

    -- Experiment methods.

    select source, filename, 0 as entry, 'experimentDescription' as scope, line as parentid,
        'interactionDetectionMethod' as property,
        case when 0 = any (array_accum(entry)) then 'primaryRef' else 'secondaryRef' end as reftype,
        code as refvalue,
        'psi-mi' as dblabel, 'MI:0488' as dbcode
    from mitab_method_names
    union all

    -- Experiment document information.

    select source, filename, 0 as entry, 'experimentDescription' as scope, line as parentid,
        'bibref' as property,
        case when 0 = any (array_accum(entry)) then 'primaryRef' else 'secondaryRef' end as reftype,
        pmid as refvalue,
        'pubmed' as dblabel, 'MI:0446' as dbcode
    from mitab_pubmed
    union all

    -- Interaction type names.

    select source, filename, 0 as entry, 'interaction' as scope, interaction as parentid,
        'interactionType' as property, 'primaryRef' as reftype, code as refvalue,
        'psi-mi' as dblabel, 'MI:0488' as dbcode
    from mitab_interaction_type_names
    union all

    -- Interaction primary references.

    select source, filename, 0 as entry, 'interaction' as scope, interaction as parentid,
        'interaction' as property, 'primaryRef' as reftype, "uid" as refvalue
    from mitab_interaction_identifiers;

-- Names, labels, aliases.

insert into xml_names

    -- Interactor aliases.
    -- The first alias is regarded as being equivalent to the PSI MI XML short label.

    select source, filename, 0 as entry, 'interactor' as scope, interactorid as parentid,
        'interactor' as property, case when entry = 1 then 'shortLabel' else 'alias' as nametype,
        alias as name
    from mitab_aliases as A
    inner join tmp_mitab_interactors as I
        on A.source = I.source
        and A.filename = I.filename
        and A.interaction = I.interaction
        and A.position = I.position
    union all

    -- Experiment methods.

    select source, filename, 0 as entry, 'experimentDescription' as scope, line as parentid,
        'interactionDetectionMethod' as property, 'shortLabel' as nametype, name as name
    from mitab_method_names
    union all

    -- Experiments authors.

    select source, filename, 0 as entry, 'experimentDescription' as scope, line as parentid,
        'shortLabel' as nametype, author as name
    from mitab_authors
    union all

    -- Interaction type names.

    select source, filename, 0 as entry, 'interaction' as scope, interaction as parentid,
        'interactionType' as property, 'shortLabel' as nametype,
        case when 0 = any (array_accum(entry)) then 'shortLabel' else 'alias' end as nametype,
        name as name
    from mitab_interaction_type_names;

commit;
