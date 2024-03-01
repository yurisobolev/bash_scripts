#!/bin/bash

# Script checking brute forse atack
# YuryS
# 26.07.2023

source /usr/local/sbin/functions
trap cleanup EXIT

function variables {
    TICKET="1"
    main_dir=/tmp/1/
    Log=/var/log/radius/radius.log
    past_Log=/var/log/radius/radius.log.1
    text=/tmp/1/text.txt
    id_list=/tmp/1/id_list.txt
    result_file=/tmp/1/script.log
    ip_count_file=/tmp/1/ip_count_file.txt
    result=0
    ZABBIX_SERVER="192.168.20.122"
    ZABBIX_HOST=s-system
    ZABBIX_KEY="failed_connection"
}

function cleanup {
   functions.lockfile delete
}

function main_action {

        if [ ! -d "$main_dir" ]; then
                mkdir -p "$main_dir"
        fi

        sort -u $text >> tmpfile && mv tmpfile $text
        all_id=$(cat $text)
        for id in $all_id ; do
                grep -F "$id" $Log >> $id_list
        done
        sort -u $id_list >> tmpfile && mv tmpfile $id_list
        grep -F "Calling-Station-Id" $id_list >> tmpfile && mv tmpfile $id_list
        grep -o '".*"' $id_list | sed 's/"//g' >> $ip_count_file

        all_ips=$(cat $ip_count_file)
        for ip in $all_ips ; do
                count=$( grep -o -i $ip $ip_count_file | wc -l)

                if [ $count  -ge 40 ]; then
                        result=1
                        echo $(date "+%Y-%m-%d %H:%M") $ip $count >> $result_file
                fi
        done
        sort -u $result_file >> tmpfile && mv tmpfile $result_file
        rm -rf $text $id_list $ip_count_file
}

function actions {
        grep -o '(.*)' $Log >> $text
        main_action
        grep -o '(.*)' $past_Log >> $text
        main_action
        zabbix $result
}

function zabbix {
    zabbix_sender -z $ZABBIX_SERVER -s $ZABBIX_HOST -k $ZABBIX_KEY -o $1 &> /dev/null
}

function main {
    echo INFO: Start script
    variables
    functions.lockfile create
    actions
    cleanup
}

main 2>&1|functions.logging
