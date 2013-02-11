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

\copy bind_interactors from '<directory>/interactors.txt'
\copy bind_complexes from '<directory>/complexes.txt'
\copy bind_complex_references from '<directory>/complex_references.txt'
\copy bind_references from '<directory>/references.txt'
\copy bind_labels from '<directory>/labels.txt'

-- Remove interactions involving small molecules and unrecognised entities.
-- Since removing only such interactors would risk interactions being
-- underspecified and erroneously interpreted as being complete, should the
-- other interactors be identified, the entire interaction is removed in each
-- case.

-- NOTE: There are some records in BIND that have ill-formed formatting.
-- NOTE: For example, complex #257564.
-- NOTE: Such records are discarded here.

delete from bind_interactors
    where interactionid in (
        select interactionid
        from bind_interactors
        where participantType not in ('gene', 'protein', 'DNA', 'RNA', 'complex')
        );
delete from bind_complexes
    where bcid in (
        select bcid
        from bind_complexes
        where participantType not in ('gene', 'protein', 'DNA', 'RNA', 'complex')
        );

-- Add an implicit interactor identifier.

create temporary sequence bind_interactors_interactorid;

alter table bind_interactors add column interactorid integer;

update bind_interactors set interactorid = nextval('bind_interactors_interactorid');

alter table bind_interactors alter column interactorid set not null;

-- Add indexes.

create index bind_interactors_index on bind_interactors(interactionid);
create index bind_complexes_index on bind_complexes(bcid);

analyze bind_interactors;
analyze bind_complexes;
analyze bind_complex_references;
analyze bind_references;
analyze bind_labels;

insert into xml_interactors

    -- Get the identifiers from each interactor.

    select 'BIND' as source, filename, 0 as entry, cast(interactorid as varchar) as interactorid,
        cast(participantid as varchar) as participantid, cast(interactionid as varchar) as interactionid
    from bind_interactors
    union all

    -- Get the identifiers from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, cast(interactorid as varchar) as interactorid,
        cast(interactorid as varchar) as participantid, cast(bcid as varchar) as interactionid
    from bind_complexes;

