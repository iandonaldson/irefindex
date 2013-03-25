-- Import sequences from a previous release of iRefIndex.

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

\copy irefindex_sequences_archived from '<directory>/sequences_archived'

create index irefindex_sequences_archived_index on irefindex_sequences_archived(dblabel, refvalue);
analyze irefindex_sequences_archived;

\copy irefindex_sequences_archived_original from '<directory>/sequences_archived_original'
analyze irefindex_sequences_archived_original;

commit;
