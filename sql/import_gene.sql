-- Import data into the schema.

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

\copy gene2refseq from '<directory>/gene2refseq.txt'
\copy gene_info from '<directory>/gene_info.txt'
\copy gene_synonyms from '<directory>/gene_synonyms.txt'
\copy gene_history from '<directory>/gene_history.txt'

analyze gene2refseq;
analyze gene_info;
analyze gene_synonyms;
analyze gene_history;

commit;
