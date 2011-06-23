create database <database>;
create user '<username>'@'%' identified by '<password>';
grant all privileges on <database>.* to '<username>'@'%';
