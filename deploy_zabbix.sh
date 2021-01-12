#!/usr/bin/env ksh
SOURCE_DIR=$(dirname $0)
ZABBIX_DIR=/etc/zabbix
PREFIX_DIR="${ZABBIX_DIR}/scripts/agentd/spluix"

SPLUNK_URL="${1:-http://localhost:8089}"
SPLUNK_USER="${2:-monitor}"
SPLUNK_PASS="${3:-xxxxxxx}"
CACHE_DIR="${4:-${PREFIX_DIR}/tmp}"
CACHE_TTL="${5:-5}"

mkdir -p "${PREFIX_DIR}"

SCRIPT_CONFIG="${PREFIX_DIR}/spluix.conf"
if [[ -f "${SCRIPT_CONFIG}" ]]; then
    SCRIPT_CONFIG="${SCRIPT_CONFIG}.new"
fi

cp -rpv "${SOURCE_DIR}/spluix/spluix.sh"             "${PREFIX_DIR}/"
cp -rpv "${SOURCE_DIR}/spluix/spluix.conf.example"   "${SCRIPT_CONFIG}"
cp -rpv "${SOURCE_DIR}/spluix/zabbix_agentd.conf"    "${ZABBIX_DIR}/zabbix_agentd.conf.d/spluix.conf"

regex_array[0]="s|SPLUIX_URL=.*|SPLUIX_URL=\"${SPLUIX_URL}\"|g"
regex_array[1]="s|SPLUIX_USER=.*|SPLUIX_USER=\"${SPLUIX_USER}\"|g"
regex_array[2]="s|SPLUIX_PASS=.*|SPLUIX_PASS=\"${SPLUIX_PASS}\"|g"
regex_array[3]="s|CACHE_DIR=.*|CACHE_DIR=\"${CACHE_DIR}\"|g"
regex_array[4]="s|CACHE_TTL=.*|CACHE_TTL=\"${CACHE_TTL}\"|g"
for index in ${!regex_array[*]}; do
    sed -i "${regex_array[${index}]}" ${SCRIPT_CONFIG}
done
