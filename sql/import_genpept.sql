-- Import data into the schema.

-- Copyright (C) 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

create temporary table tmp_genpept_proteins (
    accession varchar not null,
    db varchar not null,
    gi integer not null,
    organism varchar not null,
    "sequence" varchar not null
);

\copy tmp_genpept_proteins from '<directory>/genpept_proteins.txt.seq'
analyze tmp_genpept_proteins;

insert into genpept_proteins
    select accession, db, gi, case when taxids = 1 then taxid else null end, "sequence"
    from (
        select accession, db, gi, "sequence", count(distinct taxid) as taxids, min(taxid) as taxid
        from tmp_genpept_proteins
        left outer join taxonomy_names
            on organism = name
        group by accession, db, gi, "sequence"
        ) as X;

create index genpept_proteins_sequence on genpept_proteins(sequence);
create index genpept_proteins_gi on genpept_proteins(gi);
analyze genpept_proteins;

insert into genpept_accessions
    select accession, substring(accession from 1 for position('.' in accession) - 1)
    from genpept_proteins
    group by accession;

create index genpept_accessions_shortform on genpept_accessions(shortform);
analyze genpept_accessions;

commit;
