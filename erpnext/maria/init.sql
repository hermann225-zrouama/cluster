create user if not exists 'frappe'@'%' identified by 'frappe';
grant all privileges on *.* to 'frappe'@'%' with grant option;
create database if not exists `frappe`;