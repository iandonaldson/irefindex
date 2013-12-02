-- Collect interaction-related information.

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

-- NOTE: It appears that most databases provide usable primary references for
-- NOTE: all interactions, unlike those provided for their interactors.

-- NOTE: MPPI and OPHID do not provide interaction identifiers. Both sources
-- NOTE: provide data in PSI-MI XML 1.0 format, but do seem to provide
-- NOTE: experiment information that could be usable.

insert into xml_xref_all_interactions
    select distinct source, filename, entry, parentid as interactionid,

        -- Normalise database labels.

        case when dblabel like 'uniprot%' or dblabel in ('SP', 'Swiss-Prot', 'TREMBL') then 'uniprotkb'
             when dblabel like 'entrezgene%' or dblabel like 'entrez gene%' then 'entrezgene/locuslink'
             when dblabel like '%pdb' then 'pdb'
             when dblabel in ('protein genbank identifier', 'genbank indentifier') then 'genbank_protein_gi'
             when dblabel in ('MI', 'psimi', 'PSI-MI') then 'psi-mi'
             else dblabel
        end as dblabel,

        -- Fix certain psi-mi references.

        case when dblabel = 'MI' and not refvalue like 'MI:%' then 'MI:' || refvalue
             when dblabel = 'MI' and refvalue like 'MI:%' and not refvalue ~ 'MI:[0-9]{4}' then substring(refvalue from 'MI:[0-9]{4}')
             else refvalue
        end as refvalue,

        reftype,
        reftypelabel

    from xml_xref

    -- Restrict to interactions and specifically to primary and secondary references.

    where scope = 'interaction'
        and property = 'interaction'
        and reftype in ('primaryRef', 'secondaryRef');

analyze xml_xref_all_interactions;

-- Get preferred identifiers for the interactions.

insert into xml_xref_interactions
    select source, filename, entry, interactionid, identifier[2] as dblabel, identifier[3] as refvalue
    from (
        select source, filename, entry, interactionid, max(array[reftype, dblabel, refvalue]) as identifier
        from xml_xref_all_interactions
        where reftype = 'primaryRef'
            or reftype = 'secondaryRef' and (
                source = 'INTACT' and dblabel = 'intact' and reftypelabel = 'identity'
                or source = 'MATRIXDB' and dblabel = 'matrixdb' and reftypelabel = 'identity'
                )
        group by source, filename, entry, interactionid
        ) as X;

analyze xml_xref_interactions;

-- Get interaction types.
-- Only the PSI-MI form of interaction types are of interest.

insert into xml_xref_interaction_types

    -- Normalise database labels.

    select distinct source, filename, entry, parentid as interactionid,

        -- Fix certain psi-mi references.

        case when dblabel = 'MI' and not refvalue like 'MI:%' then 'MI:' || refvalue
             else refvalue
        end as refvalue

    from xml_xref

    -- Restrict to interactors and specifically to primary and secondary references.

    where scope = 'interaction'
        and property = 'interactionType'
        and reftype in ('primaryRef', 'secondaryRef')
        and dblabel in ('psi-mi', 'MI', 'PSI-MI', 'psimi');

analyze xml_xref_interaction_types;

-- Get interaction names.

insert into xml_names_interaction_names
    select distinct source, filename, entry, parentid as interactionid, nametype, name
    from xml_names
    where scope = 'interaction'
        and property = 'interaction';

analyze xml_names_interaction_names;

commit;
