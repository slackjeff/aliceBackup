#!/usr/bin/env sh
#----------------------------------------------------------------------------#
# aliceBackup
#----------------------------------------------------------------------------#
set -e

#----------------------------------------------------------------------------#
# Global Vars
#----------------------------------------------------------------------------#
aliceVersion="0.1"
date="$(date "+%Y%m%d_%H%M%S")"

# Nome da máquina
machineName=$(hostname -s)

# Local aonde sera feito o backup na máquina
backupDir="/backup"

# Local para armazenar o backup antigo...
# Que a cada 7 dias é rotacionado e jogado para cá.
backupDirOld="${backupDir}/old"

#----------------------------------------------------------------------------#
# Load Conf
#----------------------------------------------------------------------------#

#for loadMe in /home/slackjeff/Scripts/aliceBackup/*.conf; do
#    source $loadMe
#done

#----------------------------------------------------------------------------#
# Tests
#----------------------------------------------------------------------------#
[ ! -d $backupDir ] && mkdir -v $backupDir
[ ! -d $backupDirOld ] && mkdir -v $backupDirOld

#----------------------------------------------------------------------------#
# Functions
#----------------------------------------------------------------------------#
USAGE()
{
    echo "ARGUMENTS"
    echo "--exclude-list [list of exclude files]"
    echo "ssh://example@example.com"
    exit 1
}

STATISTICS()
{
    printf "\n######################### SUMARRY ############################\n"
    printf "Backup Start: $(date)\n"
    printf "Backup End  : $(date)\n"
    printf "Delta Size  : $(du -sh ${backupDir}/full-backup-$machineName.snar)\n"
    printf "Total Backup Dir :\n$(du -h ${backupDir}/)\n"
    printf "##############################################################\n"

}

FULL_BACKUP()
{
    sourceDirectory="$1"
    tar --verbose \
    --create \
    --file=${backupDir}/backup-full-$machineName-$date.tar \
    --listed-incremental=${backupDir}/full-backup-$machineName.snar \
    $sourceDirectory
}

INCREMENTAL_BACKUP()
{
    sourceDirectory="$1"
    tar --verbose \
    --create \
    --file=${backupDir}/backup-incremental-$machineName-$date.tar \
    --incremental ${backupDir}/full-backup-$machineName.snar \
    $sourceDirectory
}

# Rotacione o backup a cada 7 dias.
ROTATE_BACKUP()
{
    if [ "$(date +%u)" -eq 7 ]; then
        printf "######################### ROTATE\n"
        cd $backupDir
        for rotate in *; do
            [ $rotate = old ] && continue
            printf "File: $rotate"
            if mv $rotate $backupDirOld; then
                printf " [OK]\n"
            fi
        done
    fi
    return 0
}

#----------------------------------------------------------------------------#
# MAIN
#----------------------------------------------------------------------------#

[ $# -eq 0 ] && USAGE
while [ "$#" -ne 0 ]; do
    case "$1" in
        --source)
            shift
            sourceDirectory="$1 $sourceDirectory"
            ;;
        --exclude-this)
            shift
            excluded="$1 $excluded"
        ;;
        # Metodo ssh
        ssh://*)
            ssh=${1##ssh://}
            shift
        ;;
        --quiet)
            verbose="0" # Desligado
            shift
        ;;
        --verbose)
            verbose="1" # Ligado
        ;;
        *) USAGE ;;
    esac
    shift
done

# Rotacione o backup se necessário.
ROTATE_BACKUP
if [ -f ${backupDir}/full-backup-$machineName.snar ]; then
    INCREMENTAL_BACKUP "$sourceDirectory"
else
    FULL_BACKUP "$sourceDirectory"
fi

# Imprimir as estatistica? Padrão é sim.
if [ -z $verbose ] || [ "$verbose" = 1 ]; then
    STATISTICS
fi
