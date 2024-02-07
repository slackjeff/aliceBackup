#!/usr/bin/env sh
##############################################################################
# aliceBackup
# AUTHOR  : Jefferson 'Slackjeff' Carneiro <slackjeff@riseup.net>
# LICENSE:  GPLv3
##############################################################################
#set -e

#----------------------------------------------------------------------------#
# Don't Edit, use /etc/alicebackup/alicebackup.conf
#----------------------------------------------------------------------------#

# PRG Version
version="0.2"

# Used to flag backups, example:
# backup-full-20240205_224113.tar.xz
date="$(date +"%Y-%m-%d-%H%M%S")"

# aliceBackup Configure Dir
aliceConfigureDir="/etc/alicebackup"

# aliceBackup Configure File
aliceConfigureFile="alicebackup.conf"

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
backupLocalDir="/backup"

# Remote dir storage ALL backups
backupRemoteDir="/backup-storage"

# For perfomance.
export LC_ALL=C
export LANG=C

#----------------------------------------------------------------------------#
# Tests
#----------------------------------------------------------------------------#

# Root?
[ $(id -u) -ne 0 ] && { printf "Need root."; exit 1 ;}

# Create local structure.
[ ! -d "$backupLocalDir" ] && mkdir -v "$backupLocalDir"

[ ! -d "$aliceConfigureDir" ] && mkdir -pv "$aliceConfigureDir"

if [ ! -f "${aliceConfigureDir}/$aliceConfigureFile" ]; then
    cat <<EOF > "${aliceConfigureDir}/$aliceConfigureFile"
# aliceBackup Machine Local Configure File
EOF
fi

#----------------------------------------------------------------------------#
# Load Conf
#----------------------------------------------------------------------------#

# Load local machine configure
. "${aliceConfigureDir}/$aliceConfigureFile"

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
    --file=${backupLocalDir}/backup-full-$machineName-$date.tar.gz \
    --listed-incremental=${backupLocalDir}/backup-full-$machineName.snar \
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
    cp ${backupLocalDir}/backup-full-$machineName.snar \
    ${backupLocalDir}/backup-diff-$machineName-${count}.snar
    tar      \
    $exclude \
    --create \
    --file=${backupLocalDir}/backup-diff-$machineName-$date.tar.gz \
    --listed-incremental=${backupLocalDir}/backup-diff-$machineName-${count}.snar     \
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
    cd ${backupLocalDir}
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
    cd ${backupLocalDir}
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
        cd "$backupLocalDir"
        rm -v *.snar 2>/dev/nul
    else
        return 0
    fi
}

PRESS_ESCAPE()
{
    exitstatus="$1"
    if [ "$exitstatus" -eq 1 ]; then
        exit
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

CONFIGURE_ME()
{
    while :; do
        sshConfigureMe=$(whiptail --title "SSH SERVER IP/DOMAIN" \
        --inputbox "IP or domain of your SSH server: " 10 70 \
        3>&1 1>&2 2>&3)
        exitstatus=$?
        PRESS_ESCAPE "$exitstatus"

        sshPortConfigureMe=$(whiptail --title "SSH PORT" --inputbox \
        "PORT of your SSH server: " 10 70 3>&1 1>&2 2>&3)
        exitstatus=$?
        PRESS_ESCAPE "$exitstatus"

        idRsaConfigureMe=$(whiptail --title "ID RSA" --inputbox \
        "FULL PATH of YOUR ID_RSA.\nExample:\n/home/MyUser/.ssh/computer1.rsa " \
        10 70 3>&1 1>&2 2>&3)
        exitstatus=$?
        PRESS_ESCAPE "$exitstatus"

        backupLocalDirConfigureMe=$(whiptail --title "LOCAL DIRECTORY TO BACKUP" \
        --inputbox \
        "FULL PATH of the location where the backups will be stored on your LOCAL COMPUTER!\n/backup is default." 10 70 3>&1 1>&2 2>&3)
        exitstatus=$?
        PRESS_ESCAPE "$exitstatus"

        backupRemoteDirConfigureMe=$(whiptail --title "REMOTE DIRECTORY TO BACKUP" \
        --inputbox \
        "FULL PATH of the location where the backups will be stored on REMOTE SERVER!\nDefault is /backupServer" 10 70 3>&1 1>&2 2>&3)
        exitstatus=$?
        PRESS_ESCAPE "$exitstatus"

        if whiptail --title "Correct INFORMATION?" \
        --yesno "All informations correct?\n\n[SSH IP/Domain]: $sshConfigureMe\n[PORT]: $sshPortConfigureMe\n[PATH ID_RSA]: $idRsaConfigureMe\n[LOCAL DIRECTORY BKP]: $backupLocalDirConfigureMe\n[REMOTE DIRECTORY BKP]: $backupRemoteDirConfigureMe" 15 70; then
            break
        else
            continue
        fi
    done
    [ -z "$sshPortConfigureMe" ] && sshPortConfigureMe="22"
    [ -z "$backupLocalDirConfigureMe" ] && backupLocalDirConfigureMe="/backup"
    [ -z "$backupRemoteDirConfigureMe" ] && backupRemoteDirConfigureMe="/backupServer"

    cat << EOF >> "${aliceConfigureDir}/$aliceConfigureFile"

#####################################################################
# SSH CONFIGURE
#####################################################################

# SSH IP/HOST/DOMAIN
SSH_SERVER="$sshConfigureMe"
# SSH PORT
SSH_PORT="$sshPortConfigureMe"
# ID RSA LOCAL
ID_RSA="$idRsaConfigureMe"

#####################################################################
# DIRECTORY CONFIGURE
#####################################################################

# Local Machine Directory
backupLocalDir="$backupLocalDirConfigureMe"
# Remote Machine/server Directory
backupRemoteDir="$backupRemoteDirConfigureMe"

#####################################################################
# OTHERS
#####################################################################

# Delete backups older than X days. DEFAULT 15 DAYS
deleteOlderBackups='15'

# RSYNC ARGS
RSYNC_CMD="--archive --verbose --human-readable --compress"

EOF

    whiptail --title "INFORMATION" --msgbox "If you need to edit any set variables, you can do so in: /etc/alicebackup.conf." 10 70
    exit
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
        --configure-me)
            CONFIGURE_ME
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
if [ -f ${backupLocalDir}/backup-full-${machineName}.snar ]; then
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
