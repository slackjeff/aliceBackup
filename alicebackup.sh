#!/usr/bin/env sh
##############################################################################
# aliceBackup
# AUTHOR  : Jefferson 'Slackjeff' Carneiro <slackjeff@riseup.net>
# LICENSE:  GPLv3
#
# ROADMAP
# () Implement backup restore method with tar + rsync.
# () Create check for No space left on device.
# () Create complete log system.
#
##############################################################################

#set -e

#----------------------------------------------------------------------------#
# Global Vars
#----------------------------------------------------------------------------#

# PRG Version
version="0.1"
# Used to flag backups, example:
# backup-full-20240205_224113.tar.xz
date="$(date +"%Y-%m-%d-%H%M%S")"

##########################################
# Make a full backup EVERY Sunday = 7    #
#  1    2    3    4    5    6    7       #
# Mon  Tue  Wed  Thu  Fri  Sat  Sunday   #
# Seg  Ter  Qua  Qui  Sex  Sab  Dom      #
# Lun  Mar  Mié  Jue  Vie  Sab  Dom      #
##########################################

dayOfTheWeek=$(date +%u)

# Util for multiple backups in server.
machineName=$(hostname -s)

# Directory where will backup made in local machine.
backupDir="/backup"

#----------------------------------------------------------------------------#
# No Edit
#----------------------------------------------------------------------------#

# For perfomance.
export LC_ALL=C
export LANG=C

#----------------------------------------------------------------------------#
# Load Conf
#----------------------------------------------------------------------------#

#for loadMe in /home/slackjeff/Scripts/aliceBackup/*.conf; do
#    source $loadMe
#done

#----------------------------------------------------------------------------#
# Tests
#----------------------------------------------------------------------------#

# Root?
[ $(id -u) -ne 0 ] && { printf "Need root."; exit 1 ;}
# Create local structure.
[ ! -d $backupDir ] && mkdir -v $backupDir

#----------------------------------------------------------------------------#
# Functions
#----------------------------------------------------------------------------#

# Mode Usage
USAGE()
{
    printf "\
aliceBackup - version $version\n
Options:
\t--source=/dir/for/create/backup/
\t--exclude-this=/exclude/file/or/directory/
\t--html-log
\trsync://USER@example.com:/backupServer
\nUsage Examples:
$(basename $0) --exclude-this=".local" --exclude-this="/var/log/dir" --source=/home --source=/etc rsync://username@example.com:/backupServer
"
    exit 1
}

# Create a Full Backup
FULL_BACKUP()
{
    sourceDirectory="$1"
    exclude="$2"
    printf "#==========================================================#\n"
    printf "| BACKUP FULL\n"
    printf "#==========================================================#\n"
    tar \
    --verbose \
    $exclude \
    --create \
    --file=${backupDir}/backup-full-$machineName-$date.tar.gz \
    --listed-incremental=${backupDir}/backup-full-$machineName.snar \
    $sourceDirectory
}

# Create differential Backup.
DIFFERENTIAL_BACKUP()
{
    sourceDirectory="$1"
    exclude="$2"
    printf "#==========================================================#\n"
    printf "| BACKUP DIFFERENTIAL\n"
    printf "#==========================================================#\n"
    # Need count to increment .snar and not overwrite full backup .snar
    count=$(ls -1 /backup/backup-diff-*.snar 2>/dev/null | wc -l)
    count=$((count+1))
    cp ${backupDir}/backup-full-$machineName.snar \
    ${backupDir}/backup-diff-$machineName-${count}.snar
    tar      \
    --verbose \
    $exclude \
    --create \
    --file=${backupDir}/backup-diff-$machineName-$date.tar.gz \
    --listed-incremental=${backupDir}/backup-diff-$machineName-${count}.snar     \
    $sourceDirectory
}

# After making backuyp, send it with rsync to storage in server or
# other local.
RSYNC_SEND()
{
    sendServer="$1"
    printf "\n#==========================================================#\n"
    printf "| RSYNC Send to: $host\n"
    printf "#==========================================================#\n"
    cd ${backupDir}
    rsync -avh --exclude '*.snar' . $sendServer
}

# Remove local backups for store only on the server.
REMOVE_LOCAL_BACKUPS()
{
    cd ${backupDir}
    printf "\n=======> Remove Local Backup <=======\n"
    rm -v backup-diff-*.tar.gz 2>/dev/null
    rm -v backup-full-*.tar.gz 2>/dev/null
}

# Rotate. Every 7 days delete files with *.snar metada and
# start over with the full backup.
ROTATE_DAY()
{
    if [ $dayOfTheWeek -eq 7 ]; then
        printf "\n#==========================================================#\n"
        printf "| Rotate Day!\n"
        printf "\n#==========================================================#\n"
        cd $backupDir
        rm -v *.snar 2>/dev/nul
    else
        return 0
    fi
}

#----------------------------------------------------------------------------#
# MAIN
#----------------------------------------------------------------------------#

# Loop options and args
if [ $# -eq 0 ];then
    USAGE
fi

while [ -n "$1" ]; do
    case "$1" in
        --source=*)
            sourceDirectoryCut=$(echo $1 | cut -d= -f2)
            sourceDirectory="$sourceDirectory $sourceDirectoryCut"
            shift
        ;;
        --exclude-this=*)
            excludeCut=$(echo $1 | cut -d= -f2)
            [ -z $excludeCut ] && USAGE
            excludes="$excludes --exclude=$excludeCut"
            shift
        ;;
        # Send backup with RSYNC METHOD
        rsync://*)
            rsync=${1##rsync://}
            [ -z $rsync ] && USAGE
            shift
        ;;
        *)
            printf -- "$1: Unknown option.\n"
            USAGE
        ;;
    esac
done

# Rotate day = 7?
ROTATE_DAY

# Which backup are we going make?
if [ -f ${backupDir}/backup-full-${machineName}.snar ]; then
    DIFFERENTIAL_BACKUP "$sourceDirectory" "$excludes"
else
    FULL_BACKUP "$sourceDirectory" "$excludes"
fi

# Send Server
RSYNC_SEND "$rsync"

# Keep only headers .snar for next control.
REMOVE_LOCAL_BACKUPS
