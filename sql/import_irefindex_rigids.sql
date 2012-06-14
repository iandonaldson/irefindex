-- Import RIG identifiers generated from ROG identifiers.

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

\copy irefindex_rigids from '<directory>/rigids_for_interactions'
analyze irefindex_rigids;

-- A mapping from RIG identifiers to ROG identifiers for complete interactions.

insert into irefindex_interactions
    select I.source, I.filename, I.entry, O.interactorid, X.participantid, I.interactionid, O.rogid, I.rigid
    from irefindex_rigids as I
    inner join xml_interactors as X
        on (I.source, I.filename, I.entry, I.interactionid) =
           (X.source, X.filename, X.entry, X.interactionid)
    inner join irefindex_rogids as O
        on (X.source, X.filename, X.entry, X.interactorid) =
           (O.source, O.filename, O.entry, O.interactorid);

analyze irefindex_interactions;

-- A mapping from RIG identifiers to ROG identifiers without reference to
-- specific interactions.

insert into irefindex_distinct_interactions
    select rigid, rogid
    from (
        select min(array[source, filename, cast(entry as varchar), interactionid]) as first
        from irefindex_interactions
        group by rigid
        ) as X
    inner join irefindex_interactions as I
        on X.first = array[I.source, I.filename, cast(I.entry as varchar), I.interactionid];

create index irefindex_distinct_interactions_rigid on irefindex_distinct_interactions(rigid);
analyze irefindex_distinct_interactions;

commit;
