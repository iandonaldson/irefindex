begin;

-- NOTE: It appears that most databases provide usable primary references for
-- NOTE: all interactions, unlike those provided for their interactors.

-- NOTE: MPPI and OPHID do not provide interaction identifiers. Both sources
-- NOTE: provide data in PSI-MI XML 1.0 format, but do seem to provide
-- NOTE: experiment information that could be usable.

insert into xml_xref_interactions
    select distinct source, filename, entry, parentid as interactionid, reftype,

        -- Normalise database labels.

        case when dblabel like 'uniprot%' or dblabel in ('SP', 'Swiss-Prot', 'TREMBL') then 'uniprotkb'
             when dblabel like 'entrezgene%' or dblabel like 'entrez gene%' then 'entrezgene'
             when dblabel like '%pdb' then 'pdb'
             when dblabel in ('protein genbank identifier', 'genbank indentifier') then 'genbank_protein_gi'
             when dblabel in ('MI', 'psimi') then 'psi-mi'
             else dblabel
        end as dblabel,

        -- Fix certain psi-mi references.

        case when dblabel = 'MI' and not refvalue like 'MI:%' then 'MI:' || refvalue
             else refvalue
        end as refvalue

    from xml_xref

    -- Restrict to interactions and specifically to primary and secondary references.

    where scope = 'interaction'
        and property = 'interaction'
        and reftype = 'primaryRef';

-- Make some reports more efficient to generate.

create index xml_xref_interactions_index on xml_xref_interactions (source);
analyze xml_xref_interactions;

-- Get interaction types.
-- Only the PSI-MI form of interaction types are of interest.

insert into xml_xref_interaction_types

    -- Normalise database labels.

    select distinct source, filename, entry, parentid as interactorid,

        -- Fix certain psi-mi references.

        case when dblabel = 'MI' and not refvalue like 'MI:%' then 'MI:' || refvalue
             else refvalue
        end as refvalue

    from xml_xref

    -- Restrict to interactors and specifically to primary and secondary references.

    where scope = 'interactor'
        and property = 'interactorType'
        and reftype in ('primaryRef', 'secondaryRef')
        and dblabel in ('psi-mi', 'MI', 'psimi');

analyze xml_xref_interaction_types;

commit;
