# 森空岛每日签到 Docker 镜像

一个纯 Shell 实现的 森空岛每日签到，仅使用 CURL、OpenSSL 和 jq 这三个第三方程序。

代码移植自 [skland-daily-attendance](https://github.com/enpitsuLin/skland-daily-attendance)。  
暂时没有实现推送服务，如有需要请 ISSUE 我或发一个 PR。

虽然是 Docker 镜像，但是你也可以直接就把仓库里的 `attendance.sh` 拿去用而不使用 Docker。

## 直接使用

1. 登录森空岛网页版后，打开 <https://web-api.skland.com/account/info/hg> 记下 content 字段的值。
2. 在脚本运行前请设置环境变量 `SKLAND_TOKEN`，值为上一步获取 content，如果需要多账号支持，请使用半角逗号 `,` 分割
3. 运行脚本，它将自动帮你完成签到服务

## 与 Docker/Docker compose 一起使用

Docker 镜像在 <https://hub.docker.com/r/snrainiar/docker-skland-daily>

与直接使用类似，你需要设置环境变量 `SKLAND_TOKEN`，然后启动镜像即可。

与直接使用不同，该 Docker 镜像配置了计划任务，会在每天的 00:00 自动执行一次签到。
