#!/usr/bin/env ksh
PATH=/usr/local/bin:${PATH}
IFS_DEFAULT="${IFS}"

#################################################################################

#################################################################################
#
#  Variable Definition
# ---------------------
#
APP_NAME=$(basename $0)
APP_DIR=$(dirname $0)
APP_VER="1.0.1"
APP_WEB="http://www.sergiotocalini.com.ar/"
TIMESTAMP=`date '+%s'`

SPLUNK_URL="http://localhost:8200"
CACHE_DIR="${APP_DIR}/tmp"
CACHE_TTL=1                                      # IN MINUTES
#
#################################################################################

#################################################################################
#
#  Load Oracle Environment
# -------------------------
#
[ -f ${APP_DIR}/${APP_NAME%.*}.conf ] && . ${APP_DIR}/${APP_NAME%.*}.conf

#
#################################################################################

#################################################################################
#
#  Function Definition
# ---------------------
#
usage() {
    echo "Usage: ${APP_NAME%.*} [Options]"
    echo ""
    echo "Options:"
    echo "  -a            Arguments to the section."
    echo "  -h            Displays this help message."
    echo "  -j            Jsonify output."
    echo "  -s            Select the section (service, account, etc. )."
    echo "  -v            Show the script version."
    echo ""
    echo "Please send any bug reports to sergiotocalini@gmail.com"
    exit 1
}

version() {
    echo "${APP_NAME%.*} ${APP_VER}"
    exit 1
}

zabbix_not_support() {
    echo "ZBX_NOTSUPPORTED"
    exit 1
}

refresh_cache() {
    params=( "${@}" )
    ttl="${CACHE_TTL}"

    name=`printf '%s/' "${params[@]}" 2>/dev/null`
    [[ -z ${name} ]] && name="services/server/info/"
    endpoint="${name%?}?output_mode=json"
    
    filename="${CACHE_DIR}/${name%?}.json"
    basename=`dirname ${filename}`
    [[ -d "${basename}" ]] || mkdir -p "${basename}"
    [[ -f "${filename}" ]] || touch -d "$(( ${ttl}+1 )) minutes ago" "${filename}"

    if [[ $(( `stat -c '%Y' "${filename}" 2>/dev/null`+60*${ttl} )) -le ${TIMESTAMP} ]]; then
	curl -sk -u "${SPLUNK_USER}:${SPLUNK_PASS}" "${SPLUNK_URL}/${endpoint}" 2>/dev/null | \
	     jq . 2>/dev/null > "${filename}"
    fi
    echo "${filename}"
}


service() {
    params=( ${@} )
    pattern='^(([a-z]{3,5})://)?((([^:\/]+)(:([^@\/]*))?@)?([^:\/?]+)(:([0-9]+))?)(\/[^?]*)?(\?[^#]*)?(#.*)?$'
    [[ "${SPLUNK_URL}" =~ $pattern ]] || return 1
    regex_match=( "${.sh.match[@]:-${BASH_REMATCH[@]:-${match[@]}}}" )
    
    if [[ ${params[0]} =~ (uptime|listen) ]]; then
	pid=`sudo lsof -Pi :${regex_match[6]:-${regex_match[2]}} -sTCP:LISTEN -t 2>/dev/null`
	rcode="${?}"
	if [[ -n ${pid} ]]; then
	    if [[ ${params[0]} == 'uptime' ]]; then
		res=`sudo ps -p ${pid} -o etimes -h 2>/dev/null | awk '{$1=$1};1'`
	    elif [[ ${params[0]} == 'listen' ]]; then
		[[ ${rcode} == 0 && -n ${pid} ]] && res=1
	    fi
	fi
    elif [[ ${params[0]} == 'version' ]]; then
	res=$( server 'info' 'entry[0].content.version' )
    fi
    echo "${res:-0}"
    return 0
}


server() {
    params=( ${@} )
    if [[ ${params[0]:-info} =~ (info|introspection|status) ]]; then
	len=${#params[@]}
	cache=$( refresh_cache "services" "server" "${params[@]:0:${len}-1}" )
	if [[ ${?} == 0 ]]; then
	    res=`jq -r ".${params[-1]}" ${cache} 2>/dev/null`
	fi
    fi
    echo "${res//null}"
    return 0    
}


data() {
    params=( ${@} )
    if [[ ${params[0]:-indexes} =~ (indexes|indexes-extended|index-volumes) ]]; then
	len=${#params[@]}
	cache=$( refresh_cache "services" "data" "${params[@]:0:${len}-1}" )
	if [[ ${?} == 0 ]]; then
	    if [[ ${params[0]} == "indexes" && ${params[-1]} =~ (list|LIST|all|ALL) ]]; then
		res=`jq -r ".entry[] | [.name, .author, .content.disabled, .content.isReady] | join(\"|\")" ${cache} 2>/dev/null`
	    else
		res=`jq -r ".${params[-1]}" ${cache} 2>/dev/null`
	    fi
	fi
    fi
    echo "${res//null}"
    return 0
}

#
#################################################################################

#################################################################################
while getopts "s::a:sj:uphvt:" OPTION; do
    case ${OPTION} in
	h)
	    usage
	    ;;
	s)
	    SECTION="${OPTARG}"
	    ;;
        j)
            JSON=1
            IFS=":" JSON_ATTR=( ${OPTARG} )
	    IFS="${IFS_DEFAULT}"
            ;;
	a)
	    param="${OPTARG//p=}"
	    [[ -n ${param} ]] && ARGS[${#ARGS[*]}]="${param}"
	    ;;
	v)
	    version
	    ;;
        \?)
            exit 1
            ;;
    esac
done

if [[ "${SECTION}" == "service" ]]; then
    rval=$( service "${ARGS[@]}" )  
elif [[ "${SECTION}" == "server" ]]; then
    rval=$( server "${ARGS[@]}" )
elif [[ "${SECTION}" == "data" ]]; then
    rval=$( data "${ARGS[@]}" )
else
    zabbix_not_support
fi
rcode="${?}"

if [[ ${JSON} -eq 1 ]]; then
    echo '{'
    echo '   "data":['
    count=1
    while read line; do
	if [[ ${line} != '' ]]; then
            IFS="|" values=(${line})
            output='{ '
            for val_index in ${!values[*]}; do
		output+='"'{#${JSON_ATTR[${val_index}]:-${val_index}}}'":"'${values[${val_index}]}'"'
		if (( ${val_index}+1 < ${#values[*]} )); then
                    output="${output}, "
		fi
            done
            output+=' }'
	    if (( ${count} < `echo ${rval}|wc -l` )); then
		output="${output},"
            fi
            echo "      ${output}"
	fi
        let "count=count+1"
    done < <(echo "${rval}")
    echo '   ]'
    echo '}'
else
    echo "${rval:-0}"
fi

exit ${rcode}
