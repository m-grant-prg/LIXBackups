#! /usr/bin/env bash
##########################################################################
##									##
##	bckfullweekly.sh is automatically generated,			##
##		please do not modify!					##
##									##
##########################################################################

##########################################################################
##									##
## Script ID: bckfullweekly.sh						##
## Author: Mark Grant							##
##									##
## Purpose:								##
## Runs a level 0 incremental (ie full) backup of entire        	##
## file system. It allows for a cycle of 5 backups for weekly   	##
## coverage, designated by 1 - 5 which identifier is calculated 	##
## by day of month / 7 + 1                                      	##
## The weekly timing element is expected to be delivered via    	##
## cron.                                                        	##
##                                                              	##
## Syntax:      bckfullweekly.sh [-h || --help || -v || --version]	##
##									##
## Exit Codes:	0 & 64 - 113 as per C/C++ standard			##
##		0 - success						##
##		64 - Invalid arguments					##
##		65 - Failed mounting backup NAS server			##
##		66 - backup.snar non-existent or inaccesssible		##
##		67 - trap received					##
##									##
##########################################################################

##########################################################################
##									##
## Changelog								##
##									##
## Date		Author	Version	Description				##
##									##
## 02/04/2010	MG	1.0.1	Created.				##
## 26/08/2010	MG	1.0.2	Amended to use variables enabling some	##
##				system portability by setting these	##
##				variables at the start of the script.	##
## 11/09/2010	MG	1.0.3	Changed to use gzip.			##
## 24/09/2010	MG	1.0.4	Added disk stat logging and mailing,	##
##				done whilst backup share is attached.	##
## 18/11/2010	MG	1.0.5	Changed to emit help and version on	##
##				input of correct flag as argument. Also	##
##				stored version in string in Init section##
## 20/11/2010	MG	1.0.6	Removed shutdown from script. In cron	##
##				can use script.sh && shutdown		##
## 28/11/2010	MG	1.0.7	Changed script to read parameters from	##
##				etclocation/backups.conf.		##
## 14/12/2010	MG	1.0.8	Removed FreeBSD unsupported -B switch	##
##				from df -ah mailx command.		##
## 16/12/2010	MG	1.0.9	Allow the mailing of df -ah command	##
##				for any OS, not just FreeBSD.		##
## 10/01/2012	MG	1.0.10	Removed the .sh extension from the	##
##				command name. Add .gvfs file exclusion	##
##				to support Gnome desktops and Ubuntu.	##
## 06/11/2012	MG	1.0.11	Reverted to use the .sh file extension.	##
##				Added exclusion to tar command for /run	##
##				and /var/run following inclusion of	##
##				/run in Linux.				##
## 17/11/2012	MG	1.0.12	Moved NAS trash empty to after deletion	##
##				of this backup. Commented out deletion	##
##				of daily backups as this will now be	##
##				handled by the daily backup.		##
## 20/12/2012	MG	1.0.13	Added Host name and seuence number to	##
##				email message subject line.		##
## 06/02/2013	MG	1.0.14	Added mailing of backup file date	##
##				hierarchy after backup.			##
## 26/02/2013	MG	1.0.15	Changed command line option processing	##
##				to use getopts.				##
##									##
##########################################################################

exec 6>&1 7>&2 # Immediately make copies of stdout & stderr

####################
## Init variables ##
####################
script_exit_code=0
version="1.0.15"		# set version variable
etclocation=/usr/local/etc	# Path to etc directory

# Get system name for implementing OS differeneces.
osname=$(uname -s)

# Calculate backup sequence number. DoM/7 + 1
# Remove leading zeros otherwise thinks it is octal
bckseq=$(date +%d)
bckseq=$(echo $bckseq | sed 's/^0*//')
((bckseq=bckseq / 7 + 1))

###############
## Functions ##
###############
script_short_desc=$(uname -n)" Weekly Full Backup - "$bckseq

# Standard function to log $1 to stderr and mail to recipient
mess_log()
{
echo $1 1>&2
echo $1 | mailx -s "$script_short_desc" $mail_recipient
}

# Standard function to log and mail $1, cleanup and return exit code
script_exit()
{
mess_log "$1" 
exec 1>&6 2>&7 6>&- 7>&- # Restore stdin & stdout & close fd's 6 & 7
sleep 5
detbckshare.sh
exit $script_exit_code
}

# Standard trap exit function
trap_exit()
{
script_exit_code=67
script_exit "Script terminating due to trap received. Code: "$script_exit_code
}

# Setup trap
trap trap_exit SIGHUP SIGINT SIGTERM

