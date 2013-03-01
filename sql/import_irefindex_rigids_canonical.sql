-- Import canonical RIG identifiers generated from canonical ROG identifiers.

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

\copy irefindex_rigids_canonical from '<directory>/rigids_for_interactions_canonical'
analyze irefindex_rigids_canonical;

-- A mapping from canonical RIG identifiers to canonical ROG identifiers without
-- reference to specific interactions.

insert into irefindex_distinct_interactions_canonical
    select crigid as rigid, crogid as rogid
    from irefindex_rigids_canonical as C
    inner join irefindex_distinct_interactions as I
        on C.rigid = I.rigid
    inner join irefindex_rogids_canonical as R
        on I.rogid = R.rogid;

create index irefindex_distinct_interactions_canonical_rigid on irefindex_distinct_interactions_canonical(rigid);
analyze irefindex_distinct_interactions_canonical;

commit;
