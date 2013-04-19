-- Generate the final gene groups for canonicalisation.

-- Copyright (C) 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

insert into irefindex_rgg_genes
    select min(related) as rggid, geneid
    from irefindex_gene2related_known
    group by geneid;

analyze irefindex_rgg_genes;

insert into irefindex_rgg_rogids
    select distinct rggid, rogid
    from irefindex_rgg_genes as G
    inner join irefindex_gene2rog as R
        on G.geneid = R.geneid;

analyze irefindex_rgg_rogids;

-- Use the length and primary UniProt accession availability, selecting a RefSeq
-- accession otherwise.

-- Since there may be more than one sequence with the maximum length for a
-- canonical group from a particular sequence database, the minimum ROG
-- identifier is chosen in such situations.

insert into irefindex_rgg_rogids_canonical
    select R.rggid, coalesce(min(G1.sequence || G1.taxid), min(G2.sequence || G2.taxid)) as rogid
    from irefindex_rgg_rogids as R

    -- Find the longest non-isoform UniProt sequence for the canonical group.

    left outer join (
        select rggid, max(length) as length
        from irefindex_rgg_rogids as R
        inner join irefindex_gene2uniprot as G
            on R.rogid = G.sequence || G.taxid
        where not G.accession like '%-%'
        group by rggid
        ) as X1
        on R.rggid = X1.rggid
    left outer join irefindex_gene2uniprot as G1
        on X1.length = G1.length
        and R.rogid = G1.sequence || G1.taxid
        and not G1.accession like '%-%'

    -- Find the longest RefSeq sequence for the canonical group.

    left outer join (
        select rggid, max(length) as length
        from irefindex_rgg_rogids as R
        inner join irefindex_gene2refseq as G
            on R.rogid = G.sequence || G.taxid
        group by rggid
        ) as X2
        on R.rggid = X2.rggid
    left outer join irefindex_gene2refseq as G2
        on X2.length = G2.length
        and R.rogid = G2.sequence || G2.taxid
    group by R.rggid;

analyze irefindex_rgg_rogids_canonical;

-- A complete canonical mapping for all sequences.
-- This is needed by the protein identifier mapping.

insert into irefindex_sequence_rogids_canonical
    select distinct R.rogid, coalesce(C.rogid, R.rogid)
    from irefindex_sequence_rogids as R

    -- Not all sequences have a mapping to genes.

    left outer join irefindex_rgg_rogids as G
        on R.rogid = G.rogid
    left outer join irefindex_rgg_rogids_canonical as C
        on G.rggid = C.rggid;

analyze irefindex_sequence_rogids_canonical;

-- A complete mapping of active canonical ROG identifiers is produced once a
-- definitive list of ROG identifiers is available.

-- Canonical RIG identifiers are produced once RIG identifiers are available.

commit;
