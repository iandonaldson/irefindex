-- Show unknown interaction types.

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

create temporary table tmp_unknown_types as
    select I.refvalue, count(*) as total
    from xml_xref_interaction_types as I
    left outer join psicv_terms as T
        on I.refvalue = T.code
    where T.code is null
    group by I.refvalue
    order by I.refvalue;

\copy tmp_unknown_types to '<directory>/unknown_interaction_types'

rollback;
