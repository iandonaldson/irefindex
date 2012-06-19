begin;

-- Specific ROG integer identifiers mapped to canonical ROG integer identifiers.

create temporary table tmp_rog2canonicalrog as
    select SI.rog || '|+|' || CI.rog
    from irefindex_rogids_canonical as R
    inner join irefindex_rog2rogid as SI
        on R.rogid = SI.rogid
    inner join irefindex_rog2rogid as CI
        on R.crogid = CI.rogid;

\copy tmp_rog2canonicalrog to '<directory>/ROG2CANONICALROG.irfm'

-- Canonical ROG integer identifiers mapped to specific ROG integer identifiers.

create temporary table tmp_canonicalrog2rogs as
    select CI.rog || '|+|' || array_to_string(array_accum(distinct SI.rog), '|')
    from irefindex_rogids_canonical as R
    inner join irefindex_rog2rogid as SI
        on R.rogid = SI.rogid
    inner join irefindex_rog2rogid as CI
        on R.crogid = CI.rogid
    group by CI.rog;

\copy tmp_canonicalrog2rogs to '<directory>/CANONICALROG2ROG.irfm'

-- Interaction references mapped to RIG identifiers.

create temporary table tmp_interaction2rig as
    select refvalue, rigid
    from xml_xref_interactions as I
    inner join irefindex_rigids as R
        on (I.source, I.filename, I.entry, I.interactionid) = 
           (R.source, R.filename, R.entry, R.interactionid);

\copy tmp_interaction2rig to '<directory>/_EXT__RIG_src_intxn_id.irft'

-- ROG integer identifiers mapped to RIG identifiers and other ROGs in an interaction.

create temporary table tmp_rog2rigid as
    select I.rog || '|+|' || R.rigid || '|+|' || array_to_string(array_accum(distinct I2.rog), '+')
    from irefindex_distinct_interactions as R
    inner join irefindex_distinct_interactions as R2
        on R.rigid = R2.rigid

    -- The principal ROG.

    inner join irefindex_rog2rogid as I
        on R.rogid = I.rogid

    -- Other ROGs.

    inner join irefindex_rog2rogid as I2
        on R2.rogid = I2.rogid
    group by R.rigid, I.rog;

\copy tmp_rog2rigid to '<directory>/rog2rig.irfm'

-- A pairwise mapping of ROG integer identifiers for each interaction.

create temporary table tmp_graph as
    select I.rog as rogA, I2.rog as rogB
    from irefindex_distinct_interactions as R
    inner join irefindex_distinct_interactions as R2
        on R.rigid = R2.rigid

    -- The principal ROG.

    inner join irefindex_rog2rogid as I
        on R.rogid = I.rogid

    -- Other ROGs.

    inner join irefindex_rog2rogid as I2
        on R2.rogid = I2.rogid

    where I.rog < I2.rog
    group by I.rog, I2.rog;

\copy tmp_graph to '<directory>/graph'

rollback;
