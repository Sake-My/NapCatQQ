# syntax=docker/dockerfile:1
FROM node:20-bookworm-slim AS builder

ARG NAPCAT_VERSION=0.0.0-docker
ENV NAPCAT_VERSION=${NAPCAT_VERSION}
WORKDIR /src

RUN npm install --global pnpm@9.15.9
COPY . .
RUN pnpm install --frozen-lockfile \
    && pnpm run build:webui \
    && pnpm run build:shell \
    && cd packages/napcat-shell/dist \
    && npm pkg delete devDependencies \
    && npm install --omit=dev --no-audit --no-fund

FROM ubuntu:22.04 AS runtime

ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive
ARG QQ_DOWNLOAD_BASE=https://qqdl.gtimg.cn/qqfile/QQNT/9.9.36/beta/9ee04bef
ARG QQ_VERSION=3.2.34-53644

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl dbus-user-session ffmpeg fonts-wqy-zenhei gosu jq \
        libasound2 libatspi2.0-0 libdbus-1-3 libgbm1 libgtk-3-0 libnotify4 \
        libnss3 libsecret-1-0 libx11-xcb1 libxss1 libxtst6 tini tzdata xauth xvfb \
    && case "${TARGETARCH}" in amd64|arm64) ;; *) exit 1 ;; esac \
    && curl --fail --location --retry 3 --connect-timeout 30 --max-time 600 \
        "${QQ_DOWNLOAD_BASE}/linuxqq_${QQ_VERSION}_${TARGETARCH}.deb" -o /tmp/linuxqq.deb \
    && apt-get install -y --no-install-recommends /tmp/linuxqq.deb \
    && rm /tmp/linuxqq.deb \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 napcat \
    && useradd --uid 1000 --gid napcat --home-dir /app --create-home napcat

WORKDIR /app
ENV HOME=/app \
    TZ=Asia/Shanghai \
    NAPCAT_WORKDIR=/app/napcat \
    NAPCAT_QQ_DATA_DIR=/app/.config/QQ \
    NAPCAT_DISABLE_PIPE=1

COPY --from=builder --chown=napcat:napcat /src/packages/napcat-shell/dist/ /app/napcat/
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/napcat-entrypoint

# 使用 QQ 自带的 Electron 加载当前源码构建的 NapCat。
RUN printf '%s\n' "import('file:///app/napcat/napcat.mjs').catch(error => { console.error(error); process.exit(1); });" \
        > /opt/QQ/resources/app/loadNapCat.js \
    && jq '.main = "./loadNapCat.js"' /opt/QQ/resources/app/package.json > /tmp/qq-package.json \
    && mv /tmp/qq-package.json /opt/QQ/resources/app/package.json \
    && mkdir -p /app/.config/QQ /app/napcat/config /app/napcat/plugins /app/napcat/logs /app/napcat/cache \
    && chown -R napcat:napcat /app

EXPOSE 6099
VOLUME ["/app/.config/QQ", "/app/napcat/config", "/app/napcat/plugins"]
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/napcat-entrypoint"]
