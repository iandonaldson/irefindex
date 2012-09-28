begin;

create temporary table tmp_sources as

    -- PSI-XML sources.

    select distinct source
    from xml_interactors
    union all

    -- MITAB sources.

    select 'MPIDB'
    from mitab_uid
    where source in ('MPI-LIT', 'MPI-IMEX')
    union all
    select 'INNATEDB'
    from mitab_uid
    where source = 'INNATEDB'
    union all

    -- Special sources.

    (select 'BIND' as source
    from bind_interactors
    limit 1)
    union all
    (select 'DIG' as source
    from dig_diseases
    limit 1)
    union all
    (select 'FLY' as source
    from fly_accessions
    limit 1)
    union all
    (select 'GENE' as source
    from gene_info
    limit 1)
    union all
    (select 'GENPEPT' as source
    from genpept_accessions
    limit 1)
    union all
    (select 'IPI' as source
    from ipi_accessions
    limit 1)
    union all
    (select 'MMDB' as source
    from mmdb_pdb_accessions
    limit 1)
    union all
    (select 'PDB' as source
    from pdb_proteins
    limit 1)
    union all
    (select 'PSI_MI' as source
    from psicv_terms
    limit 1)
    union all
    (select 'REFSEQ' as source
    from refseq_identifiers
    limit 1)
    union all
    (select 'TAXONOMY' as source
    from taxonomy_names
    limit 1)
    union all
    (select 'UNIPROT' as source
    from uniprot_accessions
    limit 1)
    union all
    (select 'YEAST' as source
    from yeast_accessions
    limit 1);

\copy tmp_sources to '<directory>/imported_sources'

rollback;
