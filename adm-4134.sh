#!/bin/bash

# Script for backup Yandex.Disk and upload to S3
# ADM-4134
# YuryS
# 06.04.2023

function variables {
    today=$(date +'%Y-%m-%d')
    month=$(date +'%Y-%m')
    backupdir=/home/adm-4134/YandexDisk_backup/$month/$today/YandexDisk_backup
    archivedir=/home/adm-4134/YandexDisk_backup/$month/$today/YandexDisk_backup.tar
    encryptedtar=/home/adm-4134/YandexDisk_backup/$month/$today/YandexDisk_backup.tar.gpg
    passfile=/home/adm-4134/.gnupg/adm-4134.pgpass
    result=0
    ZABBIX_SERVER="zabbix-proxy.clouds"
    ZABBIX_HOST=$(hostname)
    ZABBIX_KEY="yd_backup" 
}

source /usr/local/sbin/functions
trap cleanup EXIT

function cleanup {
    functions.lockfile delete
}

function checkReturnCode {
    if [ $1 -ne 0 ]; then
        zabbix 1 
        exit
    fi
}

function backupYD {
    find /home/adm-4134/YandexDisk_backup/* -type f -mtime +3 -exec rm -f {} \;
    echo "Cloning YD"
    rclone copy YandexDisk:Backup $backupdir
    checkReturnCode $?
    echo "Archiving files"
    tar cf - $backupdir | pigz -9 -p 2 > $archivedir
    if [ $? -eq 0 ]; then
        rm -rf $backupdir
    else 
        checkReturnCode $?
    fi
    echo "Encoding archive"
    gpg --batch --passphrase-file $passfile -c $archivedir
    if [ $? -eq 0 ]; then
        rm -rf $archivedir
    else 
        checkReturnCode $?
    fi
    echo "Archive to S3"
    s3cmd -c /home/backup_s3/.s3cfg put $encryptedtar s3://..../YandexDisk/$month/$today.YandexDisk.tar.gpg &> /dev/null
    checkReturnCode $?
    zabbix 0 
}

function zabbix {
    zabbix_sender -z $ZABBIX_SERVER -s $ZABBIX_HOST -k $ZABBIX_KEY -o $1 &> /dev/null
}

function main {
    echo INFO: Start script    
    variables
    functions.lockfile create    
    backupYD
    cleanup
}

main 2>&1|functions.logging