#!/bin/bash
set -e

#====== 彩色输出函数 ======
green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

#====== 安装依赖 ======
sudo apt update >/dev/null 2>&1
sudo apt install -y curl wget xz-utils jq xxd >/dev/null 2>&1

#====== 检测并安装 Xray ======
check_and_install_xray() {
  if command -v xray >/dev/null 2>&1; then
    green "✅ Xray 已安装，跳过安装"
  else
    green "❗检测到 Xray 未安装，正在安装..."
    bash <(curl -Ls https://github.com/zjaacd/Xray-install/raw/main/install-release.sh)
    XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
    if [ ! -x "$XRAY_BIN" ]; then
      red "❌ Xray 安装失败，请检查"
      exit 1
    fi
    green "✅ Xray 安装完成"
  fi
}

#====== 安装并配置 VLESS Reality 节点 ======
install_vless_reality() {
  check_and_install_xray
  XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")

  read -rp "监听端口（如 443）: " PORT
  read -rp "节点备注: " REMARK

  UUID="123e4567-e89b-12d3-a456-426655440000"
  KEYS=$($XRAY_BIN x25519)
  PRIV_KEY=$(echo "$KEYS" | awk '/Private/ {print $3}')
  PUB_KEY=$(echo "$KEYS" | awk '/Public/ {print $3}')
  SHORT_ID=$(head -c 4 /dev/urandom | xxd -p)
  SNI="www.cloudflare.com"

  mkdir -p /usr/local/etc/xray
  cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "$UUID", "email": "$REMARK" }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "$SNI:443",
        "xver": 0,
        "serverNames": ["$SNI"],
        "privateKey": "$PRIV_KEY",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

  systemctl daemon-reexec
  systemctl restart xray
  systemctl enable xray

  IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
  LINK="vless://$UUID@$IP:$PORT?type=tcp&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID#$REMARK"
  green "✅ VLESS Reality 节点链接如下："
  echo "$LINK"
}

#====== 执行 ======
install_vless_reality
