purgedb.sh: used to clean the Mysql db from orphaned accounts

activateReplica.pl a script that once configured and scheduled on a Carbonio Aplication server will automatically promote  all the newly created accounts 
the script need and config file as input, 

It requires some Perl libraries that can be installed using

apt install libnet-ldap-perl libyaml-perl libdbi-perl -y
dnf install perl-YAML.noarch perl-DBD-Pg perl-LDAP -y

Using multiple config files different domains can be replicated to different application server
