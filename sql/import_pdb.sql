-- Import data into the schema.

-- Copyright (C) 2011, 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

create temporary table tmp_pdb_proteins (
    accession varchar not null,
    chain varchar not null,
    gi integer not null,
    actualsequence varchar not null,
    "sequence" varchar not null,
    length integer not null,
    primary key(accession, chain)
);

\copy tmp_pdb_proteins from '<directory>/pdbaa_proteins.txt.seq'

create index tmp_pdb_proteins_sequence on tmp_pdb_proteins(sequence);
analyze tmp_pdb_proteins;

insert into pdb_proteins
    select accession, chain, gi, "sequence", length
    from tmp_pdb_proteins;

insert into pdb_sequences
    select distinct "sequence", actualsequence
    from tmp_pdb_proteins;

create index pdb_proteins_sequence on pdb_proteins(sequence);
analyze pdb_proteins;

commit;
