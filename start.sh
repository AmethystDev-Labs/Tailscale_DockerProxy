#!/bin/sh
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

# --- 1. 检查环境变量 ---
log "检查配置中..."
if [ -z "${TAILSCALE_AUTHKEY}" ]; then
    log "错误: 环境变量 TAILSCALE_AUTHKEY 未设置！"
    exit 1
fi

log "tskey: ${TAILSCALE_AUTHKEY}"

# --- 2. 清理旧 socket ---
rm -f /var/run/tailscale/tailscaled.sock

# --- 3. 注册 init hook：tailscaled 就绪后在后台执行 tailscale up ---
# tailscaled 启动后会监听 socket，我们轮询等待它就绪再执行 up
(
    log "等待 tailscaled socket 就绪..."
    for i in $(seq 1 30); do
        if /app/tailscale status > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    log "正在连接 Tailscale 节点..."
    /app/tailscale up \
        --authkey="${TAILSCALE_AUTHKEY}" \
        --hostname="${TAILSCALE_HOSTNAME:-K8s-Docker}" \
        --accept-dns=false

    if [ $? -eq 0 ]; then
        log "Tailscale 已成功连接。代理地址: SOCKS5 0.0.0.0:1055"
    else
        log "错误: Tailscale 连接失败！"
        # 通知主进程退出（发送 SIGTERM 给 PID 1）
        kill 1
    fi
) &

# --- 4. exec：让 tailscaled 成为 PID 1 ---
# 这是关键：exec 替换当前 shell 进程，tailscaled 直接持有 PID 1
log "正在以 PID 1 启动 tailscaled..."
exec /app/tailscaled \
    --tun=userspace-networking \
    --socks5-server=0.0.0.0:1055 \
    --outbound-http-proxy-listen=0.0.0.0:1055 \
    --state=mem: \
    2>&1
