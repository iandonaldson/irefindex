create database <database>;
create user '<username>'@'%' identified by '<password>';

grant select, insert, update, delete, create, drop, references, index, alter,
    create temporary tables, lock tables, execute, create view, show view,
    create routine, alter routine
on <database>.* to '<username>'@'%';

grant process, file on *.* to '<username>'@'%';
