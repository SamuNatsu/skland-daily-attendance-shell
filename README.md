# 森空岛签到

纯 Shell 实现的森空岛各版面登岛检票和明日方舟每日签到任务

主要逻辑代码移植自 [skland-daily-attendance](https://github.com/enpitsuLin/skland-daily-attendance)

## 前置需求

* 脚本需要在 [Bash](https://www.gnu.org/software/bash) 环境下运行，Windows 用户请使用 [MSYS2](https://www.msys2.org)、[WSL2](https://learn.microsoft.com/zh-cn/windows/wsl/install) 或虚拟机等拥有 Bash 的环境运行
* 脚本需要使用 [curl](https://curl.se)、[OpenSSL](https://www.openssl.org) 和 [jq](https://jqlang.github.io/jq) 这三个第三方软件包

## 使用方法

### 直接使用

先登录森空岛网页版，然后打开 <https://web-api.skland.com/account/info/hg> 记下 `content` 字段的值

设置环境变量 `SKLAND_TOKEN`，值为上一步获取的 `content`，如果需要多账号支持，请使用半角逗号 `,` 分割

运行脚本，它将自动帮你完成签到服务

```sh
SKLAND_TOKEN=xxxx,yyyy,zzzz ./attendance.sh
```

### 在 Docker 中使用

Docker 镜像在 <https://hub.docker.com/r/snrainiar/skland-daily-attendance-shell>

你需要根据 [直接使用](#直接使用) 中的步骤配置环境变量 `SKLAND_TOKEN`，然后启动镜像即可

镜像中配置了计划任务，会在每天的 05:00(CST) 执行一次签到，因此你不需要手动重启镜像

```sh
docker run -d --restart always --name skland-daily-attendance -e SKLAND_TOKEN=xxxx,yyyy,zzzz snrainiar/skland-daily-attendance-shell
```

### 在 Docker compose 中使用

步骤与 [在 Docker 中使用](#在-docker-中使用) 类似，你需要编写一份 `compose.yml` 文件

```yml
services:
  skland-daily-attendance:
    image: snrainiar/skland-daily-attendance-shell
    container_name: skland-daily-attendance
    restart: always
    environment:
      SKLAND_TOKEN: xxxx,yyyy,zzzz
```

## 通知推送功能

**通知推送功能仅适用于 Docker 和 Docker compose 使用方法**

### Server 酱推送

你需要设置环境变量 `SERVERCHAN_KEY`，填入你 Server 酱的推送密钥

### Bark 推送

你需要设置环境变量 `BARK_URL`，填入你 Bark 的推送地址
