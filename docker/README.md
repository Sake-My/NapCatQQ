# Docker 镜像

镜像从本仓库源码构建，包含 WebUI、Shell 和 Linux QQ 3.2.34-53644，
不依赖已下线的 `mlikiowa/napcat-docker` 基础镜像或上游 Release。
GitHub Actions 当前构建和验证 `linux/amd64`。

## 构建与发布

相关文件变更后，分支推送自动构建并检查 WebUI 启动、重启后的配置保留。
默认分支验证通过后发布到 `ghcr.io/<仓库所有者小写>/<仓库名小写>`，
标签为 `latest` 和 `sha-<7位提交号>`。
也可在 Actions → Build and publish Docker image → Run workflow 手动运行；
非默认分支手动运行只发布提交标签，不更新 `latest`。
使用仓库自带的 `GITHUB_TOKEN`，无需配置 Docker Hub 密码。

首次创建的 GHCR 包通常为私有。需要匿名拉取时，由包所有者在
GitHub Packages 的 Package settings 中将可见性设为 Public；
否则在部署机器上使用有 `read:packages` 权限的凭据登录 GHCR。

本地构建：

```bash
docker build --build-arg NAPCAT_VERSION=0.0.0-local -t napcatqq:local .
```

## 1Panel / Docker Compose

在 1Panel 的容器编排中使用下列配置，镜像名对应本 fork：

```yaml
services:
  napcat:
    image: ghcr.io/sake-my/napcatqq:latest
    container_name: napcat
    restart: unless-stopped
    environment:
      TZ: Asia/Shanghai
      # 留空则首次启动生成随机 Token，保存在 config/webui.json。
      NAPCAT_WEBUI_SECRET_KEY: ""
      # 可选：指定已有登录记录的 QQ 号用于快速登录。
      ACCOUNT: ""
    ports:
      - "127.0.0.1:6099:6099"
    volumes:
      - ./data/qq:/app/.config/QQ
      - ./data/config:/app/napcat/config
      - ./data/plugins:/app/napcat/plugins
```

QQ 数据、配置和插件沿用原镜像常见的挂载路径。默认运行用户 UID/GID 为 1000；
启动时入口脚本只调整以上数据目录以及容器内日志、缓存目录的所有者。
已有配置不会被初始化流程覆盖；显式设置 `NAPCAT_WEBUI_SECRET_KEY` 会按应用原有逻辑更新 Token。

将域名通过 1Panel OpenResty 反向代理到 `http://127.0.0.1:6099`，
配置 HTTPS 和 WebSocket 支持，即可通过 `https://你的域名/webui/` 访问。
此地址适用于 OpenResty 使用 host 网络的情况；独立 bridge 网络的代理应使用共享网络内的容器名。

NapCat 和 AstrBot 加入同一个自定义 Docker 网络后，在 NapCat 添加反向 WebSocket，
地址填写 `ws://astrbot:6199/ws`（将 `astrbot` 替换为实际容器名或网络别名）。
不需要将 6099 或 6199 暴露到公网。仅使用 HTTPS 且证书通过 DNS 验证时，
这些服务的公网入站只需要 TCP 443。

CI 只验证容器与 WebUI 能启动，不验证真实 QQ 登录或消息收发；部署后需扫码登录验证。
上游已停止提供原发布资源，容器内的在线更新功能可能不可用，应重新构建并更换镜像更新。
