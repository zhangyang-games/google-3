#!/bin/bash

# ==============================================================================
# 数字主权复兴：谷歌云低熵生存节点一键部署向导
# 包含：Caddy自动HTTPS底座 + Memos碎片 + Joplin(WebDAV) + Gitea(私有闭环)
# ==============================================================================

# 颜色定义，让终端交互具备美感
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 确保以 root 权限运行
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误：请使用 sudo -i 切换到 root 用户后执行此脚本。${NC}" 1>&2
   exit 1
fi

# 显示主菜单
show_menu() {
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${GREEN}      谷歌云超级三剑客：低能耗自组织节点部署向导      ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${YELLOW}请选择你要执行的造物指令：${NC}"
    echo ""
    echo "  1) 🧱 部署基石：安装 Docker 与 Caddy (自动申请证书的网关)"
    echo "  2) 📝 部署 Memos (知识碎片闪念胶囊)"
    echo "  3) 📓 部署 Joplin (WebDAV 纯文本避难所)"
    echo "  4) 🐙 部署 Gitea (单人绝对私有代码孤岛)"
    echo "  5) 🔄 重载路由：重载 Caddy 配置使其立即生效"
    echo "  0) 🚪 退出系统"
    echo ""
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${YELLOW}注意: GCP后台防火墙务必已放行 80, 443 以及 222(Git SSH) 端口${NC}"
}

# 1. 部署基石
install_base() {
    echo -e "${GREEN}正在浇筑底层建筑 (Docker & Caddy)...${NC}"
    apt update -y
    apt install -y docker.io debian-keyring debian-archive-keyring apt-transport-https curl
    systemctl enable --now docker

    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update -y
    apt install caddy -y

    # 清空默认的 Caddyfile，准备迎接我们的自定义秩序
    > /etc/caddy/Caddyfile
    systemctl enable --now caddy
    echo -e "${GREEN}底座搭建完毕！Docker 与 Caddy 正在静默运行。${NC}"
    sleep 2
}

# 2. 部署 Memos
install_memos() {
    echo -e "${CYAN}准备部署 Memos...${NC}"
    read -p "请输入已解析到本机IP的 Memos 域名 (如 memos.xccop.eu.org): " DOMAIN
    if [ -z "$DOMAIN" ]; then echo -e "${RED}域名不能为空！${NC}"; sleep 2; return; fi

    docker run -d --init --name memos --restart always -p 5230:5230 -v /root/.memos/:/var/opt/memos neosmemo/memos:0.21.0
    
    echo "$DOMAIN {" >> /etc/caddy/Caddyfile
    echo "    reverse_proxy 127.0.0.1:5230" >> /etc/caddy/Caddyfile
    echo "}" >> /etc/caddy/Caddyfile
    echo "" >> /etc/caddy/Caddyfile
    
    echo -e "${GREEN}Memos 容器启动成功，路由已登记！${NC}"
    sleep 2
}

# 3. 部署 Joplin (WebDAV)
install_joplin() {
    echo -e "${CYAN}准备部署 Joplin 同步节点 (WebDAV)...${NC}"
    read -p "请输入已解析的 Joplin 域名 (如 note.xccop.eu.org): " DOMAIN
    read -p "请设定你的 WebDAV 用户名: " WEBDAV_USER
    read -p "请设定你的 WebDAV 密码: " WEBDAV_PASS
    
    if [ -z "$DOMAIN" ] || [ -z "$WEBDAV_USER" ] || [ -z "$WEBDAV_PASS" ]; then 
        echo -e "${RED}所有信息均为必填项！${NC}"; sleep 2; return; 
    fi

    mkdir -p /root/joplin_data
    # 使用单引号强行封印密码变量，防止 Shell 拦截特殊符号
    docker run -d --name joplin-webdav --restart always -p 8080:80 -e USERNAME="$WEBDAV_USER" -e PASSWORD="$WEBDAV_PASS" -v /root/joplin_data:/webdav ugeek/webdav:amd64

    echo "$DOMAIN {" >> /etc/caddy/Caddyfile
    echo "    reverse_proxy 127.0.0.1:8080" >> /etc/caddy/Caddyfile
    echo "}" >> /etc/caddy/Caddyfile
    echo "" >> /etc/caddy/Caddyfile

    echo -e "${GREEN}WebDAV 堡垒已升起，路由已登记！${NC}"
    sleep 2
}

# 4. 部署 Gitea (关闭注册)
install_gitea() {
    echo -e "${CYAN}准备部署 Gitea 私密代码仓库...${NC}"
    read -p "请输入已解析的 Gitea 域名 (如 git.xccop.eu.org): " DOMAIN
    if [ -z "$DOMAIN" ]; then echo -e "${RED}域名不能为空！${NC}"; sleep 2; return; fi

    mkdir -p /root/gitea
    
    # 核心魔法：使用 GITEA__service__DISABLE_REGISTRATION=true 环境变量
    # 强制在容器诞生之初就彻底关闭注册通道，无需等待 app.ini 生成后再去手动修改
    docker run -d --name=gitea --restart=always -p 3000:3000 -p 222:22 \
      -v /root/gitea:/data \
      -e USER_UID=1000 \
      -e USER_GID=1000 \
      -e GITEA__service__DISABLE_REGISTRATION=true \
      gitea/gitea:latest

    echo "$DOMAIN {" >> /etc/caddy/Caddyfile
    echo "    reverse_proxy 127.0.0.1:3000" >> /etc/caddy/Caddyfile
    echo "}" >> /etc/caddy/Caddyfile
    echo "" >> /etc/caddy/Caddyfile

    echo -e "${GREEN}Gitea 部署完毕，对外围注册渠道已做物理切断！${NC}"
    sleep 2
}

# 5. 重载 Caddy
reload_caddy() {
    caddy reload --config /etc/caddy/Caddyfile
    echo -e "${YELLOW}网关路由重载完成，自动 HTTPS 证书正在申请中（稍等片刻即可用浏览器访问）。${NC}"
    sleep 3
}

# 主循环
while true; do
    show_menu
    read -p "请输入对应的数字键 (0-5): " choice
    case $choice in
        1) install_base ;;
        2) install_memos ;;
        3) install_joplin ;;
        4) install_gitea ;;
        5) reload_caddy ;;
        0) echo -e "${CYAN}系统退出，愿你在数字废土中保持自由。${NC}"; exit 0 ;;
        *) echo -e "${RED}无效输入，请重新选择。${NC}"; sleep 1 ;;
    esac
done
