#!/bin/bash
#

# Make a script to check the date of nginx septic tanks on the fronts
# ADM-4056
# YuryS

zabbix_conf_file=/etc/zabbix/zabbix_agentd.conf

limit=10
#limit of days before expire
sent=0
pathlist=$(find /etc/nginx/* -name 'fullchain.pem' -o -name '*.crt' | grep -v staff_certs | grep -v clientcrt )
#проверка на существование файлов сертиков
if [[ -z "${pathlist// }" ]];then
	sent=1
	zabbix_sender -c $zabbix_conf_file -p 10051 -k crt.check -o $sent > /dev/null
else
	for path in $pathlist; do
		CURRENTDATE=`LANG=en_EN TZ=GMT date +"%b %d %R:%S %Y %Z"`
		NOTAFTER=`openssl x509 -enddate -noout -in $path | sed 's/^.*=// '`
		DIFFDAYS=`echo $(( ($(date -d "$NOTAFTER" +"%s")-$(date -d "$CURRENTDATE" +"%s"))/86400 ))`
		if [[ $DIFFDAYS -le $limit ]]; then
			sent="${path}_expires_in_${DIFFDAYS}"
			zabbix_sender -c $zabbix_conf_file -p 10051 -k crt.check -o $sent > /dev/null
		fi
	done
	if [[ $sent == 0 ]];then
		zabbix_sender -c $zabbix_conf_file -p 10051 -k crt.check -o $sent > /dev/null
	fi
fi
