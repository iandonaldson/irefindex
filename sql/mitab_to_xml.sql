-- Conversion from MITAB to PSI-MI XML-oriented data.

-- Since MPIDB encodes experiment information so that many experiments are
-- described on the same line, an entry number is used to indicate which
-- experiment was described first. A single interaction may therefore be
-- associated with a number of experiments.

-- Experiments are defined on a per line basis in the MPIDB import data files.
-- As a result, the source, filename and line columns act as experiment keys.

begin;

-- Remove any existing MITAB data from the XML tables.

create temporary table tmp_mitab_sources as
    select distinct source
    from mitab_uid;

delete from xml_interactors where source in (select source from tmp_mitab_sources);
delete from xml_experiments where source in (select source from tmp_mitab_sources);
delete from xml_organisms where source in (select source from tmp_mitab_sources);
delete from xml_xref where source in (select source from tmp_mitab_sources);
delete from xml_names where source in (select source from tmp_mitab_sources);

-- Common sequence numbers for interactors and participants.

create temporary sequence mitab_interactor;
create temporary sequence mitab_participant;

-- A temporary table for interactors.

create temporary table tmp_mitab_interactors as
    select source, filename, interaction, position,
        nextval('mitab_interactor') as interactorid, dbname, acc, taxid
    from mitab_uid;

-- Entity tables.

insert into xml_interactors
    select source, filename, 0 as entry, interactorid,
        nextval('mitab_participant') as participantid, interaction as interactionid
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
    -- NOTE: This relegates the uid identifier for InnateDB records to a
    -- NOTE: secondary reference.

    select source, filename, 0 as entry, 'interactor' as scope, cast(interactorid as varchar) as parentid,
        'interactor' as property,
        case when source <> 'INNATEDB' then 'primaryRef' else 'secondaryRef' end as reftype,
        acc as refvalue,
        dbname as dblabel, null as dbcode
    from tmp_mitab_interactors
    where source <> 'INNATEDB'
    union all

    -- InnateDB puts UniProt accessions in the aliases list.
    -- NOTE: This promotes the first alias for InnateDB records to a primary
    -- NOTE: reference.

    select I.source, I.filename, 0 as entry, 'interactor' as scope, cast(interactorid as varchar) as parentid,
        'interactor' as property,
        'primaryRef' as reftype,
        A.alias as refvalue,
        'uniprotkb' as dblabel, null as dbcode
    from tmp_mitab_interactors as I
    inner join mitab_uid as U
        on (I.source, I.filename, I.interaction, I.position) =
           (U.source, U.filename, U.interaction, U.position)
    inner join mitab_aliases as A
        on (U.source, U.filename, U.interaction, U.position) =
           (A.source, A.filename, A.interaction, A.position)
        and A.entry = 0
    where I.source = 'INNATEDB'
    union all

    -- Experiment methods.

    select source, filename, 0 as entry, 'experimentDescription' as scope, cast(line as varchar) as parentid,
        'interactionDetectionMethod' as property,
        'primaryRef' as reftype,
        code as refvalue,
        'psi-mi' as dblabel, 'MI:0488' as dbcode
    from mitab_method_names
    union all

    -- Experiment document information.

    select source, filename, 0 as entry, 'experimentDescription' as scope, cast(line as varchar) as parentid,
        'bibref' as property,
        'primaryRef' as reftype,
        cast(pmid as varchar) as refvalue,
        'pubmed' as dblabel, 'MI:0446' as dbcode
    from mitab_pubmed
    union all

    -- Interaction type names.

    select source, filename, 0 as entry, 'interaction' as scope, interaction as parentid,
        'interactionType' as property,
        'primaryRef' as reftype,
        code as refvalue,
        'psi-mi' as dblabel, 'MI:0488' as dbcode
    from mitab_interaction_type_names
    group by source, filename, interaction, code
    union all

    -- Interaction primary references.

    select source, filename, 0 as entry, 'interaction' as scope, interaction as parentid,
        'interaction' as property,
        'primaryRef' as reftype,
        "uid" as refvalue,
        dbname as dblabel, null as dbcode
    from mitab_interaction_identifiers
    group by source, filename, interaction, "uid", dbname;

-- Names, labels, aliases.

insert into xml_names

    -- Interactor aliases.
    -- The first alias is regarded as being equivalent to the PSI MI XML short label.

    select A.source, A.filename, 0 as entry, 'interactor' as scope, cast(interactorid as varchar) as parentid,
        'interactor' as property,
        case when entry = 0 then 'shortLabel' else 'alias' end as nametype,
        null as typelabel, null as typecode,
        alias as name
    from mitab_aliases as A
    inner join tmp_mitab_interactors as I
        on A.source = I.source
        and A.filename = I.filename
        and A.interaction = I.interaction
        and A.position = I.position
    union all

    -- Experiment methods.

    select source, filename, 0 as entry, 'experimentDescription' as scope, cast(line as varchar) as parentid,
        'interactionDetectionMethod' as property,
        'shortLabel' as nametype,
        null as typelabel, null as typecode,
        name as name
    from mitab_method_names
    union all

    -- Interaction type names.

    select source, filename, 0 as entry, 'interaction' as scope, interaction as parentid,
        'interactionType' as property,
        'shortLabel' as nametype,
        null as typelabel, null as typecode,
        name as name
    from mitab_interaction_type_names
    group by source, filename, interaction, name;

commit;
