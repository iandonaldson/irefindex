-- Import data into the schema.

-- Copyright (C) 2011, 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

create temporary table tmp_refseq_proteins (
    accession varchar,
    version varchar,
    gi integer not null,
    taxid integer,
    "sequence" varchar not null,
    length integer not null
);

create temporary table tmp_refseq_identifiers (
    accession varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    position integer not null
);

create temporary table tmp_refseq_nucleotides (
    nucleotide varchar not null,
    protein varchar not null
);

\copy tmp_refseq_proteins from '<directory>/refseq_proteins.txt.seq'
\copy tmp_refseq_identifiers from '<directory>/refseq_identifiers.txt'
\copy tmp_refseq_nucleotides from '<directory>/refseq_nucleotides.txt'

insert into refseq_proteins
    select accession, version,
        case when position('.' in version) <> 0 then
            cast(substring(version from position('.' in version) + 1) as integer)
        else null end as vnumber,
        gi, taxid, "sequence", length, false as missing
    from tmp_refseq_proteins;

insert into refseq_identifiers
    select accession, dblabel, refvalue, position, false as missing
    from tmp_refseq_identifiers;

insert into refseq_nucleotides
    select nucleotide, protein, false as missing
    from tmp_refseq_nucleotides;

create index refseq_proteins_accession on refseq_proteins(accession);
create index refseq_proteins_version on refseq_proteins(version);
create index refseq_proteins_sequence on refseq_proteins(sequence);

analyze refseq_proteins;
analyze refseq_identifiers;
analyze refseq_nucleotides;

insert into refseq_nucleotide_accessions
    select distinct nucleotide, substring(nucleotide from '[^.]*') as shortform, false as missing
    from refseq_nucleotides;

create index refseq_nucleotide_accessions_shortform on refseq_nucleotide_accessions(shortform);
analyze refseq_nucleotide_accessions;

commit;
