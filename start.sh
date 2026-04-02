#!/bin/sh
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

if [ -z "${TAILSCALE_AUTHKEY}" ]; then
    log "错误: 环境变量 TAILSCALE_AUTHKEY 未设置！"
    exit 1
fi

log "AUTHKEY 前缀: $(echo "${TAILSCALE_AUTHKEY}" | cut -c1-20)..."

rm -f /var/run/tailscale/tailscaled.sock

(
    log "等待 tailscaled socket 就绪..."
    for i in $(seq 1 30); do
        if /app/tailscale status > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    log "正在连接 Tailscale 节点..."
    # 关键修复：用变量展开时加引号，防止 shell 对特殊字符做分词
    AUTH="${TAILSCALE_AUTHKEY}"
    log "传入 authkey 前缀: $(echo "$AUTH" | cut -c1-20)..."

    /app/tailscale up \
        --authkey="$AUTH" \
        --hostname="${TAILSCALE_HOSTNAME:-K8s-Docker}" \
        --accept-dns=false \
        --reset

    if [ $? -eq 0 ]; then
        log "Tailscale 已成功连接。"
    else
        log "错误: Tailscale 连接失败！"
        kill 1
    fi
) &

log "正在以 PID 1 启动 tailscaled..."
exec /app/tailscaled \
    --tun=userspace-networking \
    --socks5-server=0.0.0.0:1055 \
    --outbound-http-proxy-listen=0.0.0.0:1055 \
    --state=mem: \
    2>&1