##########
## Main ##
##########
# Process command line arguments with getopts.
while getopts :hv arg
do
	case $arg in
		h)	echo "Usage is $0 [options]"
			echo "	-h displays usage information"
			echo "	OR"
			echo "	-v displays version information"
			;;
		v)	echo "$0 version "$version
			;;
		\?)	echo "Invalid argument -$OPTARG." >&2
			exit 64
			;;
	esac
done

# If help or version requested then exit now.
if [ $# -gt 0 ]
	then
		exit 0
fi

# Read parameters from $etclocation/backups.conf
IFS="="

exec 3<$etclocation/backups.conf
while read -u3 -ra input
do
	case ${input[0]} in
	dir)
		bckupdir=${input[1]}
		;;
	notifyuser)
		mail_recipient=${input[1]}
		;;
	esac
done
exec 3<&-

# Build the backup & incremental file names and paths
backpath="/mnt/$bckupdir/backup"$bckseq".tar.gz"
snarpath="/mnt/$bckupdir/backup.snar"

# Check to see if the NAS backup server is mounted, if not, mount
attbckshare.sh
status=$?
if [ $status != "0" ]
	then
	script_exit_code=65
	script_exit "Failed to mount backup NAS server. Mount error: "$status" Script exit code: "$script_exit_code
fi

# Re-direct stdout & stderr to backup logs and write initial entries
exec 1>> /mnt/$bckupdir/backup.log 2>> /mnt/$bckupdir/backuperror.log
echo "Attempting to process backup - "$backpath
mess_log "Attempting to process backup - "$backpath

date
date 1>&2

# If the backup file exists, delete
if [ -f $backpath -a -r $backpath \
        -a -w $backpath ]
        then
                rm $backpath
fi

# If the level 0 incremental file exists, delete
if [ -f $snarpath -a -r $snarpath -a -w $snarpath ]
        then
                rm $snarpath
fi

