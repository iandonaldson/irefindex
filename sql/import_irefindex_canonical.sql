-- Initiate the canonicalisation process by finding related genes: those
-- associated with the same ROG identifier.

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

-- Make a comprehensive mapping from genes to proteins.

insert into irefindex_gene2rog
    select geneid, sequence || taxid as rogid
    from irefindex_gene2refseq
    union
    select geneid, sequence || taxid as rogid
    from irefindex_gene2uniprot;

alter table irefindex_gene2rog add primary key(geneid, rogid);
analyze irefindex_gene2rog;

-- Make an initial gene-to-gene mapping via shared ROG identifiers.

insert into irefindex_gene2related
    select distinct A.geneid, B.geneid as related
    from irefindex_gene2rog as A
    inner join irefindex_gene2rog as B
        on A.rogid = B.rogid;

analyze irefindex_gene2related;

-- Define a mapping of relevant genes using known sequences from interaction
-- records. This activity is performed before assignment because the result of
-- the canonicalisation process is meant to be used in the assignment of
-- sequences to identifiers in situations where many sequences are suggested for
-- an interactor but where a canonical representative might be an appropriate
-- disambiguator or alternative representation of an interactor.

-- Since identifiers for active interaction records are not yet available, but
-- since the protein identifier mapping must cover all known sequences and these
-- must also be considered in the canonicalisation process, ROG identifiers
-- generated from the full sequence collection are employed instead.

create temporary table tmp_rogids as
    select rogid
    from irefindex_sequence_rogids
    union
    select distinct sequence || taxid as rogid
    from xml_xref_interactors
    where sequence is not null and taxid is not null;

analyze tmp_rogids;

insert into irefindex_gene2related_active
    select distinct A.geneid, B.geneid as related
    from irefindex_gene2rog as A
    inner join irefindex_gene2rog as B
        on A.rogid = B.rogid
    inner join tmp_rogids as C
        on A.rogid = C.rogid;

analyze irefindex_gene2related_active;

insert into irefindex_gene2related_known select * from irefindex_gene2related_active;

analyze irefindex_gene2related_known;

commit;
