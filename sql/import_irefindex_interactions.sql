begin;

insert into xml_xref_all_interactions

    -- Normalise database labels.

    select distinct source, filename, entry, parentid as interactionid, reftype, reftypelabel,
        case when dblabel like 'uniprot%' or dblabel in ('SP', 'Swiss-Prot', 'TREMBL') then 'uniprotkb'
             when dblabel like 'entrezgene%' or dblabel like 'entrez gene%' then 'entrezgene'
             when dblabel like '%pdb' then 'pdb'
             when dblabel in ('protein genbank identifier', 'genbank indentifier') then 'genbank_protein_gi'
             else dblabel
        end as dblabel,
        refvalue
    from xml_xref

    -- Restrict to interactions and specifically to primary and secondary references.

    where scope = 'interaction'
        and reftype in ('primaryRef', 'secondaryRef');

-- Make some reports more efficient to generate.

create index xml_xref_all_interactions_index on xml_xref_all_interactions (source);
analyze xml_xref_all_interactions;

commit;
