#!/usr/bin/env sh
##############################################################################
# aliceBackup
# AUTHOR  : Jefferson 'Slackjeff' Carneiro <slackjeff@riseup.net>
# LICENSE:  GPLv3
#
# TODO:
#   * need to improve the sending part via ssh + rsync.
#   * Improve part about deleting files on the remote server every X days.
#     Standard 15 days. It does not need to be run every time each backup.
##############################################################################

#set -e

#----------------------------------------------------------------------------#
# Global Vars
#----------------------------------------------------------------------------#

# Used to flag backups, example:
# backup-full-20240205_224113.tar.xz
date="$(date +"%Y-%m-%d-%H%M%S")"

# Port of ssh Default is 22
SSH_PORT='22'

SSH_SERVER="192.168.30.28"

# Include here Path of id_rsa
ID_RSA=''

# Delete backups older than X days
# DEFAULT IS 15 DAYS
deleteOlderBackups='15'

###########################
# RSYNC ARGS
###########################
RSYNC_CMD="--archive --verbose --human-readable --compress"

#----------------------------------------------------------------------------#
# Don't Edit
#----------------------------------------------------------------------------#

# PRG Version
version="0.2"

##########################################
# Make a full backup EVERY Sunday = 7    #
##########################################
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

# Remote dir storage ALL backups
backupRemoteDir="/backup-storage"

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
\trsync://USER@example.com
\nUsage Examples:
"
    exit 1
}

DIE()
{
    msg="$1"
    printf -- "$msg\n"
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
    printf "\n#==========================================================#\n"
    printf "| BACKUP DIFFERENTIAL\n"
    printf "#==========================================================#\n"
    # Need count to increment .snar and not overwrite full backup .snar
    count=$(ls -1 /backup/backup-diff-*.snar 2>/dev/null | wc -l)
    count=$((count+1))
    cp ${backupDir}/backup-full-$machineName.snar \
    ${backupDir}/backup-diff-$machineName-${count}.snar
    tar      \
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
    remoteDirectory="$2"
    printf "\n#==========================================================#\n"
    printf "| RSYNC Send to: $host\n"
    printf "#==========================================================#\n"
    cd ${backupDir}
    if [ -n "$ID_RSA" ] && [ -n "$SSH_PORT" ]; then
        rsync $RSYNC_CMD --exclude '*.snar' . ${sendServer}:${remoteDirectory} -e "ssh -p $SSH_PORT -i $ID_RSA"
        if [ "$?" -ne 0 ]; then
            return 1
        fi
    else
        rsync $RSYNC_CMD --exclude '*.snar' . ${sendServer}:${remoteDirectory} -e "ssh -p $SSH_PORT"
        if [ "$?" -ne 0 ]; then
            return 1
        fi
    fi
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
    if [ "$dayOfTheWeek" -eq 7 ]; then
        printf "\n#==========================================================#\n"
        printf "| Rotate Day!\n"
        printf "\n#==========================================================#\n"
        cd "$backupDir"
        rm -v *.snar 2>/dev/nul
    else
        return 0
    fi
}

# Delete old backup remote server...
DELETE_OLD_BACKUP_REMOTE_SERVER()
{
    printf "\n#==========================================================#\n"
    printf "# DELETE BACKUPS MORE THAN: ${deleteOlderBackups} Days"
    printf "\n#==========================================================#\n"
    ssh -p "$SSH_PORT" "${userAndHost}" -i "$ID_RSA" \
    "find \"$backupRemoteDir\" -type f -mtime +\"$deleteOlderBackups\" -exec rm -v {} +"
}

#----------------------------------------------------------------------------#
# MAIN
#----------------------------------------------------------------------------#

# Loop options and args
if [ "$#" -eq 0 ];then
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
            [ -z "$excludeCut" ] && USAGE
            excludes="$excludes --exclude=$excludeCut"
            shift
        ;;
        --delete-backups-more-than=*)
            deleteOlderBackups=$(echo $1 | cut -d= -f2)
            if [ -z "$deleteOlderBackups" ]; then
                DIE "You need to pass a value to know backups longer than how many days I should delete.\n Example: --delete-backups-more-than=10"
            fi
            shift
        ;;
        # Send backup with RSYNC METHOD
        rsync://*)
            userAndHost=${1##rsync://} # Remove rsync://
            # Remove directory if user enter user@example:/directory
            # and keep only user@example
            userAndHost=${userAndHost%%:*}
            [ -z "$userAndHost" ] && USAGE
            shift
        ;;
        --remote-dir=*)
            remoteDirCut=$(echo $1 | cut -d= -f2)
            [ -z $remoteDirCut ] && USAGE
            backupRemoteDir="$remoteDirCut"
            shift
        ;;
        --port=*)
            portCut=$(echo $1 | cut -d= -f2)
            [ -z "$portCut" ] && USAGE
            SSH_PORT="$portCut"
            shift
        ;;
        --id-rsa=*)
            idrsaCut=$(echo $1 | cut -d= -f2)
            [ -z "$idrsaCut" ] && USAGE
            ID_RSA="$idrsaCut"
            if [ ! -f "$ID_RSA" ]; then
                DIE "--id-rsa='$ID_RSA' NOT FOUND..."
            fi
            shift
        ;;
        --help)
            USAGE
        ;;
        *)
            printf -- "$1: Unknown option.\n"
            USAGE
        ;;
    esac
done

# Let's test if the --source directories exist.
for check in $sourceDirectory; do
    if [ ! -d "$check" ]; then
        DIE "Directory include in --source=$check DON'T EXIST."
    fi
done

# Test ssh connection without remote dir :/
printf "\nTest Connection: "
if ! ssh -q $(echo ${userAndHost%:/*}) "exit"; then
    DIE "[${userAndHost%:/*} its correct? (No route to host).]"
fi
printf "[OK]\n"

################################
## OK, START BACKUP.
################################

# Rotate day = 7?
ROTATE_DAY

# Which backup are we going make?
if [ -f ${backupDir}/backup-full-${machineName}.snar ]; then
    DIFFERENTIAL_BACKUP "$sourceDirectory" "$excludes"
else
    FULL_BACKUP "$sourceDirectory" "$excludes"
fi

if [ -n "$userAndHost" ]; then
    # Send Server
    RSYNC_SEND "$userAndHost" "$backupRemoteDir" || DIE "Error. Aborting backup."
else
    printf "\nBackup was not SENT TO SERVER!"
    DIE "\nBackup was not SENT TO SERVER\nYou need to pass an argument to rsync! Example: rsync://root@192.168.30.28 .\n"
fi

# Keep only headers .snar for next control.
REMOVE_LOCAL_BACKUPS

if [ -n "$deleteOlderBackups" ]; then
    DELETE_OLD_BACKUP_REMOTE_SERVER
fi
