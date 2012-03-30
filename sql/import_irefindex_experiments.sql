begin;

-- Get all experiment-related records of interest.

insert into xml_xref_all_experiments
    select source, filename, entry, parentid as experimentid,
        case when property = 'interactionDetection' then 'interactionDetectionMethod'
             else property
        end as property,
        reftype,
        case when dblabel in ('Pub-Med', 'PUBMED', 'Pubmed') then 'pubmed'
             when dblabel in ('MI', 'psimi', 'PSI-MI') then 'psi-mi'
             else dblabel
        end as dblabel,

        -- Fix certain psi-mi references.

        case when dblabel = 'MI' and not refvalue like 'MI:%' then 'MI:' || refvalue
             else refvalue
        end as refvalue

    from xml_xref
    where scope = 'experimentDescription'
        and reftype in ('primaryRef', 'secondaryRef')
        and property in ('bibref', 'interactionDetection', 'interactionDetectionMethod', 'participantIdentificationMethod');

analyze xml_xref_all_experiments;

insert into xml_xref_experiment_organisms
    select distinct source, filename, entry, parentid as experimentid, taxid
    from xml_organisms
    where scope = 'experimentDescription';

analyze xml_xref_experiment_organisms;

insert into xml_xref_experiment_pubmed
    select distinct source, filename, entry, experimentid, refvalue
    from xml_xref_all_experiments
    where property = 'bibref' and dblabel = 'pubmed';

analyze xml_xref_experiment_pubmed;

insert into xml_xref_experiment_methods
    select distinct source, filename, entry, experimentid, property, refvalue
    from xml_xref_all_experiments
    where property in ('interactionDetectionMethod', 'participantIdentificationMethod') and dblabel = 'psi-mi';

analyze xml_xref_experiment_methods;

-- Author information originates in the short labels, but is not consistently recorded.
-- NOTE: A list of usable sources is included here.

insert into xml_names_experiment_authors
    select source, filename, entry, parentid as experimentid, name
    from xml_names
    where scope = 'experimentDescription'
        and property = 'experimentDescription'
        and nametype = 'shortLabel'
        and source in ('BIOGRID', 'INTACT', 'MINT');

analyze xml_names_experiment_authors;

commit;
