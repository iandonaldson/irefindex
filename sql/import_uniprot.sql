-- Import data into the schema.

-- Copyright (C) 2011, 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
-- Copyright (C) 2013 Paul Boddie <paul@boddie.org.uk>
-- Original author: Paul Boddie <paul.boddie@biotek.uio.no>
--
-- This program is free software; you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program.  If not, see <http://www.gnu.org/licenses/>.

begin;

-- Import the proteins, separating the original sequences into a separate
-- mapping table.

create temporary table tmp_uniprot_proteins (
    uniprotid varchar not null,
    accession varchar not null,
    sequencedate varchar,
    taxid integer,
    mw integer,
    actualsequence varchar not null, -- the original sequence
    "sequence" varchar not null,     -- the digest representing the original sequence
    length integer not null,
    primary key(accession)
);

-- Import Swiss-Prot proteins.

\copy tmp_uniprot_proteins from '<directory>/uniprot_sprot_proteins.txt.seq'

create index tmp_uniprot_proteins_sequence on tmp_uniprot_proteins(sequence);
analyze tmp_uniprot_proteins;

insert into uniprot_proteins
    select uniprotid, accession, sequencedate, taxid, mw, "sequence", length,
        'Swiss-Prot'
    from tmp_uniprot_proteins;

insert into uniprot_sequences
    select distinct "sequence", actualsequence
    from tmp_uniprot_proteins;

analyze uniprot_sequences;

drop index tmp_uniprot_proteins_sequence;
truncate tmp_uniprot_proteins;

-- Import TrEMBL proteins.

\copy tmp_uniprot_proteins from '<directory>/uniprot_trembl_proteins.txt.seq'

create index tmp_uniprot_proteins_sequence on tmp_uniprot_proteins(sequence);
analyze tmp_uniprot_proteins;

insert into uniprot_proteins
    select uniprotid, accession, sequencedate, taxid, mw, "sequence", length,
        'TrEMBL'
    from tmp_uniprot_proteins;

insert into uniprot_sequences
    select distinct A.sequence, A.actualsequence
    from tmp_uniprot_proteins as A
    left outer join uniprot_sequences as B
        on A.sequence = B.sequence
    where B.sequence is null;

analyze uniprot_sequences;

drop index tmp_uniprot_proteins_sequence;
truncate tmp_uniprot_proteins;

-- Import related data.

\copy uniprot_accessions from '<directory>/uniprot_sprot_accessions.txt'
\copy uniprot_accessions from '<directory>/uniprot_trembl_accessions.txt'
\copy uniprot_identifiers from '<directory>/uniprot_sprot_identifiers.txt'
\copy uniprot_identifiers from '<directory>/uniprot_trembl_identifiers.txt'
\copy uniprot_gene_names from '<directory>/uniprot_sprot_gene_names.txt'
\copy uniprot_gene_names from '<directory>/uniprot_trembl_gene_names.txt'

create index uniprot_accessions_accession on uniprot_accessions(accession);
analyze uniprot_accessions;

create index uniprot_proteins_sequence on uniprot_proteins(sequence);
analyze uniprot_proteins;

create index uniprot_sequences_sequence on uniprot_sequences(sequence);
analyze uniprot_sequences;

create index uniprot_proteins_index on uniprot_proteins(uniprotid);
analyze uniprot_proteins;

create index uniprot_gene_names_genename on uniprot_gene_names(genename);
analyze uniprot_gene_names;

-- Add FASTA data.

\copy tmp_uniprot_proteins from '<directory>/uniprot_sprot_varsplic_proteins.txt.seq'

create index tmp_uniprot_proteins_sequence on tmp_uniprot_proteins(sequence);
analyze tmp_uniprot_proteins;

-- Merge with the imported proteins.

insert into uniprot_proteins
    select A.uniprotid, A.accession, A.sequencedate, A.taxid, A.mw, A.sequence, A.length,
        'Swiss-Prot'
    from tmp_uniprot_proteins as A
    left outer join uniprot_proteins as B
        on A.accession = B.accession
    where B.uniprotid is null;

insert into uniprot_sequences
    select distinct A.sequence, A.actualsequence
    from tmp_uniprot_proteins as A
    left outer join uniprot_sequences as B
        on A.sequence = B.sequence
    where B.sequence is null;

create index uniprot_proteins_uniprotid on uniprot_proteins(uniprotid);
analyze uniprot_proteins;

analyze uniprot_sequences;

-- Fix isoform identifiers.

update uniprot_proteins
    set uniprotid = substring(uniprotid for position(' ' in uniprotid) - 1)
    where position(' ' in uniprotid) <> 0;

-- Add missing taxid information.

update uniprot_proteins as P
    set taxid = (
        select min(Q.taxid)
        from uniprot_proteins as Q
        where Q.uniprotid = P.uniprotid
            and Q.taxid is not null
        )
    where taxid is null;

analyze uniprot_proteins;

-- Add the isoform mapping.

insert into uniprot_isoforms
    select uniprotid, accession, substring(accession from 1 for 6) as parent
    from uniprot_proteins
    where length(accession) > 6;

analyze uniprot_isoforms;

commit;
