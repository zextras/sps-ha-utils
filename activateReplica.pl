#!/usr/bin/perl  
##############################################################################
#
#   Author:             Lorenzo Fascì
#
##############################################################################
use strict;
use Net::LDAP;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw( LDAP_CONTROL_PAGED );
use JSON;
use Data::Dumper;
use Encode;
use YAML qw/LoadFile/;
use DBI;
 
################ START GLOBAL DEFINITIONS ######################## 

my $configFile = ""; 
if ($ARGV[0] ne "") {
    $configFile = $ARGV[0]; 
} else {
    print "Usage: $0 configFile\n";
    exit 1;
}

my $config = LoadFile($configFile); 

my $createLog = @{$config}{'create_log'};

#Local LDAP
my $localLdapHost = @{$config}{'local_ldap_server'};
my $localLdapPort = @{$config}{'local_ldap_port'};
my $localLdapProto = @{$config}{'local_ldap_proto'};
my $zcsLdapUri = "$localLdapProto://$localLdapHost:$localLdapPort";
my $localBind = @{$config}{'local_ldap_user_dn'};
my $localPassword = @{$config}{'local_ldap_password'};
my $localSearchBase =  @{$config}{'local_ldap_searchbase'};
my $localFilter =  @{$config}{'local_ldap_filter'};
my $localAttr =  @{$config}{'local_ldap_attr'};
my $localAttributes =  @{$config}{'local_ldap_attrs'};

#HA
my $db_host = @{$config}{'pg_server'};
my $db_port = @{$config}{'pg_port'};
my $db_user = @{$config}{'pg_user'};
my $db_name = @{$config}{'pg_db'};
my $db_pass = @{$config}{'pg_password'}; 
my $dstHostname = @{$config}{'dst_hostname'}; 

my $encoding = $^O eq 'MSWin32' ? 'cp850' : 'utf8';

#Create a log file
my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
my $mdy = sprintf '%d_%d_%d', $mday, $mon+1,$year+1900;
my $hm = $hour."_".$min;
my $logFile = @{$config}{'log_file_dir'}.$mdy."_".$hm.".txt";
my $xcgContacts = @{$config}{'exchange_contacts'};

my $local = Net::LDAP->new($zcsLdapUri, onerror => 'die') or die "Could not connect to ldap directory!";
$local->bind($localBind, password=>$localPassword);

my @localIds = &ldapGet($local,$localSearchBase, $localFilter, $localAttr);

my @promotedAccounts = ();
my $db = "dbi:Pg:dbname=$db_name;host=$db_host;port=$db_port";
my $dbh = DBI->connect($db, $db_user, $db_pass,{ RaiseError => 1, AutoCommit => 0 }) || die "Error connecting to the database: $DBI::errstr\n";
my @haData = &execSelect($dbh, "SELECT account_id, status, update_time, mail_host, replica_topic_id FROM replica_account");
foreach my $r (@haData) {
	push(@promotedAccounts, $r->{'account_id'});
}
$dbh->disconnect();	

my $notPromoted = sub_array(\@localIds, \@promotedAccounts);
if ($notPromoted) {
	my $toPromoteList = join( ",",@$notPromoted);
	if ($toPromoteList ne "") {
		my $execRemove = system("su - zextras -c \"/opt/zextras/bin/carbonio ha setAccountDestination $dstHostname 10 accounts $toPromoteList\"");
		print $execRemove;
		print "su - zextras -c \"/opt/zextras/bin/carbonio ha setAccountDestination $dstHostname 10 accounts $toPromoteList\" \n";

	}
}

##&ldapGet($ldapObj,$searchbase, $filter,$attribute);
sub ldapGet() {
	my $ldapObj = shift;
	my $searchbase = shift;
	my $filter = shift;
	my $attribute = shift;
	my @values = ();
	# print "$searchbase $filter $attribute\n";
	my $page = Net::LDAP::Control::Paged->new(size => 900);
	my $cookie;
	while (1) {
		my $mesg = $ldapObj->search(
			base    => $searchbase,
			filter  => $filter,
			attrs   => [$attribute],
			control => [$page]
		);

		$mesg->code && die "Error on search: $@ : " . $mesg->error;
		while (my $ldapEntry = $mesg->pop_entry()) {
			# print ($ldapEntry->get_value($attribute)."\n");
			push (@values, $ldapEntry->get_value($attribute));
		}

		my ($resp) = $mesg->control(LDAP_CONTROL_PAGED) or last;
		$cookie    = $resp->cookie or last;
		# Paging Control
		$page->cookie($cookie);
	}
	return @values;
}

# my $ref = &sub_array(\@array1,\@array2);
sub sub_array () {
  my $a1   = shift; # array reference
  my $a2   = shift; # array reference
  my @a1m2 = ();
  # Se i due array sono definiti
	if ($a1 && $a2) {
		@a1m2 = @$a1;  # array 1 minus array 2;
   	for my $element (@$a2) {
       	for my $index (0..$#a1m2) {
           	if ($element eq $a1m2[$index]) {
               	splice @a1m2, $index, 1;
               	last;
           	}
       	}
   	}
	if ($#a1m2+1 > 0) {
			return \@a1m2;
		}else {
			return 0;   		
		}	
	} elsif ($a1) {
		return $a1;
	}	
}	 


sub genTimestamp() {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $mdy = sprintf '%d/%d/%d', $mday, $mon+1,$year+1900;
    my $hms = $hour.":".$min.":".$sec;
    return $mdy." ".$hms;
}

sub writeLog() {
    my $message = shift;  
    my $logFile = shift;  
    open (LOGFILE, ">>$logFile") or die "Can't open $logFile : $!";
    flock LOGFILE, 2;
	print LOGFILE &genTimestamp()." $message\n";
    flock LOGFILE, 8;
    close(LOGFILE);
}

sub execSelect {
	my $dbh = shift;
	my $query = shift;
    my @arrayRef;
	my $sth = $dbh->prepare( $query );
	my $rv = $sth->execute() or die $DBI::errstr;
	if($rv < 0) {
	   print $DBI::errstr;
	}
	my $rowRef = $sth->fetchrow_hashref;
    while (my $row_ref = $sth->fetchrow_hashref())   {
		push (@arrayRef,$row_ref);
    }
    $sth->finish;
    return @arrayRef;
}