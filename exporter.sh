#!/usr/bin/env bash

: "${1:?First input ORGANIZATION required}"
: "${2:?Second input GRAFANA API KEY required}"
: "${3:?Third input ENVIRONMENT required}"


ORG=$1
KEY=$2
ENVIRONMENT=$3
DIR="./$ENVIRONMENT/$ORG"

fetch_fields() {
    curl -sSL -f -k -H "Authorization: Bearer ${1}" "https://grafana.${ENVIRONMENT}.taulia.com/api/${2}" | jq -r "if type==\"array\" then .[] else . end| .${3}"
}

mkdir -p "$DIR/dashboards"
mkdir -p "$DIR/datasources"
mkdir -p "$DIR/alert-notifications"

echo "---------------------"
echo "Importing dashboards"
for dash in $(fetch_fields $KEY 'search?query=&' 'uri'); do
    DB=$(echo ${dash}|sed 's,db/,,g').json
    echo "importing $DB"
    curl -s -f -k -H "Authorization: Bearer ${KEY}" "https://grafana.${ENVIRONMENT}.taulia.com/api/dashboards/${dash}" | jq 'del(.dashboard.version,.meta.created,.meta.createdBy,.meta.updated,.meta.updatedBy,.meta.expires,.meta.version,.dashboard.id)' | jq '. + {overwrite:true}' > "$DIR/dashboards/$DB"
done

echo "---------------------"
echo "importing datasources"
for id in $(fetch_fields $KEY 'datasources' 'id'); do
    DS=$(echo $(fetch_fields $KEY "datasources/${id}" 'name')|sed 's/ /-/g').json
    echo "importing $DS"
    curl -s -f -k -H "Authorization: Bearer ${KEY}" "https://grafana.${ENVIRONMENT}.taulia.com/api/datasources/${id}" | jq '' > "$DIR/datasources/$DS"
done

echo "---------------------"
echo "importing alerts"
for id in $(fetch_fields $KEY 'alert-notifications' 'id'); do
    FILENAME=$(echo $(fetch_fields $KEY "alert-notifications/${id}" 'name')|sed 's/ /-/g').json
    echo $FILENAME
    curl -s -f -k -H "Authorization: Bearer ${KEY}" "https://grafana.${ENVIRONMENT}.taulia.com/api/alert-notifications/${id}" | jq 'del(.created,.updated)' > "$DIR/alert-notifications/$FILENAME"
done

