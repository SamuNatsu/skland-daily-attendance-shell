# 森空岛签到

纯 Shell 实现的森空岛各版面登岛检票和明日方舟每日签到任务

主要逻辑代码移植自 [skland-daily-attendance](https://github.com/enpitsuLin/skland-daily-attendance)

## 前置需求

- 脚本需要在 [Bash](https://www.gnu.org/software/bash) 环境下运行，Windows 用户请使用 [MSYS2](https://www.msys2.org)、[WSL2](https://learn.microsoft.com/zh-cn/windows/wsl/install) 或虚拟机等拥有 Bash 的环境运行
- 脚本需要使用 [curl](https://curl.se)、[OpenSSL](https://www.openssl.org) 和 [jq](https://jqlang.github.io/jq) 这三个第三方软件包
- 如果需要使用 SMTP 消息推送功能，请确保系统中可以使用 [mailx](https://linux.die.net/man/1/mailx) 命令发送邮件

## 使用方法

### 直接使用

1. 登录森空岛网页版，然后打开网址 <https://web-api.skland.com/account/info/hg>，记下 `content` 字段的值 **（保护账号安全，请勿向他人透露该值！）**

2. 设置环境变量 `SKLAND_TOKEN`，值为上一步获取的 `content`；如果需要多账号支持，请使用半角逗号 `,` 分隔各个 `content`，如：`xxxx,yyyy,zzzz`

3. 运行脚本如下，它将自动帮你完成签到服务
   ```sh
   SKLAND_TOKEN=xxxx,yyyy,zzzz ./attendance.sh
   ```

### 在 Docker 中使用

Docker 镜像在 <https://hub.docker.com/r/snrainiar/skland-daily-attendance-shell>

你需要根据 [直接使用](#直接使用) 中的步骤获得环境变量 `SKLAND_TOKEN` 的值，然后把它编写到 Docker 启动命令中启动镜像即可

```sh
docker run \
  -d \
  --restart always \
  --name skland-daily-attendance \
  -e SKLAND_TOKEN=xxxx,yyyy,zzzz \
  snrainiar/skland-daily-attendance-shell
```

> [!NOTE]
> 镜像中配置了计划任务，会在每天的 05:00（北京时间） 执行一次签到，因此你不需要手动重启镜像

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

### 白嫖 GitHub Actions 使用

> [!CAUTION]
> 强烈 **不推荐** 使用该方式，因为可能会触发 GitHub Actions 滥用检测导致仓库爆炸

1. Fork 一份仓库代码  
   点击仓库右上角的 `Fork` 按钮将仓库 Fork 到自己的账号下

2. 添加仓库 Secret  
   点击 `Settings` -> 点击选项卡 `Secrets and variables` -> 点击 `Actions` -> 点击 `New repository secret`

   建立名为 `SKLAND_TOKEN` 的 Secret，按照 [直接使用](#直接使用) 中的要求填写

4. 启动 Action  
   点击 `Actions` -> 点击左侧 `Schedule` -> 点击 `Run workflow` -> 点击按钮 `Run workflow`

   Action 默认为关闭状态，Fork 之后需要手动执行一次，若成功运行其才会激活

> [!IMPORTANT]
> 如果仓库 60 天内没有活动，其计划 Actions 会被 **自动禁用**，你需要手动进行处理  
> 一般情况下你会收到 Github 发送的一封关于 Actions 将被禁用的通知邮件

## 通知推送功能

### Bark 推送

你需要设置环境变量 `BARK_URL`，填入你 Bark 的推送地址

对于白嫖 GitHub Actions 用户，你需要像 [白嫖 GitHub Actions 使用](#白嫖-github-actions-使用) 中定义 `SKLAND_TOKEN` 一样在仓库 Secret 中定义 `BARK_URL`

### Server 酱推送

你需要设置环境变量 `SERVERCHAN_SENDKEY`，填入你 Server 酱的推送密钥

对于白嫖 GitHub Actions 用户，配置环境变量的方法如 [Bark 推送](#bark-推送) 中的一样

### SMTP 推送

> [!IMPORTANT]
> SMTP 推送强制要求使用 **TLS 协议**，并且要求进行 **登陆验证**

你需要配置如下环境变量：

|       名字       |        作用        |          示例值           |
| :--------------: | :----------------: | :-----------------------: |
|   `SMTP_HOST`    |   SMTP 主机地址    |             -             |
|   `SMTP_PORT`    |     SMTP 端口      | 一般来说是 `465` 或 `587` |
|   `SMTP_USER`    |    SMTP 用户名     |    一般是一个邮箱地址     |
|  `SMTP_PASSWD`   |     SMTP 密码      |             -             |
|   `SMTP_FROM`    |     发送者邮箱     | 一般来说应该和用户名一样  |
|    `SMTP_TO`     |     接收者邮箱     |             -             |
| `SMTP_REAL_NAME` |     发送者名字     |             -             |
| `SMTP_START_TLS` | 启用 STARTTLS 协议 |   只能是 `on` 或 `off`    |

对于白嫖 GitHub Actions 用户，配置环境变量的方法如 [Bark 推送](#bark-推送) 中的一样

## 开发者功能

在执行脚本时，设置环境变量 `SKLAND_DEBUG` 为非空值，可以让脚本打印测试信息，帮助你发现可能存在的问题或告知开发者以进行漏洞修复

> [!CAUTION]
> 测试信息中可能包含你账号的敏感信息，请注意保护
