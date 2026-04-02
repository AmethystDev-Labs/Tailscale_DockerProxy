#!/bin/sh

# --- 配置与日志函数 ---
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

# 即使部分命令失败也继续执行后续逻辑（手动控制错误）
set -m 

# --- 1. 检查环境变量 ---
log "检查配置中..."
if [ -z "${TAILSCALE_AUTHKEY}" ]; then
    log "错误: 环境变量 TAILSCALE_AUTHKEY 未设置！"
    exit 1
fi

# --- 2. 启动 Tailscale 守护进程 ---
log "正在启动 tailscaled (用户态网络模式)..."

# 移除旧的 socket 文件防止冲突（如果存在）
rm -f /var/run/tailscale/tailscaled.sock

# 在后台启动 tailscaled
# --state=mem: 适合容器化环境，不持久化状态（由 AuthKey 重新注册）
/app/tailscaled --tun=userspace-networking --socks5-server=0.0.0.0:1055 --outbound-http-proxy-listen=0.0.0.0:1055 > /dev/stdout 2>&1 &
PID=$!

# 等待 tailscaled 启动就绪
sleep 3

# --- 3. 登录并连接 Tailscale ---
log "正在连接 Tailscale 节点..."
# 使用 --accept-routes 等常用配置提高可用性
/app/tailscale up \
    --authkey="${TAILSCALE_AUTHKEY}" \
    --hostname="${TAILSCALE_HOSTNAME:-Zeabur-Docker}" \
    --accept-dns=false

if [ $? -eq 0 ]; then
    log "Tailscale 已成功连接。代理地址: SOCKS5 127.0.0.1:1055"
else
    log "错误: Tailscale 连接失败！"
    kill $PID
    exit 1
fi

# --- 4. 阻塞主进程 ---
log "服务已就绪，正在保持运行..."
# 使用 wait 等待后台进程，使脚本不会退出
# 这样容器就会一直保持运行状态
wait $PID
