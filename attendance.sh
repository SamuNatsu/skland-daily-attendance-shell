#!/bin/bash

# Constants
SKLAND_AUTH_URL="https://as.hypergryph.com/user/oauth2/v2/grant"
CRED_CODE_URL="https://zonai.skland.com/api/v1/user/auth/generate_cred_by_code"
BINDING_URL="https://zonai.skland.com/api/v1/game/player/binding"
SKLAND_CHECKIN_URL="https://zonai.skland.com/api/v1/score/checkin"
SKLAND_ATTENDANCE_URL="https://zonai.skland.com/api/v1/game/attendance"
SKLAND_BOARD_IDS="1,2,3,4,100"
SKLAND_BOARD_NAMES='{"1":"明日方舟","2":"来自星辰","3":"明日方舟: 终末地","4":"泡姆泡姆","100":"纳斯特港"}'

## Generate signature
# $1 -> token
# $2 -> pathname
# $3 -> searchParams
# $4 -> data
generate_signature() {
  # Sign header
  local PLATFORM="1"
  local TIMESTAMP=$(($(date +%s) - 2))
  local DID=""
  local VNAME="1.5.1"

  # Signing
  local STR="$2$3$4$TIMESTAMP{\"platform\":\"$PLATFORM\",\"timestamp\":\"$TIMESTAMP\",\"dId\":\"$DID\",\"vName\":\"$VNAME\"}"
  local HMAC=$(echo -n $STR | openssl dgst -sha256 -hmac $1 | awk '{print $2}')
  local SIGN=$(echo -n $HMAC | md5sum | awk '{print $1}')

  # Return signature and headers
  echo $SIGN
  echo $PLATFORM
  echo $TIMESTAMP
  echo $DID
  echo $VNAME
}

## Get privacy name
# $1 -> name
get_privacy_name() {
  local NAME=$1
  local FIRST=${NAME:0:1}
  local LAST=${NAME: -1}
  echo "$FIRST****$LAST"
}

## Hypergryph auth
# $1 -> token
hypergryph_auth() {
  # Query API
  local RESPONSE=$(
    curl \
    -s \
    -H "User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0" \
    -H "Accept-Encoding: gzip" \
    -H "Connection: close" \
    -H "Content-Type: application/json" \
    -d "{\"appCode\":\"4ca99fa6b56cc2ba\",\"token\":\"$1\",\"type\":0}" \
    $SKLAND_AUTH_URL
  )
  if [ $? -ne 0 ]; then
    echo "[失败] 无法访问 OAuth API" >&2
    exit 1
  fi

  # Check response
  if [[ $(jq 'has("data")' <<< $RESPONSE) == "false" ]]; then
    local MSG=$(jq -r ".msg" <<< $RESPONSE)
    echo "[失败] 无法登陆: $MSG" >&2
    exit 1
  fi

  # Return code
  echo $(jq -r ".data.code" <<< $RESPONSE)
}

## Skland sign in
# $1 -> code
skland_sign_in() {
  # Query API
  local RESPONSE=$(
    curl \
      -s \
      -H "User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0" \
      -H "Accept-Encoding: gzip" \
      -H "Connection: close" \
      -H "Content-Type: application/json; charset=utf-8" \
      -d "{\"code\":\"$1\",\"kind\":1}" \
      $CRED_CODE_URL
  )
  if [ $? -ne 0 ]; then
    echo "[失败] 无法访问森空岛登陆 API" >&2
    exit 1
  fi

  # Check response
  if [[ $(jq ".code != 0" <<< $RESPONSE) == "true" ]]; then
    local MSG=$(jq -r ".message" <<< $RESPONSE)
    echo "[失败] 无法登陆森空岛: $MSG" >&2
    exit 1
  fi

  # Return response
  echo $(jq ".data" <<< $RESPONSE)
}

## Skland get binding
# $1 -> cred
# $2 -> token
skland_get_binding() {
  # Get signature and header
  local SIGN=$(generate_signature $2 "/api/v1/game/player/binding" "" "")
  local PLATFORM=$(awk "NR==2" <<< $SIGN)
  local TIMESTAMP=$(awk "NR==3" <<< $SIGN)
  local DID=$(awk "NR==4" <<< $SIGN)
  local VNAME=$(awk "NR==5" <<< $SIGN)
  SIGN=$(awk "NR==1" <<< $SIGN)

  # Query API
  local RESPONSE=$(
    curl \
    -s \
    -H "Platform: $PLATFORM" \
    -H "Timestamp: $TIMESTAMP" \
    -H "Did: $DID" \
    -H "Vname: $VNAME" \
    -H "Sign: $SIGN" \
    -H "Cred: $1" \
    $BINDING_URL
  )
  if [ $? -ne 0 ]; then
    echo "[错误] 无法访问森空岛角色绑定 API" >&2
    exit 1
  fi

  # Check response
  if [[ $(jq ".code != 0" <<< $RESPONSE) == "true" ]]; then
    local MSG=$(jq -r ".message" <<< $RESPONSE)
    echo "[错误] 无法获取角色绑定: $MSG" >&2
    exit 1
  fi

  # Return response
  echo $(jq ".data.list" <<< $RESPONSE)
}

