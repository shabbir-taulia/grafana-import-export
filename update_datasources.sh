#!/bin/bash
: "${1:?First input GRAFANA API KEY required}"
: "${2:?Second input ENVIRONMENT required}"

KEY=$1
ENVIRONMENT=$2

grafana_datasources=(`curl -s -k 'https://grafana.'${ENVIRONMENT}'.taulia.com/api/datasources' -H "Authorization: Bearer ${KEY}" | jq -r ".[] | .url" | grep -v "prometheus" | sed 's/\-[^-]*$//' | sort | uniq -u`)
oc_datasources=(`oc get pods | grep 'db-2' | awk '{print $1}' | sed 's/\-[^-]*$//'`)

datasources=(`echo ${oc_datasources[@]} ${grafana_datasources[@]} | tr ' ' '\n' | sort | uniq -u`)
echo "${datasources[@]}"
for i in "${datasources[@]}"; do
	name=$(echo "$i" | cut -d '-' -f 2- | rev | cut -d '-' -f 2- | rev)
	
	if [[ "$name" == 'xmlrpc-translator' ]]; then
		db_name='xmlrpc-translate'
    elif [[ "$name" == 'outbound-tracker' ]]; then
    	db_name='outboundtracker'
    elif [[ "$name" == 'supplier-information-management' ]]; then
    	db_name='sim'
    elif [[ "$i" == monolith* ]]; then
    	db_name='monolith'
    elif [[ "$i" == app* ]]; then
    	db_name='trusted-component'
    else
    	db_name="$name"
    fi
	
	db_name=$(echo "$db_name" | sed 's/\-/_/g')

    check_user=`oc exec -c mysql $i-2 -- mysql -e "SELECT User FROM mysql.user;" | grep "grafanaReader"`
    if [ ! $check_user ]; then 
    	echo "grafanaReader not found, will create user and grant select priviledges"
    	oc exec -c mysql $i-2 -- mysql -e "create user 'grafanaReader' identified by '0uSvz0pzTFyy1r4';grant select on taulia_$db_name.* to 'grafanaReader';"
    fi
	
	echo '{
 		 "name":"'$db_name'",
 	 	 "type":"mysql",
 	 	 "url":"'$i'-read",
	 	 "database":"taulia_'$db_name'",
  	 	 "user":"grafanaReader",
  	 	 "password":"0uSvz0pzTFyy1r4",
  	 	 "access":"proxy"
		}'

	
	curl -s -k 'https://grafana.'${ENVIRONMENT}'.taulia.com/api/datasources' -X POST \
	-H "Authorization: Bearer ${KEY}" \
	-H "Content-Type: application/json" \
	--data-binary '{
 		 "name":"'$db_name'",
 	 	 "type":"mysql",
 	 	 "url":"'$i'-read",
	 	 "database":"taulia_'$db_name'",
  	 	 "user":"grafanaReader",
  	 	 "password":"0uSvz0pzTFyy1r4",
  	 	 "access":"proxy"
		}'
done

#to-do add mysql commands to create user and grant permissions
#to-do add slack alert
#to-do make exception for old dbname.service name db url's

