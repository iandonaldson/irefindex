-- Import MITAB-originating data.

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

\copy mitab_uid from '<directory>/mitab_uid.txt'
-- \copy mitab_alternatives from '<directory>/mitab_alternatives.txt'
\copy mitab_aliases from '<directory>/mitab_alias.txt'
\copy mitab_method_names from '<directory>/mitab_method.txt'
\copy mitab_authors from '<directory>/mitab_authors.txt'
\copy mitab_pubmed from '<directory>/mitab_pmids.txt'
\copy mitab_interaction_type_names from '<directory>/mitab_interactionType.txt'
\copy mitab_sources from '<directory>/mitab_sourcedb.txt'
\copy mitab_interaction_identifiers from '<directory>/mitab_interactionIdentifiers.txt'
-- \copy mitab_confidence from '<directory>/mitab_confidence.txt'

commit;
