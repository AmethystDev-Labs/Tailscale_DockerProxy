#!/bin/sh

# --- 配置与日志函数 ---
# 定义日志输出格式
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

# 遇到错误立即停止脚本执行
set -e

# --- 1. 检查环境变量 ---
log "检查配置中..."
if [ -z "${TAILSCALE_AUTHKEY}" ]; then
    log "错误: 环境变量 TAILSCALE_AUTHKEY 未设置！"
    exit 1
fi
log "TAILSCALE_AUTHKEY 已确认。"

# --- 2. 启动 Tailscale 守护进程 ---
log "正在启动 tailscaled (用户态网络模式)..."
# 使用 & 后台运行，并将日志重定向到标准输出
/app/tailscaled --tun=userspace-networking --socks5-server=0.0.0.0:1055 > /dev/null 2>&1 &

sleep 2


# --- 3. 登录并连接 Tailscale ---
log "正在连接 Tailscale 节点..."
if /app/tailscale up --authkey="${TAILSCALE_AUTHKEY}" --hostname="${TAILSCALE_HOSTNAME:-Docker}"; then
    log "Tailscale 已成功启动并连接。"
else
    log "错误: Tailscale 启动失败！"
    exit 1
fi
