#!/usr/bin/env bash
set -Eeuo pipefail

# 兼容由 Docker/1Panel 创建的 root 所有者挂载目录，QQ 本身以普通用户运行。
if [[ $(id -u) == 0 ]]; then
    mkdir -p /app/.config/QQ /app/napcat/{config,plugins,logs,cache}
    chown -R napcat:napcat /app/.config/QQ /app/napcat/{config,plugins,logs,cache}
    exec gosu napcat "$0" "$@"
fi

umask 077
if [[ ! -e /app/napcat/config/webui.json ]]; then
    # 只初始化新配置；保留已有 Token、OneBot 设置和登录状态。
    token=${NAPCAT_WEBUI_SECRET_KEY:-$(cat /proc/sys/kernel/random/uuid)}
    jq -n --arg token "$token" \
        '{host: "0.0.0.0", port: 6099, token: $token}' \
        > /app/napcat/config/webui.json
fi

if [[ -n ${ACCOUNT:-} ]]; then
    set -- "$@" -q "$ACCOUNT"
fi

exec dbus-run-session -- xvfb-run --auto-servernum \
    --server-args="-screen 0 1280x720x24 -nolisten tcp" \
    /opt/QQ/qq --no-sandbox "$@"
