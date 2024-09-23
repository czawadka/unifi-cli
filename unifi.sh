#!/bin/bash -x

UNIFI_USR=$1
UNIFI_PWD=$2

UNIFI_BASE_URL=$3
FIREWALLRULE_ID=$4
CMD=$5

URL_LOGIN="${UNIFI_BASE_URL}/api/auth/login"
URL_FIREWALLRULE="${UNIFI_BASE_URL}/proxy/network/api/s/default/group/firewallrule"
URL_SELF="${UNIFI_BASE_URL}/api/users/self"

CURL=/usr/bin/curl
CURL_OUT_FILE="/tmp/unifi-out-${UNIFI_USR}.txt"
UNIFI_COOKIES="/tmp/unifi-cookies-${UNIFI_USR}.txt"


_is_logged_in() {
  $CURL \
    "${URL_SELF}" \
    -X GET \
    -b "${UNIFI_COOKIES}" \
    -S -s -k \
    -o /dev/null \
    -w "%{http_code}"
}

login_if_needed() {
  # if there is cookie file and is user logged in
  if [ -f ${UNIFI_COOKIES} ] && [[ $(_is_logged_in) == 200 ]] ; then
    return 0
  fi

  DATA="{\"username\": \"${UNIFI_USR}\", \"password\": \"${UNIFI_PWD}\"}"
  resp_code=$($CURL --fail-early \
    "${URL_LOGIN}" \
    -X POST \
    --data "${DATA}" \
    -H 'content-type: application/json' \
    -H 'dnt: 1' \
    -c "${UNIFI_COOKIES}" \
    -S -s -k \
    -o "${CURL_OUT_FILE}" \
    -w "%{http_code}")

  if [[ ${resp_code} -ne 200 ]]; then
    echo "Response ${resp_code}:"
    cat "${CURL_OUT_FILE}"
    return 1
  fi
}

firewallrule_is_enabled() {
  FIREWALLRULE_ID=$1
  $CURL \
    "${URL_FIREWALLRULE}/${FIREWALLRULE_ID}" \
    -X GET \
    -b "${UNIFI_COOKIES}" \
    -S -s -k
}

firewallrule_enable() {
  FIREWALLRULE_ID=$1
  enabled=$2
  # {"id":["64312f56895b8a044cd0ad49"],"data":{"enabled":false}}
#  DATA="{\"enabled\": ${enabled}}"
#  DATA="{\"id\":[\"${FIREWALLRULE_ID}\"], \"data\":{\"enabled\": ${enabled}}}"
  DATA='{"id":["64312f56895b8a044cd0ad49"],"data":{"enabled":false}}'
  resp_code=$($CURL \
    "${URL_FIREWALLRULE}" \
    -X PUT \
    -H 'content-type: application/json' \
    --data "${DATA}" \
    -b "${UNIFI_COOKIES}" \
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
  status)
    firewallrule_is_enabled "$FIREWALLRULE_ID" || exit  2
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
