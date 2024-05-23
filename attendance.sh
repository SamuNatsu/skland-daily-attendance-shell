#!/bin/bash

#------------------------------------------------------------------------------
# 常量
#------------------------------------------------------------------------------

HYPERGRYPH_OAUTH_URL='https://as.hypergryph.com/user/oauth2/v2/grant'
SKLAND_AUTH_URL='https://zonai.skland.com/api/v1/user/auth/generate_cred_by_code'
SKLAND_BINDING_URL='https://zonai.skland.com/api/v1/game/player/binding'
SKLAND_CHECKIN_URL='https://zonai.skland.com/api/v1/score/checkin'
SKLAND_ATTENDANCE_URL='https://zonai.skland.com/api/v1/game/attendance'

declare -A SKLAND_BOARD_MAP
SKLAND_BOARD_MAP[1]='明日方舟'
SKLAND_BOARD_MAP[2]='来自星辰'
SKLAND_BOARD_MAP[3]='明日方舟: 终末地'
SKLAND_BOARD_MAP[4]='泡姆泡姆'
SKLAND_BOARD_MAP[100]='纳斯特港'
SKLAND_BOARD_MAP[101]='开拓芯'

#------------------------------------------------------------------------------
# 日志函数
#------------------------------------------------------------------------------

# (str)
debug() {
  local timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
  echo "[$timestamp] [DEBUG] $1" >/proc/$PID/fd/1
}

# (str)
info() {
  local timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
  echo "[$timestamp] [ INFO] $1" >/proc/$PID/fd/1
}

# (str)
error() {
  local timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
  echo "[$timestamp] [ERROR] $1" >/proc/$PID/fd/2
}

#------------------------------------------------------------------------------
# 工具函数
#------------------------------------------------------------------------------

# 生成 API 签名
# (token, path, query, data) -> signature, header
generate_signature() {
  # 初始化 header
  local platform='1'
  local timestamp=$(($(date +%s) - 2))
  local dId=''
  local vName='1.5.1'
  local header='{"platform":"'$platform'","timestamp":"'$timestamp'","dId":"'$dId'","vName":"'$vName'"}'

  # 生成签名
  local str=$2$3$4$timestamp$header
  local hmac_sha256=$(echo -n $str | openssl dgst -sha256 -hmac $1 | awk '{print $2}')
  local sign=$(echo -n $hmac_sha256 | md5sum | awk '{print $1}')

  # 返回签名和 header
  echo $sign
  echo $header
}

# 名字打码
# (name) -> privacy_name
get_privacy_name() {
  local privacy=$(sed 's/./*/g' <<< ${1:1:-1})
  echo ${1:0:1}$privacy${1: -1}
}

#------------------------------------------------------------------------------
# 通知推送 API
#------------------------------------------------------------------------------

# 初始化
notification_init() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S %Z")
  echo -ne "# 森空岛每日签到\n\n> $timestamp" > /tmp/skland-daily.log
}

# 添加推送内容记录
# (str)
notification_add() {
  echo -ne "\n\n$1" >> /tmp/skland-daily.log
}

# Bark 推送 API
# (url, title, content)
notification_bark() {
  # 发送请求
  local response=$(
    curl \
      -s \
      -H 'Content-Type: application/json; charset=utf-8' \
      -d '{"title":"'$2'","body":"'$3'","group":"Skland"}' \
      $1
  )

  # 检查 CURL 返回值
  if [ $? -ne 0 ]; then
    error "无法访问 Bark API: curl_exit=$?"
    return 1
  fi

  # 打印响应
  debug "Bark 响应: json=$response"
}

# Server 酱推送 API
# (key, title, content)
notification_server_chan() {
  # 发送请求
  local response=$(
    curl \
      -s \
      -H 'Content-Type: application/json; charset=utf-8' \
      -d '{"title":"'$2'","desp":"'$3'"}' \
      "https://sctapi.ftqq.com/$1.send"
  )

  # 检查 CURL 返回值
  if [ $? -ne 0 ]; then
    error "无法访问 Server 酱 API: curl_exit=$?"
    return 1
  fi

  # 检查响应
  if [[ $(jq '.code == 0' <<< $response) == 'true' ]]; then
    info 'Server 酱推送成功'
  else
    error "Server 酱推送失败: response=$response"
    return 1
  fi
}

# 执行推送
notification_execute() {
  # 获取记录
  local content=$(cat /tmp/skland-daily.log)
  rm -f /tmp/skland-daily.log

  # Bark 推送
  if [[ -n $BARK_URL ]]; then
    notification_bark $BARK_URL '【森空岛每日签到】' "$content"
  fi

  # Server 酱推送
  if [[ -n $SERVERCHAN_KEY ]]; then
    notification_server_chan $SERVERCHAN_KEY '【森空岛每日签到】' "$content"
  fi
}

#------------------------------------------------------------------------------
# 鹰角网络通行证 API
#------------------------------------------------------------------------------

