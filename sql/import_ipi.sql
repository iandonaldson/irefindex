-- Import data into the schema.

-- Copyright (C) 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

create temporary table tmp_ipi_proteins (
    accession varchar not null,
    actualsequence varchar not null,
    "sequence" varchar not null,
    length integer not null,
    primary key(accession)
);

\copy tmp_ipi_proteins from '<directory>/ipi_proteins.txt.seq'

create index tmp_ipi_proteins_sequence on tmp_ipi_proteins(sequence);
analyze tmp_ipi_proteins;

insert into ipi_proteins
    select accession, "sequence", length
    from tmp_ipi_proteins;

insert into ipi_sequences
    select distinct "sequence", actualsequence
    from tmp_ipi_proteins;

insert into ipi_accessions
    select accession, substring(accession from '[^.]*') as shortform
    from ipi_proteins;

create index ipi_proteins_sequence on ipi_proteins(sequence);
analyze ipi_proteins;

create index ipi_accessions_shortform on ipi_accessions(shortform);
analyze ipi_accessions;

\copy ipi_identifiers from '<directory>/ipi_identifiers.txt'

analyze ipi_identifiers;

commit;
