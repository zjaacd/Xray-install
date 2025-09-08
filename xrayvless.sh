#!/bin/bash
set -e

#====== 彩色输出函数 ======
green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

#====== 安装依赖 ======
sudo apt update -y >/dev/null 2>&1
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

#====== 安装并配置 VLESS Reality 节点（全自动） ======
install_vless_reality() {
  check_and_install_xray
  XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")

  # ===== 默认参数 =====
  PORT=443
  REMARK="VLESSNode"
  UUID="123e6666-e89b-12d3-a666-888888889999"
  SNI="www.cloudflare.com"
  SHORT_ID=$(head -c 4 /dev/urandom | xxd -p)

  KEYS=$($XRAY_BIN x25519)
  PRIV_KEY=$(echo "$KEYS" | awk '/Private/ {print $3}')
  PUB_KEY=$(echo "$KEYS" | awk '/Public/ {print $3}')

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

  green "✅ VLESS Reality 节点已安装完成！"
  green "🎯 节点链接如下："
  echo "$LINK"

  # 可选：写入文件
  echo "$LINK" > /root/vless_link.txt
  green "📄 节点链接已保存到 /root/vless_link.txt"
}

#====== 执行 ======
install_vless_reality
