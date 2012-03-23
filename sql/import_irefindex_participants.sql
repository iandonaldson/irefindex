begin;

insert into xml_xref_participants
    select source, filename, entry, parentid as participantid, property,

        -- Fix certain psi-mi references.

        case when dblabel = 'MI' and not refvalue like 'MI:%' then 'MI:' || refvalue
             else refvalue
        end as refvalue

    from xml_xref
    where scope = 'participant'
        and property in ('participantIdentificationMethod', 'biologicalRole', 'experimentalRole')
        and dblabel in ('MI', 'psimi', 'PSI-MI', 'psi-mi');

commit;
