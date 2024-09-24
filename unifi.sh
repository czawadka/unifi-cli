#!/bin/bash

UNIFI_USR=$1
UNIFI_PWD=$2

UNIFI_BASE_URL=$3
FIREWALLRULE_ID=$4
CMD=$5

URL_LOGIN="${UNIFI_BASE_URL}/api/auth/login"
URL_FIREWALLRULE="${UNIFI_BASE_URL}/proxy/network/api/s/default/rest/firewallrule"
URL_SELF="${UNIFI_BASE_URL}/api/users/self"

CURL=/usr/bin/curl
MD5="$(/usr/bin/which md5sum || echo "md5")"

UNIFI_SESSION_TIMEOUT_SECS=900 # 15min
UNIFI_SESSION_ID="$(echo -n "${UNIFI_BASE_URL}:${UNIFI_USR}" | "$MD5" | sed 's/[ -]//g')"
CURL_OUT_FILE="/tmp/unifi-${UNIFI_SESSION_ID}-out.txt"
CURL_HEADERS_FILE="/tmp/unifi-${UNIFI_SESSION_ID}-headers.txt"
CURL_XSRF_HEADERS_FILE="/tmp/unifi-${UNIFI_SESSION_ID}-xsrf-headers.txt"
CURL_COOKIE_FILE="/tmp/unifi-${UNIFI_SESSION_ID}-cookies.txt"


_is_logged_in() {
  $CURL \
    "${URL_SELF}" \
    -X GET \
    -b "${CURL_COOKIE_FILE}" \
    -S -s -k \
    -o /dev/null \
    -w "%{http_code}"
}

login_if_needed() {
  # if there is cookie file and is user logged in
  if [ -f "${CURL_COOKIE_FILE}" ] ; then
    COOKIE_FILE_SECS=$(($(date '+%s') - $(date -r "${CURL_COOKIE_FILE}" '+%s')))
    if [ "${COOKIE_FILE_SECS}" -lt "${UNIFI_SESSION_TIMEOUT_SECS}" ] \
        && [[ $(_is_logged_in) == 200 ]] ; then
      return 0
    fi
  fi

  DATA="{\"username\": \"${UNIFI_USR}\", \"password\": \"${UNIFI_PWD}\"}"
  resp_code=$($CURL --fail-early \
    "${URL_LOGIN}" \
    -X POST \
    --data "${DATA}" \
    -H 'content-type: application/json' \
    -H 'dnt: 1' \
    -c "${CURL_COOKIE_FILE}" \
    -S -s -k \
    -D "${CURL_HEADERS_FILE}" \
    -o "${CURL_OUT_FILE}" \
    -w "%{http_code}")

  if [[ ${resp_code} -ne 200 ]]; then
    echo "Response ${resp_code}:"
    cat "${CURL_OUT_FILE}"
    return 1
  fi

  grep -i '^x-csrf-token:' "${CURL_HEADERS_FILE}" > "${CURL_XSRF_HEADERS_FILE}"
}

firewallrule_get() {
  FIREWALLRULE_ID=$1
  $CURL \
    "${URL_FIREWALLRULE}/${FIREWALLRULE_ID}" \
    -X GET \
    -b "${CURL_COOKIE_FILE}" \
    -S -s -k
}

firewallrule_enable() {
  FIREWALLRULE_ID=$1
  enabled=$2
  DATA="{\"enabled\": ${enabled}}"
  resp_code=$($CURL \
    "${URL_FIREWALLRULE}/${FIREWALLRULE_ID}" \
    -X PUT \
    -H "@${CURL_XSRF_HEADERS_FILE}" \
    -H 'content-type: application/json' \
    --data "${DATA}" \
    -b "${CURL_COOKIE_FILE}" \
    -S -s -k \
    -o "${CURL_OUT_FILE}" \
    -w "%{http_code}")

  if [[ ${resp_code} -ne 200 ]]; then
    echo "Response ${resp_code}:"
    cat "${CURL_OUT_FILE}"
    return 1
  fi
}

login_if_needed || exit 1

case $CMD in
  get)
    firewallrule_get "$FIREWALLRULE_ID" || exit  2
    ;;
  on)
    firewallrule_enable "$FIREWALLRULE_ID" true || exit  3
    ;;
  off)
    firewallrule_enable "$FIREWALLRULE_ID" false || exit  4
    ;;
  *)
    echo "unknown command $CMD"
    exit 200
    ;;
esac