# OAuth 登陆
# (token) -> code
hypergryph_auth() {
  # 发送请求
  local response=$(
    curl \
      -s \
      -H 'User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0' \
      -H 'Accept-Encoding: gzip' \
      -H 'Connection: close' \
      -H 'Content-Type: application/json; charset=utf-8' \
      -d '{"appCode":"4ca99fa6b56cc2ba","token":"'$1'","type":0}' \
      $HYPERGRYPH_OAUTH_URL
  )

  # 检查 CURL 返回值
  if [ $? -ne 0 ]; then
    error "无法访问 OAuth API: curl_exit=$?"
    return 1
  fi

  # 检查响应
  if [[ $(jq '.status != 0' <<< $response) == 'true' ]]; then
    local msg=$(jq -r '.msg' <<< $response)
    error "无法登陆鹰角网络通行证: msg=$msg"
    return 1
  fi

  # 返回 code
  echo $(jq -r '.data.code' <<< $response)
}

#------------------------------------------------------------------------------
# 森空岛 API
#------------------------------------------------------------------------------

# 鉴权
# (code) -> cred, token
skland_auth() {
  # 发送请求
  local response=$(
    curl \
      -s \
      -H 'User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0' \
      -H 'Accept-Encoding: gzip' \
      -H 'Connection: close' \
      -H 'Content-Type: application/json; charset=utf-8' \
      -d '{"code":"'$1'","kind":1}' \
      $SKLAND_AUTH_URL
  )

  # 检查 CURL 返回值
  if [ $? -ne 0 ]; then
    error "无法访问鉴权 API: curl_exit=$?"
    return 1
  fi

  # 检查响应
  if [[ $(jq '.code != 0' <<< $response) == 'true' ]]; then
    local msg=$(jq -r '.message' <<< $response)
    error "无法鉴权: message=$msg"
    return 1
  fi

  # 返回 cred 和 token
  echo $(jq -r '.data.cred' <<< $response)
  echo $(jq -r '.data.token' <<< $response)
}

# 获得角色绑定信息
# (cred, token) -> list
skland_get_binding() {
  # 获得签名和 header
  local tmp=$(generate_signature $2 '/api/v1/game/player/binding')
  local sign=$(awk 'NR==1' <<< $tmp)
  local header=$(awk 'NR==2' <<< $tmp)

  # 发送请求
  local response=$(
    curl \
      -s \
      -H 'User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0' \
      -H 'Accept-Encoding: gzip' \
      -H 'Connection: close' \
      -H 'Content-Type: application/json; charset=utf-8' \
      -H "Platform: $(jq -r '.platform' <<< $header)" \
      -H "Timestamp: $(jq -r '.timestamp' <<< $header)" \
      -H "Did: $(jq -r '.dId' <<< $header)" \
      -H "Vname: $(jq -r '.vName' <<< $header)" \
      -H "Sign: $sign" \
      -H "Cred: $1" \
      $SKLAND_BINDING_URL
  )

  # 检查 CURL 返回值
  if [ $? -ne 0 ]; then
    error "无法访问角色绑定 API: curl_exit=$?"
    return 1
  fi

  # 检查响应
  if [[ $(jq '.code != 0' <<< $response) == 'true' ]]; then
    local msg=$(jq -r '.message' <<< $response)
    error "无法获取角色绑定: message=$msg"
    return 1
  fi

  # 返回角色绑定表
  echo $(jq -c '.data.list | map(.bindingList) | flatten(1)' <<< $response)
}

# 森空岛检票
# (cred, token, id)
skland_check_in() {
  # 获得签名和 header
  local tmp=$(generate_signature $2 '/api/v1/score/checkin' '' '{"gameId":'$3'}')
  local sign=$(awk 'NR==1' <<< $tmp)
  local header=$(awk 'NR==2' <<< $tmp)

  # 发送请求
  local response=$(
    curl \
      -s \
      -H 'User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0' \
      -H 'Accept-Encoding: gzip' \
      -H 'Connection: close' \
      -H 'Content-Type: application/json; charset=utf-8' \
      -H "Platform: $(jq -r '.platform' <<< $header)" \
      -H "Timestamp: $(jq -r '.timestamp' <<< $header)" \
      -H "Did: $(jq -r '.dId' <<< $header)" \
      -H "Vname: $(jq -r '.vName' <<< $header)" \
      -H "Sign: $sign" \
      -H "Cred: $1" \
      -d '{"gameId":'$3'}' \
      $SKLAND_CHECKIN_URL
  )

  # 检查 CURL 返回值
  if [ $? -ne 0 ]; then
    error "无法访问检票 API: curl_exit=$?"
    return 1
  fi

  # 检查响应
  local board=${SKLAND_BOARD_MAP[$3]}
  if [[ $(jq '.code == 0' <<< $response) == 'true' ]]; then
    notification_add "版面【$board】检票成功"
    info "版面【$board】检票成功"
  else
    local msg=$(jq -r '.message' <<< $response)
    notification_add "版面【$board】检票成功，错误信息：$msg"
    error "版面【$board】检票失败: message=$msg"
    return 1
  fi
}

