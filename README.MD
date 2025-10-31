**activateReplica.pl** is a script that once configured and scheduled on a Carbonio Aplication server will automatically promote all the newly created accounts.
The script needs a config file as input, Using multiple config files different domains can be replicated to different application server.

It requires some Perl libraries that can be installed using

apt install libnet-ldap-perl libyaml-perl libdbi-perl -y  
dnf install perl-YAML.noarch perl-DBD-Pg perl-LDAP -y

**purgedb.sh**: this script used to clean the Mysql db from orphaned accounts