insert into xml_xref

    -- Get the accession.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'primaryRef' as reftype, accession as refvalue, database as dblabel,
        null as dbcode, 'primary-reference' as reftypelabel, 'MI:0358' as reftypecode
    from bind_interactors
    where database <> 'BIND'
        and accession not in ('-', '', 'NA')
    union all

    -- Get the gi.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'secondaryRef' as reftype, gi as refvalue, 'genbank_protein_gi' as dblabel,
        null as dbcode, 'identity' as reftypelabel, 'MI:0356' as reftypecode
    from bind_interactors
    where gi <> '0'
    union all

    -- Get the accession from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'primaryRef' as reftype, accession as refvalue, database as dblabel,
        null as dbcode, 'primary-reference' as reftypelabel, 'MI:0358' as reftypecode
    from bind_complexes
    where database <> 'BIND'
        and accession not in ('-', '', 'NA')
    union all

    -- Get the gi from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'secondaryRef' as reftype, gi as refvalue, 'genbank_protein_gi' as dblabel,
        null as dbcode, 'identity' as reftypelabel, 'MI:0356' as reftypecode
    from bind_complexes
    where gi <> '0'
    union all

    -- Get the interaction identifier from the group of records representing an interaction.

    select distinct 'BIND' as source, filename, 0 as entry, 'interaction' as scope,
        cast(interactionid as varchar) as parentid, 'interaction' as property,
        'primaryRef' as reftype, cast(bindid as varchar) as refvalue, 'bind' as dblabel,
        null as dbcode, 'primary-reference' as reftypelabel, 'MI:0358' as reftypecode
    from bind_interactors
    union all

    -- Get the interaction identifier from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interaction' as scope,
        cast(bcid as varchar) as parentid, 'interaction' as property,
        'primaryRef' as reftype, cast(bcid as varchar) as refvalue, 'bind' as dblabel,
        null as dbcode, 'primary-reference' as reftypelabel, 'MI:0358' as reftypecode
    from bind_complexes
    union all

    -- Get the PubMed references for interactions.

    select distinct 'BIND' as source, filename, 0 as entry, 'experimentDescription' as scope,
        cast(I.interactionid as varchar) as parentid, 'bibref' as property,
        'primaryRef' as reftype, pmid as refvalue, 'pubmed' as dblabel,
        'MI:0446' as dbcode, 'primary-reference' as reftypelabel, 'MI:0358' as reftypecode
    from bind_interactors as I
    inner join bind_references as R
        on I.bindid = R.bindid
        and pmid <> '-1'
    union all

    -- Get the PubMed references for complexes.

    select distinct 'BIND' as source, filename, 0 as entry, 'experimentDescription' as scope,
        cast(I.bcid as varchar) as parentid, 'bibref' as property,
        'primaryRef' as reftype, pmid as refvalue, 'pubmed' as dblabel,
        'MI:0446' as dbcode, 'primary-reference' as reftypelabel, 'MI:0358' as reftypecode
    from bind_complexes as I
    inner join bind_complex_references as R
        on I.bcid = R.bcid
        and pmid <> '-1'
    union all

    -- Get the interactor types.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(I.interactorid as varchar) as parentid, 'interactorType' as property,
        'primaryRef' as reftype, code as refvalue, 'psi-mi' as dblabel,
        null as dbcode, 'identity' as reftypelabel, 'MI:0356' as reftypecode
    from bind_interactors as I
    inner join psicv_terms as T
        on I.participanttype = T.name
        and (I.participanttype <> 'gene' or T.nametype = 'preferred')
    union all
    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(I.interactorid as varchar) as parentid, 'interactorType' as property,
        'primaryRef' as reftype, code as refvalue, 'psi-mi' as dblabel,
        null as dbcode, 'identity' as reftypelabel, 'MI:0356' as reftypecode
    from bind_complexes as I
    inner join psicv_terms as T
        on I.participanttype = T.name
        and (I.participanttype <> 'gene' or T.nametype = 'preferred');

insert into xml_names

    -- Get the short label from each interactor's group of labels.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'shortLabel' as nametype, null as typelabel, null as typecode, shortLabel as name
    from bind_interactors as I
    inner join bind_labels as L
        on I.bindid = L.bindid
        and I.participantid = L.participantid
    union all

    -- Get the aliases.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'alias' as nametype, null as typelabel, null as typecode, alias as name
    from bind_interactors as I
    inner join bind_labels as L
        on I.bindid = L.bindid
        and I.participantid = L.participantid
    union all

    -- Get the short label from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'shortLabel' as nametype, null as typelabel, null as typecode, shortLabel as name
    from bind_complexes
    union all

    -- Get the alias from each record representing a complex.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, 'interactor' as property,
        'alias' as nametype, null as typelabel, null as typecode, alias as name
    from bind_complexes
    union all

    -- Get the methods.

    select distinct 'BIND' as source, filename, 0 as entry, 'experimentDescription' as scope,
        cast(I.interactionid as varchar) as parentid, 'interactionDetectionMethod' as property,
        'shortLabel' as nametype, null as typelabel, null as typecode, method as name
    from bind_interactors as I
    inner join bind_references as R
        on I.bindid = R.bindid
        and method is not null;

insert into xml_organisms

    -- Get the taxid from each interactor.

    select 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, taxid
    from bind_interactors
    union all

    -- Get the taxid from the group of records representing a complex.

    select distinct 'BIND' as source, filename, 0 as entry, 'interactor' as scope,
        cast(interactorid as varchar) as parentid, taxid
    from bind_complexes;

-- A one-to-one mapping from experiments to interactions is defined, reusing the
-- interaction identifier.

insert into xml_experiments
    select distinct 'BIND' as source, filename, 0 as entry, cast(interactionid as varchar) as interactionid,
        cast(interactionid as varchar) as interactionid
    from bind_interactors
    union all
    select distinct 'BIND' as source, filename, 0 as entry, cast(bcid as varchar) as interactionid,
        cast(bcid as varchar) as interactionid
    from bind_complexes;

commit;
