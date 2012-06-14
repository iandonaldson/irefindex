-- Show interaction size statistics.

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

create temporary table tmp_interaction_sizes as
    select participants, count(distinct array[source, filename, cast(entry as varchar), interactionid]) as total
    from (
        select source, filename, entry, interactionid, count(interactorid) as participants
        from xml_interactors
        group by source, filename, entry, interactionid
        ) as X
    group by participants
    order by participants;

\copy tmp_interaction_sizes to '<directory>/interactions_by_size'

rollback;
