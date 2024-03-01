#!/bin/bash

# Script for nmap scanning
# YuryS
# 02.10.2023

function variables {
    Log=/tmp/script.log
    server_list_file=/usr/local/sbin/script_server_list.conf
    ZABBIX_SERVER="zabbix-proxy.clouds"
    ZABBIX_HOST=$(hostname)
    ZABBIX_KEY1="port_scan"
    ZABBIX_KEY2="Open_ports_counts"
    Port_count=/tmp/port_count.conf
    Log_with_ports=/tmp/log_with_ports.txt
    Sort_log=/tmp/sort_log.txt
    result_file=/tmp/result_file.txt
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

function action {
    rm -rf $Log $Port_count $Log_with_ports $Sort_log $result_file
    echo $(date "+%Y-%m-%d %H:%M") >> $Log
    echo "Scan log for nmap scanning" >> $Log
    echo "                      " >> $Log
    server_list=$(cat $server_list_file)
    for ip in $server_list ; do
            scan_result=$(nmap $ip)
            checkReturnCode $?  
            echo "$scan_result" | sed -e '1d;3d;4d;$d' >> $Log
    done
    echo "Script ran at $(hostname)" >> $Port_count
    echo "List of ports and their number" >> $Port_count
    grep -oE '([0-9]+/tcp)' "$Log" | sort | uniq -c >> "$Port_count"
    echo "_____________________________________________" >> $Port_count
    cat $Port_count $Log > $Log_with_ports
    mv $Log_with_ports $Log
    echo -e 'Report' | mail -aFrom:`hostname -s`@mail.ru -s 'Open ports check - Scan Result' sa@mail.ru -a "Content-Disposition: attachment; filename=adm-4192.log" < $Log
    checkReturnCode $?
    found_flag=0
    while IFS= read -r line; do
            if [[ $line == *"_"* ]]; then
                    found_flag=1
                    break
            fi
            echo "$line" >> $Sort_log
    done < "$Log"
    cat "$Sort_log" | tr -d '\n' > "$result_file"
    result=$(cat $result_file)
    zabbix_sender -z $ZABBIX_SERVER -s $ZABBIX_HOST -k $ZABBIX_KEY2 -o "$result" &> /dev/null 
    zabbix 0
}

function zabbix {
    zabbix_sender -z $ZABBIX_SERVER -s $ZABBIX_HOST -k $ZABBIX_KEY1 -o $1 &> /dev/null
}

function main {
    echo INFO: Start script
    variables
    functions.lockfile create
    action
    cleanup
}

main 2>&1|functions.logging
