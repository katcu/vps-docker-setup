非常抱歉，之前的输出确实因为长度限制被截断了。

为了确保您能一次性复制完整的内容，我将省略所有无关的对话文本，**只提供完整的 `README.md` 代码块**。请直接复制下面的全部内容：

```markdown
# 🚀 Lightweight Docker Setup for 1H1G VPS

> 专为 1核 1G 内存 (1H1G) VPS 设计的极简 Docker + Dockge + Cloudflare Tunnel 部署脚本。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Bash](https://img.shields.io/badge/language-Bash-green.svg)

## 📖 简介 (Introduction)

在 1H1G (1 CPU, 1GB RAM) 的 VPS 上运行现代应用极具挑战性。市面上的面板（如 1Panel, 宝塔/aaPanel）后台资源占用过高（通常开机即占用 300MB-500MB），导致留给业务的内存所剩无几。

本脚本旨在提供一个**极致轻量**的解决方案，让您的 1G 内存机器也能流畅运行 Docker 服务：

*   **核心架构：** 原生 Docker + Dockge (基于 Compose 的轻量级可视化管理面板)。
*   **内存占用：** 管理环境仅占用约 **50MB - 80MB**。
*   **网络穿透：** 内置 Cloudflare Tunnel 模块，无需公网 IP，无需开放 80/443 端口。
*   **系统保护：** 自动配置 2GB Swap，防止内存溢出 (OOM) 导致死机。

## ✨ 功能特性 (Features)

- [x] **智能环境检查**：自动检测 Docker、Swap 状态，具备幂等性（可重复运行，不会破坏现有环境）。
- [x] **一键 Swap**：自动创建 2GB 虚拟内存并优化 `swappiness` 策略，专为小内存优化。
- [x] **Dockge 部署**：部署 Uptime Kuma 作者开发的 Dockge 面板，直接管理 `compose.yaml` 文件。
- [x] **CF Tunnel 集成**：独立的 Tunnel 配置模块，一键接入 Cloudflare Zero Trust。
- [x] **统一网络管理**：自动创建 `proxy-net` 桥接网络，实现 Tunnel 与容器通过“容器名”互联。

## 🛠️ 快速开始 (Quick Start)

### 方法一：一键安装 (推荐)
使用 `root` 用户 SSH 登录您的 VPS，执行以下命令：
*(请将命令中的 `[你的GitHub用户名]` 替换为您实际的 GitHub 用户名)*

```bash
curl -fsSL https://raw.githubusercontent.com/[你的GitHub用户名]/vps-docker-setup/main/install.sh | bash
```

### 方法二：手动下载运行
```bash
wget https://raw.githubusercontent.com/[你的GitHub用户名]/vps-docker-setup/main/install.sh
chmod +x install.sh
./install.sh
```

## 📖 使用指南 (Usage)

运行脚本后，您将看到交互式菜单，包含以下功能：

### 1. 一键安装 (Install)
*   **执行流程**：
    1.  检查系统 Swap，如果没有则自动创建 2GB Swap。
    2.  检查 Docker，如果没有则调用官方脚本自动安装。
    3.  部署 Dockge 面板到 `/opt/dockge`。
*   **访问方式**：安装完成后，访问 `http://你的VPS_IP:5001` 进行初始化。

### 2. 配置 CF Tunnel (Configure Tunnel)
*   **适用场景**：当您希望通过域名访问服务，且不想暴露 VPS 端口或配置 Nginx 反代时。
*   **前置要求**：
    1.  登录 [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)。
    2.  进入 `Access` -> `Tunnels` -> `Create a tunnel`。
    3.  选择 `Cloudflared`，复制安装命令中的 **Token** (即 `--token` 后面的长字符串)。
*   **操作步骤**：
    1.  运行脚本选择选项 `2`。
    2.  粘贴 Token。
    3.  脚本会自动拉取镜像并启动 Tunnel。
*   **☁️ Cloudflare 后台配置说明 (关键)**：
    *   回到 CF Tunnel 配置页面，点击 `Public Hostname`。
    *   **Subdomain**: 填写您想要的子域名 (如 `admin`)。
    *   **Domain**: 选择您的域名。
    *   **Service Type**: 选择 `HTTP`。
    *   **URL**: 填写 `dockge:5001`。
    *   *(注意：此处直接填写容器名 `dockge`，利用 Docker 内部 DNS 解析，**不要**填写 IP 地址)*

### 3. 卸载/清理 (Uninstall)
*   **功能**：环境重置工具（适合重装或出错时使用）。
*   **执行动作**：
    *   停止并删除 Dockge 和 Cloudflare Tunnel 容器。
    *   删除 `/opt/dockge` 和 `/opt/stacks` 数据目录。
    *   (可选交互) 彻底卸载 Docker 引擎。

## 📂 目录结构说明

本脚本遵循“数据持久化”原则，所有重要数据均存储在 `/opt` 目录下：

```text
/opt/
├── dockge/           # Dockge 面板主目录
│   ├── compose.yaml  # Dockge 自身的启动配置
│   └── data/         # Dockge 的数据库和配置存储
│
└── stacks/           # 【核心目录】所有 Docker 应用的存放地
    └── cf-tunnel/    # Cloudflare Tunnel 的配置文件
```

## ⚠️ 常见问题与注意事项

1.  **权限要求**：必须使用 `root` 权限运行脚本 (`sudo -i`)。
2.  **系统支持**：测试通过系统：Debian 11/12, Ubuntu 20.04/22.04。CentOS 7 可能需要额外配置内核。
3.  **端口安全**：
    *   在配置完 Cloudflare Tunnel 后，建议使用防火墙（如 UFW）封锁 VPS 的 `5001` 端口。
    *   命令：`ufw deny 5001`。
    *   这样仅允许通过域名访问，防止直接通过 IP 扫描攻击。

---
**License**: MIT
```