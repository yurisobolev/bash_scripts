#!/bin/bash

# Script for ssh private key monitoring
# ADM-3544
# YuryS
# 27.03.2023

source /usr/local/sbin/functions
trap cleanup EXIT

function variables {
    hostname=$(hostname)
    result=0
    whitelist_file=/root/adm-3544_whitelist.conf    
    keylist_file=/tmp/adm-3544_keylist.conf
    ZABBIX_SERVER="zabbix-proxy.clouds"    
    ZABBIX_HOST=$hostname
    ZABBIX_KEY="ssh.key.check"
}

function cleanup {
    functions.lockfile delete
    rm -f $keylist_file
}

function actions {
    home_list=$(echo /home/*/)
    for user_list in $home_list; do        
        ssh_list="${user_list}.ssh"
        key_list=$(ls $ssh_list 2> /dev/null)        
        for key in $key_list; do
            keypath="${ssh_list}/${key}"            
            full_path="$(hostname):${keypath}"            
            echo $full_path >> $keylist_file
        done
    done
    
    #whitelist для того чтобы добавить ключ в whitelist нужно записать путь до ключа в файл whitelist, пример записи hostname//home/.ssh/id_rsa
    grep -v -f $whitelist_file $keylist_file >> tmpfile && mv tmpfile $keylist_file
    cut -d ":" -f 2- $keylist_file >> tmpfile && mv tmpfile $keylist_file 
    keylist=$(cat $keylist_file)
    for key in $keylist; do    
        grep "PRIVATE" $key &> /dev/null
        if [ $? -eq 0 ]; then        
            echo "Detected Private Key $key"
            ssh-keygen -y -P "" -f $key &> /dev/null        
            if [ $? -eq 0 ]; then
                echo "${key} WITHOUT password "            
                result="${key}_WITHOUT_password"
                zabbix $result        
            else
                echo "${key} WITH password "        
            fi
        fi
    done
    if [ $result -eq 0 ] &> /dev/null; then            
        zabbix $result
    fi
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