# 明日方舟签到
# (cred, token, item)
skland_attendance() {
  # 提取角色数据
  local uid=$(jq -r '.uid' <<< $3)
  local cid=$(jq -r '.channelMasterId' <<< $3)
  local cname=$(jq -r '.channelName' <<< $3)
  local nname=$(jq -r '.nickName' <<< $3)
  local pname=$(get_privacy_name $nname)

  # 获得签名和 header
  local tmp=$(generate_signature $2 '/api/v1/game/attendance' '' '{"uid":"'$uid'","gameId":"'$cid'"}')
  local sign=$(awk 'NR==1' <<< $tmp)
  local header=$(awk 'NR==2' <<< $tmp)

  # 发送请求
  local response=$(
    curl \
      -s \
      -H 'User-Agent: Skland/1.5.1 (com.hypergryph.skland; build:100501001; Android 34; ) Okhttp/4.11.0' \
      -H 'Accept-Encoding: gzip' \
      -H 'Connection: close' \
      -H 'Content-Type: application/json; charset=utf-8' \
      -H "Platform: $(jq -r '.platform' <<< $header)" \
      -H "Timestamp: $(jq -r '.timestamp' <<< $header)" \
      -H "Did: $(jq -r '.dId' <<< $header)" \
      -H "Vname: $(jq -r '.vName' <<< $header)" \
      -H "Sign: $sign" \
      -H "Cred: $1" \
      -d '{"uid":"'$uid'","gameId":"'$cid'"}' \
      $SKLAND_ATTENDANCE_URL
  )

  # 检查 CURL 返回值
  if [ $? -ne 0 ]; then
    error "无法访问签到 API: curl_exit=$?"
    return 1
  fi

  # 检查响应
  if [[ $(jq '.code == 0' <<< $response) == 'true' ]]; then
    local awards=$(jq '.data.awards | map([.resource.name, .count]) | map(join(" x")) | join(", ")' <<< $response)
    notification_add "$cname - $pname 签到成功，获得了：$awards"
    info "$cname - $pname 签到成功，获得了：$awards"
  else
    local msg=$(jq -r '.message' <<< $response)
    notification_add "$cname - $pname 签到失败，错误信息：$msg"
    error "$cname - $pname 签到失败: message=$msg"
    return 1
  fi
}

#------------------------------------------------------------------------------
# 签到流程函数
#------------------------------------------------------------------------------

# 进行签到
# (token)
do_attendance() {
  # 初始化推送
  notification_init

  # OAuth 登陆
  local code=$(hypergryph_auth $1)
  if [[ -z $code ]]; then
    return 1
  fi
  info 'OAuth 登陆成功'

  # 森空岛鉴权
  local tmp=$(skland_auth $code)
  if [[ -z $tmp ]]; then
    return 1
  fi
  local cred=$(awk 'NR==1' <<< $tmp)
  local token=$(awk 'NR==2' <<< $tmp)
  info '森空岛鉴权成功'

  # 获取角色绑定
  local list=$(skland_get_binding $cred $token)
  if [[ -z $list ]]; then
    return 1
  fi
  info '角色绑定获取成功'

  # 森空岛检票
  notification_add '## 森空岛各版面每日检票'
  for id in ${!SKLAND_BOARD_MAP[*]}; do
    skland_check_in $cred $token $id &
  done
  wait
  info '森空岛检票完毕'

  # 明日方舟签到
  notification_add '## 明日方舟签到'
  local list_len=$(jq 'length' <<< $list)
  local i=0
  while [ $i -lt $list_len ]; do
    local item=$(jq -c ".[$i]" <<< $list)
    skland_attendance $cred $token $item &
    i=$(($i + 1))
  done
  wait
  info '明日方舟签到完毕'

  # 推送通知
  notification_execute
}

#------------------------------------------------------------------------------
# 主入口
#------------------------------------------------------------------------------

# 检查环境变量
if [[ -z $SKLAND_TOKEN ]]; then
  error '环境变量 "SKLAND_TOKEN" 未定义'
  exit 1
fi

# 配置环境
PID=$$
if [[ -n $DOCKER ]]; then
  if [ -f /run/attendance.pid ]; then
    PID=$(cat /run/attendance.pid)
  else
    echo -n $PID >/run/attendance.pid
  fi
fi

# 执行多账号签到任务
IFS="," read -ra tokens <<< $SKLAND_TOKEN
i=1
for token in ${tokens[*]}; do
  info "正在处理账号 #$i"
  do_attendance $token
  i=$(($i + 1))
done

# 执行 Docker 计划任务
if [[ -n $DOCKER && $PID != $$ ]]; then
  crond -f
fi
