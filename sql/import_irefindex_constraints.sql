-- Tidy up XML data and add constraints.

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

-- Several workarounds are required before adding constraints.

-- Remove useless records.

delete from xml_names where name is null;
delete from xml_xref where refvalue is null;

-- Now the constraints can be added.

analyze xml_experiments;

alter table xml_interactors add primary key (source, filename, entry, interactionid, interactorid, participantid);
analyze xml_interactors;

alter table xml_names alter column name set not null;
analyze xml_names;

alter table xml_xref alter column refvalue set not null;
analyze xml_xref;

analyze xml_organisms;

commit;