## Skland check in
# $1 -> cred
# $2 -> token
# $3 -> board
skland_check_in() {
  # Get signature and header
  local SIGN=$(generate_signature $2 "/api/v1/score/checkin" "" "{\"gameId\":\"$3\"}")
  local PLATFORM=$(awk "NR==2" <<< $SIGN)
  local TIMESTAMP=$(awk "NR==3" <<< $SIGN)
  local DID=$(awk "NR==4" <<< $SIGN)
  local VNAME=$(awk "NR==5" <<< $SIGN)
  SIGN=$(awk "NR==1" <<< $SIGN)

  # Query API
  local RESPONSE=$(
    curl \
    -s \
    -H "Platform: $PLATFORM" \
    -H "Timestamp: $TIMESTAMP" \
    -H "Did: $DID" \
    -H "Vname: $VNAME" \
    -H "Sign: $SIGN" \
    -H "Cred: $1" \
    -H "Content-Type: application/json; chaset=utf-8" \
    -H "User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0" \
    -H "Accept-Encoding: gzip" \
    -H "Connection: close" \
    -d "{\"gameId\":\"$3\"}" \
    $SKLAND_CHECKIN_URL
  )
  if [ $? -ne 0 ]; then
    echo "[错误] 无法访问森空岛检票 API" >&2
    exit 1
  fi

  # Check response
  local BOARD=$(jq -r ".[\"$3\"]" <<< $SKLAND_BOARD_NAMES)
  if [[ $(jq ".code == 0" <<< $RESPONSE) == "true" ]]; then
    echo "版面 [$BOARD] 检票成功"
  else
    local MSG=$(jq -r ".message" <<< $RESPONSE)
    echo "版面 [$BOARD] 检票失败: $MSG" >&2
  fi
}

## Arknights daily
# $1 -> cred
# $2 -> token
# $3 -> uid
# $4 -> cmid
# $5 -> channel name
# %6 -> privacy name
skland_attendance() {
  # Get signature and header
  local SIGN=$(generate_signature $2 "/api/v1/game/attendance" "" "{\"uid\":\"$3\",\"gameId\":\"$4\"}")
  local PLATFORM=$(awk "NR==2" <<< $SIGN)
  local TIMESTAMP=$(awk "NR==3" <<< $SIGN)
  local DID=$(awk "NR==4" <<< $SIGN)
  local VNAME=$(awk "NR==5" <<< $SIGN)
  SIGN=$(awk "NR==1" <<< $SIGN)

  # Query API
  local RESPONSE=$(
    curl \
    -s \
    -H "Platform: $PLATFORM" \
    -H "Timestamp: $TIMESTAMP" \
    -H "Did: $DID" \
    -H "Vname: $VNAME" \
    -H "Sign: $SIGN" \
    -H "Cred: $1" \
    -H "Content-Type: application/json; chaset=utf-8" \
    -H "User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0" \
    -H "Accept-Encoding: gzip" \
    -H "Connection: close" \
    -d "{\"uid\":\"$3\",\"gameId\":\"$4\"}" \
    $SKLAND_ATTENDANCE_URL
  )
  if [ $? -ne 0 ]; then
    echo "[错误] 无法访问森空岛签到 API" >&2
    exit 1
  fi

  # Check response
  if [[ $(jq ".code == 0" <<< $RESPONSE) == "true" ]]; then
    local AWARDS=$(jq ".data.awards" <<< $RESPONSE)
    echo $5"角色 $6 签到成功，获得了：$AWARDS"
  else
    local MSG=$(jq -r ".message" <<< $RESPONSE)
    echo $5"角色 $6 签到失败：$MSG" >&2
  fi
}

## Do attendance
# $1 -> token
do_attendance() {
  # Get auth code
  local CODE=$(hypergryph_auth $1)
  echo "OAuth 登陆成功"

  # Get cred and token
  local TMP=$(skland_sign_in $CODE)
  local CRED=$(jq -r ".cred" <<< $TMP)
  local TOKEN=$(jq -r ".token" <<< $TMP)
  echo "森空岛登陆成功"

  # Get binding list
  local LIST=$(skland_get_binding $CRED $TOKEN)
  echo "角色绑定获取成功"

  # Skland check in
  local IDS=""
  IFS="," read -ra IDS <<< $SKLAND_BOARD_IDS
  for ID in ${IDS[@]}; do
    skland_check_in $CRED $TOKEN $ID &
  done
  wait

  # Arknights attendance
  LIST=$(jq "map(.bindingList) | flatten(1)" <<< $LIST)
  local LEN=$(jq "length" <<< $LIST)
  local I=0
  while [ $I -lt $LEN ]; do
    local AUID=$(jq -r ".[$I].uid" <<< $LIST)
    local CMID=$(jq -r ".[$I].channelMasterId" <<< $LIST)
    local CHANNEL=$(jq -r ".[$I].channelName" <<< $LIST)
    local NAME=$(jq -r ".[$I].nickName" <<< $LIST)
    skland_attendance $CRED $TOKEN $AUID $CMID $CHANNEL $(get_privacy_name $NAME) &
    I=$(($I + 1))
  done
  wait
}

### Main entry

# Parse environment
if [[ -z "$SKLAND_TOKEN" ]]; then
  echo '[错误] 环境变量 "SKLAND_TOKEN" 未定义' >&2
  exit 1
fi
IFS="," read -ra ACCOUNTS <<< $SKLAND_TOKEN

# Execute tasks
I=1
for ACCOUNT in ${ACCOUNTS[@]}; do
  echo "正在处理账号 #$I"
  do_attendance $ACCOUNT
  I=$(($I + 1))
done