# Empty the NAS trashbox
rm /mnt/$bckupdir/trashbox/*

<<Old_deletion_of_daily_backups.
# If the daily backup files exist, delete
if [ -f /mnt/$bckupdir/backup"Mon.tar.gz" \
	-a -r /mnt/$bckupdir/backup"Mon.tar.gz" \
	-a -w /mnt/$bckupdir/backup"Mon.tar.gz" ]
        then
                rm /mnt/$bckupdir/backup"Mon.tar.gz"
fi

if [ -f /mnt/$bckupdir/backup"Tue.tar.gz" \
	-a -r /mnt/$bckupdir/backup"Tue.tar.gz" \
	-a -w /mnt/$bckupdir/backup"Tue.tar.gz" ]
        then
                rm /mnt/$bckupdir/backup"Tue.tar.gz"
fi
if [ -f /mnt/$bckupdir/backup"Wed.tar.gz" \
	-a -r /mnt/$bckupdir/backup"Wed.tar.gz" \
	-a -w /mnt/$bckupdir/backup"Wed.tar.gz" ]
        then
                rm /mnt/$bckupdir/backup"Wed.tar.gz"
fi

if [ -f /mnt/$bckupdir/backup"Thu.tar.gz" \
	-a -r /mnt/$bckupdir/backup"Thu.tar.gz" \
	-a -w /mnt/$bckupdir/backup"Thu.tar.gz" ]
        then
                rm /mnt/$bckupdir/backup"Thu.tar.gz"
fi

if [ -f /mnt/$bckupdir/backup"Fri.tar.gz" \
	-a -r /mnt/$bckupdir/backup"Fri.tar.gz" \
	-a -w /mnt/$bckupdir/backup"Fri.tar.gz" ]
        then
                rm /mnt/$bckupdir/backup"Fri.tar.gz"
fi

if [ -f /mnt/$bckupdir/backup"Sat.tar.gz" \
	-a -r /mnt/$bckupdir/backup"Sat.tar.gz" \
	-a -w /mnt/$bckupdir/backup"Sat.tar.gz" ]
        then
                rm /mnt/$bckupdir/backup"Sat.tar.gz"
fi

if [ -f /mnt/$bckupdir/backup"Sun.tar.gz" \
	-a -r /mnt/$bckupdir/backup"Sun.tar.gz" \
	-a -w /mnt/$bckupdir/backup"Sun.tar.gz" ]
        then
                rm /mnt/$bckupdir/backup"Sun.tar.gz"
fi

# If the daily level 1 incremental files exist, delete
if [ -f /mnt/$bckupdir/backup"Mon.snar" -a -r /mnt/$bckupdir/backup"Mon.snar" \
        -a -w /mnt/$bckupdir/backup"Mon.snar" ]
        then
                rm /mnt/$bckupdir/backup"Mon.snar"
fi

if [ -f /mnt/$bckupdir/backup"Tue.snar" -a -r /mnt/$bckupdir/backup"Tue.snar" \
        -a -w /mnt/$bckupdir/backup"Tue.snar" ]
        then
                rm /mnt/$bckupdir/backup"Tue.snar"
fi
if [ -f /mnt/$bckupdir/backup"Wed.snar" -a -r /mnt/$bckupdir/backup"Wed.snar" \
        -a -w /mnt/$bckupdir/backup"Wed.snar" ]
        then
                rm /mnt/$bckupdir/backup"Wed.snar"
fi

if [ -f /mnt/$bckupdir/backup"Thu.snar" -a -r /mnt/$bckupdir/backup"Thu.snar" \
        -a -w /mnt/$bckupdir/backup"Thu.snar" ]
        then
                rm /mnt/$bckupdir/backup"Thu.snar"
fi

if [ -f /mnt/$bckupdir/backup"Fri.snar" -a -r /mnt/$bckupdir/backup"Fri.snar" \
        -a -w /mnt/$bckupdir/backup"Fri.snar" ]
        then
                rm /mnt/$bckupdir/backup"Fri.snar"
fi

if [ -f /mnt/$bckupdir/backup"Sat.snar" -a -r /mnt/$bckupdir/backup"Sat.snar" \
        -a -w /mnt/$bckupdir/backup"Sat.snar" ]
        then
                rm /mnt/$bckupdir/backup"Sat.snar"
fi

if [ -f /mnt/$bckupdir/backup"Sun.snar" -a -r /mnt/$bckupdir/backup"Sun.snar" \
        -a -w /mnt/$bckupdir/backup"Sun.snar" ]
        then
                rm /mnt/$bckupdir/backup"Sun.snar"
fi
Old_deletion_of_daily_backups.

# Get list of sockets to exclude
find / -type s > /mnt/$bckupdir/socket_exclude

# Run the backup excluding system directories
case $osname in
FreeBSD)
	gtar -cpzf $backpath --listed-incremental=$snarpath \
		--exclude=proc --exclude=lost+found --exclude=tmp \
		--exclude=mnt --exclude=media --exclude='cdro*' --exclude=dev \
		--exclude=sys --exclude='.gvfs' \
		--exclude-from=/mnt/$bckupdir/socket_exclude /
	status=$?
;;
Linux)
	tar -cpzf $backpath --listed-incremental=$snarpath \
		--exclude=proc --exclude=lost+found --exclude=tmp \
		--exclude=mnt --exclude=media --exclude='cdro*' --exclude=dev \
		--exclude=sys --exclude='.gvfs' \
		--exclude=run --exclude=var/run \
		--exclude-from=/mnt/$bckupdir/socket_exclude /
	status=$?
;;
esac

# Final log entries and restore stdout & stderr
date
date 1>&2
echo "Processing of "$backpath" is complete. Status: "$status
mess_log "Processing of "$backpath" is complete. Status: "$status
##################################################################
## It is not clear why the following two lines cause everything ##
## to hang until charybdis is restarted. It is probably due to  ##
## the odd wiring relating to the kvm which powers off if	##
## charybdis or scylla are not powered up. So this only affects	##
## priam during EOD backup routines which shutdown machines on	##
## completion. So until fixed test on OS.			##
##################################################################
if [ $osname == "FreeBSD" ]
  then
  df -ah # Log disk stats
  ls -lht /mnt/$bckupdir
fi

# Mail disk stats
df -ah | mailx -s "$script_short_desc" $mail_recipient

# Mail backup file date hierarchy
ls -lht /mnt/$bckupdir | mailx -s "$script_short_desc" $mail_recipient

exec 1>&6 2>&7 6>&- 7>&- # Restore stdout & stderr & close fd's 6 & 7

# Cleanup logs so they only have 1000 lines max
tail -n 1000 /mnt/$bckupdir/backup.log > /mnt/$bckupdir/tmp.log
sleep 5
rm /mnt/$bckupdir/backup.log
sleep 5
mv /mnt/$bckupdir/tmp.log /mnt/$bckupdir/backup.log
sleep 5
tail -n 1000 /mnt/$bckupdir/backuperror.log > /mnt/$bckupdir/tmp.log
sleep 5
rm /mnt/$bckupdir/backuperror.log
sleep 5
mv /mnt/$bckupdir/tmp.log /mnt/$bckupdir/backuperror.log
sleep 5

# Unmount the backup NAS server
detbckshare.sh

# And exit
exit 0
