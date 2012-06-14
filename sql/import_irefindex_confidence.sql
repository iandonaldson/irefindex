-- Interaction confidence scoring.

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

create temporary table tmp_pubmed_interactions as
    select distinct refvalue as pmid, rigid
    from xml_experiments as E
    inner join xml_xref_experiment_pubmed as P
        on (E.source, E.filename, E.entry, E.experimentid) =
           (P.source, P.filename, P.entry, P.experimentid)
    inner join irefindex_rigids as I
        on (E.source, E.filename, E.entry, E.interactionid) =
           (I.source, I.filename, I.entry, I.interactionid);

create temporary table tmp_pubmed_count as
    select pmid, count(distinct rigid) as interactions
    from tmp_pubmed_interactions
    group by pmid;

analyze tmp_pubmed_interactions;
analyze tmp_pubmed_count;

insert into irefindex_confidence
    select rigid, 'lpr' as scoretype, min(interactions) as score
    from (
        select rigid, interactions
        from tmp_pubmed_interactions as A
        inner join tmp_pubmed_count as B
            on A.pmid = B.pmid
        ) as X
    group by rigid;

insert into irefindex_confidence
    select rigid, 'hpr' as scoretype, max(interactions) as score
    from (
        select rigid, interactions
        from tmp_pubmed_interactions as A
        inner join tmp_pubmed_count as B
            on A.pmid = B.pmid
        ) as X
    group by rigid;

insert into irefindex_confidence
    select rigid, 'np' as scoretype, count(distinct pmid) as score
    from tmp_pubmed_interactions
    group by rigid;

analyze irefindex_confidence;

commit;
