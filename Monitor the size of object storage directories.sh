#!/bin/bash
#

# Monitor the size of object storage directories
# YuryS

LOG=/tmp/script.log

rm $LOG

s3list=$(sudo s3cmd ls s3:// | awk '{print $3}' | sed 's/^.*s3:\/\///')

for s3dir in $s3list ; do
  sudo s3cmd ls s3://$s3dir/ | grep "DIR" | awk -F/ '{print $(NF-1)}'|
  while read s3folder; do
    zabbix_sender -z zabbix-proxy.clouds -s Sbercloud -k sber.s3.bucket.discovery -o ["{\"{#BUCKETNAME}\":\"$s3dir\",\"{#SUBFOLDERNAME}\":\"$s3folder\"}"] > /dev/null
    s3foldersize=$(sudo s3cmd du s3://$s3dir/$s3folder | awk '{print $1}')
    zabbix_sender -z zabbix-proxy.clouds -s Sbercloud -k "s3.bucket.subfolder.size.summary[$s3dir,$s3folder]" -o $s3foldersize > /dev/null
  done
  zabbix_sender -z zabbix-proxy.clouds -s Sbercloud -k sber.a3.bucket.discovery -o ["\"{#BUCKETNAME}\":\"$s3dir\""] > /dev/null
  bucketSize=$(sudo s3cmd du s3://$s3dir/ | awk '{print $1}')
  zabbix_sender -z zabbix-proxy.clouds -s Sbercloud -k "s3.bucket.size.summary[$s3dir]" -o $bucketSize > /dev/null
done
