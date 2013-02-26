#! /usr/bin/env bash
##########################################################################
##									##
##	bckfulladhoc.sh is automatically generated,			##
##		please do not modify!					##
##									##
##########################################################################

##########################################################################
##									##
## Script ID: bckfulladhoc.sh						##
## Author: Mark Grant							##
##									##
## Purpose:								##
## To run a full system backup, not part of any sequence, so		##
## just date/time stamped.						##
##                                                              	##
## Syntax:      bckfulladhoc.sh [-h || --help || -v || --version]	##
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
## 28/11/2010	MG	1.0.6	Changed script to read parameters from	##
##				etclocation/backups.conf.		##
## 14/12/2010	MG	1.0.7	Removed FreeBSD unsupported -B switch	##
##				from df -ah mailx command.		##
## 10/01/2012	MG	1.0.8	Removed the .sh extension from the	##
##				command name. Add .gvfs file exclusion	##
##				to support Gnome desktops and Ubuntu.	##
## 06/11/2012	MG	1.0.9	Reverted to use the .sh file extension.	##
##				Added exclusion to tar command for /run	##
##				and /var/run following inclusion of	##
##				/run in Linux.				##
##20/12/2012	MG	1.0.10	Added Host name and date/time suffix	##
##				to email message subject line.		##
## 26/02/2013	MG	1.0.11	Changed command line option processing	##
##				to use getopts.				##
##									##
##########################################################################

exec 6>&1 7>&2	# Immediately make copies of stdout & stderr

####################
## Init variables ##
####################
script_exit_code=0
version="1.0.11"		# set version variable
etclocation=/usr/local/etc	# Path to etc directory

###############
## Functions ##
###############
script_short_desc=$(uname -n)" Ad Hoc Full Backup "$(date '+%Y%m%d%H%M')

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

# Build the backup file name and path
backpath="/mnt/$bckupdir/backup"$(date '+%Y%m%d%H%M')".tar.gz"

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

# Not likely, but if it already exists, delete
if [ -f $backpath -a -r $backpath \
        -a -w $backpath ]
        then
                rm $backpath
fi

# Get list of sockets for exclusion
find / -type s > /mnt/$bckupdir/socket_exclude

# Run the backup excluding system directories
tar -cpzf $backpath --exclude=proc --exclude=lost+found --exclude=run \
	--exclude=tmp --exclude=mnt --exclude=media --exclude='cdro*' \
	--exclude=dev --exclude=sys --exclude='.gvfs' --exclude=var/run \
	--exclude-from=/mnt/$bckupdir/socket_exclude /
status=$?

# Final log entries and restore stdout & stderr
date
date 1>&2
echo "Processing of "$backpath" is complete. Status: "$status
mess_log "Processing of "$backpath" is complete. Status: "$status
df -ah # Log disk stats

# Was using the line buffered -B switch but this is not available under FreeBSD
df -ah | mailx -s "$script_short_desc" $mail_recipient # Mail disk stats
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
