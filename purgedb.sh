#!/bin/bash

if [ `whoami` != "zextras" ]; then
        echo "ERROR! ${0} must be run by the zextras user"
        exit 1
fi


if [ $# -ne 1 ]; then
	echo "${0} [mysql id]"
	exit 1
else
	mailboxId="${1}"
fi

#mailboxId=`mysql -N -e "SELECT id FROM zimbra.mailbox WHERE comment='"${purgeMbx}"'"`
#groupId=`mysql -N -e "SELECT group_id FROM zimbra.mailbox WHERE comment='"${purgeMbx}"'"`
emailAddress=`mysql -N -e "SELECT comment FROM zimbra.mailbox WHERE id='"$mailboxId"'"`
groupId=`mysql -N -e "SELECT group_id FROM zimbra.mailbox WHERE id='"$mailboxId"'"`
mailboxDb="mboxgroup$groupId"

echo "Cleaning $emailAddress $mailboxId $mailboxDb"

purgeScriptsDir="/tmp"
echo "SET foreign_key_checks = 0;" > $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from appointment where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from appointment_dumpster where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from data_source_item where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from imap_folder where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from imap_message where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from mail_item where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from mail_item_dumpster where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from open_conversation where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from pop3_message where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from revision where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from revision_dumpster where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from tombstone where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from tag where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from tagged_item where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from data_source_item where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from event where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from purged_conversations where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from purged_messages where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from revision where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "delete from watch where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "SET foreign_key_checks = 1;" >> $purgeScriptsDir/clean-mboxgroup.sql
echo "Cleaning db $mailboxDb for id $mailboxId"
mysql $mailboxDb < $purgeScriptsDir/clean-mboxgroup.sql
# Clean zimbra db
echo "SET foreign_key_checks = 0;" > $purgeScriptsDir/clean-zimbra.sql
echo "LOCK TABLES mailbox WRITE;" >> $purgeScriptsDir/clean-zimbra.sql
echo "delete from mailbox where id=$mailboxId;" >> $purgeScriptsDir/clean-zimbra.sql
echo "SET foreign_key_checks = 1;" >> $purgeScriptsDir/clean-zimbra.sql
echo "COMMIT;" >> $purgeScriptsDir/clean-zimbra.sql
echo "UNLOCK TABLES;" >> $purgeScriptsDir/clean-zimbra.sql
echo "delete from out_of_office where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-zimbra.sql
echo "delete from scheduled_task where mailbox_id=$mailboxId;" >> $purgeScriptsDir/clean-zimbra.sql
echo "Cleaning  zimbra db for id $mailboxId"
mysql zimbra < $purgeScriptsDir/clean-zimbra.sql

