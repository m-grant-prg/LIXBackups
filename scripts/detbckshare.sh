#! /usr/bin/env bash
##########################################################################
##									##
##	detbckshare.sh is automatically generated,			##
##		please do not modify!					##
##									##
##########################################################################

##########################################################################
##									##
## Script ID: detbckshare.sh						##
## Author: Mark Grant							##
##									##
## Purpose:								##
## To unmount the backup share on the NAS server. E.g.			##
##	/mnt/mybackupdirectory						##
##	from								##
## 	\\MyServer\mybackupdirectory					##
##									##
## Syntax:	detbckshare.sh [-h || --help || -v || --version]	##
##									##
## Exit Codes:	0 & 64 - 113 as per C/C++ standard			##
##		0 - success						##
##		64 - Invalid arguments					##
##		65 - Failed to unmount backup NAS server		##
##		66 - Backup share not mounted				##
##		67 - trap received					##
##									##
## Further info:							##
## This script is part of the portable backup package.			##
##									##
##									##
##########################################################################

##########################################################################
##									##
## Changelog								##
##									##
## Date		Author	Version	Description				##
##									##
## 09/04/2010	MG	1.0.1	Created for Linux.			##
## 26/08/2010	MG	1.0.2	Revised to support FreeBSD as well as	##
##				Linux. Also, backup variables		##
##				introduced at beginning of script to	##
##				enhance portability. (E.g. System,	##
##				backup user etc.).			##
## 18/11/2010	MG	1.0.3	Changed to emit help and version on	##
##				input of correct flag as argument. Also	##
##				stored version in string in Init section##
## 28/11/2010	MG	1.0.4	Changed script to read parameters from	##
##				etclocation/backups.conf.		##
## 10/01/2012	MG	1.0.5	Removed the .sh extension from the	##
##				command name.				##
## 05/11/2012	MG	1.0.6	Reverted to .sh file extension.		##
##									##
##########################################################################

####################
## Init variables ##
####################
script_exit_code=0
version="1.0.6"			# set version variable
etclocation=/usr/local/etc	# Path to etc directory

###############
## Functions ##
###############
# Standard function to log $1 to stderr
mess_log()
{
echo $1 1>&2
}

# Standard function to message stderr, any cleanup and return exit code
script_exit()
{
mess_log "$1" 
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
# Command line must have 1 or no arguments
if [ $# -gt 1 ]
	then
		echo "Script can only take 1 argument. Try --help."
		exit 64
fi

if [ $# = 1 ]; then
	case $1 in
		-h|-H)
			echo "Usage is detbckshare.sh [options]"
			echo "	-h or --help displays usage information"
			echo "	OR"
			echo "	-v or --version displays version information"
			;;
		--help|--HELP)
			echo "Usage is detbckshare.sh [options]"
			echo "	-h or --help displays usage information"
			echo "	OR"
			echo "	-v or --version displays version information"
			;;
		-v|-V)
			echo "detbckshare.sh version "$version
			;;
		--version|--VERSION)
			echo "detbckshare.sh version "$version
			;;
		*)
			echo "Invalid argument. Try --help"
			exit 64
			;;
	esac
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
	esac
done
exec 3<&-

# Check to see if the NAS backup server is mounted, if it is, unmount
if [ "$(mount | grep "/mnt/$bckupdir")" != "" ]
	then
	umount /mnt/$bckupdir
	status=$?
	if [ $status != "0" ]
		then
		script_exit_code=65
		script_exit "Failed to unmount backup NAS server. Umount error: "$status" Script exit code: "$script_exit_code
	fi
	else
	script_exit_code=66
	script_exit "Backup share not mounted. Script exit code: "$script_exit_code
fi
exit 0
