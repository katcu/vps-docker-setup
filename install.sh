#!/bin/bash

# ==============================================================================
# Project: Lightweight Docker Environment Setup (Dockge + CF Tunnel)
# Author: [Your Name/GitHub Username]
# Description: 专为 1H1G 小内存 VPS 设计的 Docker 自动化部署脚本
# Version: 2.0
# ==============================================================================

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- 全局变量 ---
DOCKGE_DIR="/opt/dockge"
STACKS_DIR="/opt/stacks"

# 检查 Root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 请使用 root 权限运行此脚本 (sudo -i)${NC}"
        exit 1
    fi
}

# 1. 系统清理与优化 (Swap)
function system_init() {
    echo -e "${YELLOW}>>> [1/3] 正在检查系统 Swap...${NC}"
    if grep -q "swap" /etc/fstab; then
        echo -e "${GREEN}Swap 已存在，跳过。${NC}"
    else
        echo "创建 2GB Swap 文件以防止 OOM..."
        fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
        echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
        sysctl -p
        echo -e "${GREEN}Swap (2GB) 创建并优化完成。${NC}"
    fi
}

# 2. Docker 安装
function install_docker() {
    echo -e "${YELLOW}>>> [2/3] 检查 Docker 环境...${NC}"
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker 已安装。${NC}"
    else
        echo "正在安装 Docker..."
        if [ -x "$(command -v curl)" ]; then
            curl -fsSL https://get.docker.com | bash
        else
            apt-get update && apt-get install -y curl && curl -fsSL https://get.docker.com | bash
        fi
        systemctl enable --now docker
    fi
    
    # 确保网络存在
    if ! docker network ls | grep -q "proxy-net"; then
        docker network create proxy-net
        echo -e "${GREEN}创建共享网络 proxy-net 成功。${NC}"
    fi
}

# 3. 安装/重置 Dockge
function install_dockge() {
    system_init
    install_docker
    
    echo -e "${YELLOW}>>> [3/3] 部署 Dockge 可视化面板...${NC}"
    mkdir -p "$DOCKGE_DIR"
    mkdir -p "$STACKS_DIR"
    
    cat > "$DOCKGE_DIR/compose.yaml" <<EOF
services:
  dockge:
    image: louislam/dockge:1
    restart: unless-stopped
    ports:
      - 5001:5001
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - $STACKS_DIR:/opt/stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
    networks:
      - proxy-net

networks:
  proxy-net:
    external: true
EOF

    cd "$DOCKGE_DIR"
    docker compose up -d
    echo -e "${GREEN}Dockge 安装完成！${NC}"
    echo -e "访问地址: http://$(curl -s ifconfig.me):5001"
}

# 4. 配置 Cloudflare Tunnel (独立模块)
function configure_tunnel() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}     配置 Cloudflare Tunnel     ${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    if [ ! -d "$STACKS_DIR" ]; then
        echo -e "${RED}错误：未检测到 Dockge 目录，请先执行选项 [1] 安装基础环境。${NC}"
        return
    fi

    echo "请去 Cloudflare Zero Trust -> Access -> Tunnels 获取 Token。"
    read -p "请输入 Token (eyJh...): " cf_token
    
    if [ -z "$cf_token" ]; then
        echo -e "${RED}Token 为空，操作取消。${NC}"
        return
    fi

    echo "正在配置 Tunnel..."
    mkdir -p "$STACKS_DIR/cf-tunnel"
    
    cat > "$STACKS_DIR/cf-tunnel/compose.yaml" <<EOF
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: always
    command: tunnel run --token $cf_token
    networks:
      - proxy-net

networks:
  proxy-net:
    external: true
EOF

    echo "启动 Tunnel..."
    cd "$STACKS_DIR/cf-tunnel"
    docker compose down 2>/dev/null
    docker compose up -d
    
    echo -e "${GREEN}Tunnel 已上线！请在 CF 后台配置 Public Hostname 指向 http://dockge:5001${NC}"
}

# 5. 卸载功能
function uninstall_all() {
    echo -e "${RED}!!! 危险操作警报 !!!${NC}"
    echo "此操作将："
    echo "1. 删除 Dockge 及所有相关数据 (/opt/dockge, /opt/stacks)"
    echo "2. 停止相关容器"
    echo ""
    read -p "确定要继续吗? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消。"
        return
    fi

    echo "正在清理..."
    cd "$DOCKGE_DIR" 2>/dev/null && docker compose down
    cd "$STACKS_DIR/cf-tunnel" 2>/dev/null && docker compose down
    
    rm -rf "$DOCKGE_DIR"
    rm -rf "$STACKS_DIR"
    echo -e "${GREEN}面板及数据目录已清除。${NC}"

    read -p "是否连同 Docker 引擎一起卸载? (适合重装系统前清理) [y/N] " remove_docker
    if [[ "$remove_docker" =~ ^[Yy]$ ]]; then
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        rm -rf /var/lib/docker
        echo -e "${GREEN}Docker 已卸载。${NC}"
    fi
}

# --- 主菜单 ---
show_menu() {
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}    1H1G VPS 极简部署助手 v2.0    ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "1. ${GREEN}一键安装${NC} (Swap + Docker + Dockge)"
    echo -e "2. ${YELLOW}配置 CF Tunnel${NC} (内网穿透)"
    echo -e "3. ${RED}卸载/清理${NC} (环境重置)"
    echo -e "0. 退出"
    echo -e "${BLUE}=========================================${NC}"
    read -p "请输入选项 [0-3]: " choice
    
    case $choice in
        1) install_dockge ;;
        2) configure_tunnel ;;
        3) uninstall_all ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
}

check_root
while true; do
    show_menu
    echo ""
    read -p "按回车键返回菜单..."
done