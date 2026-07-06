#!/bin/sh
# setup.sh — Автонастройка OpenWrt роутера
# Запуск: wget -qO- https://raw.githubusercontent.com/USER/REPO/main/setup.sh | sh

# ── Шаг 1: LAN подсеть ───────────────────────────────────────────────────────
uci set network.lan.ipaddr='192.168.10.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network reload

echo "LAN: $(uci get network.lan.ipaddr)/$(uci get network.lan.netmask)"

# ── Шаг 2: Пароль root ───────────────────────────────────────────────────────
# echo "root:ПАРОЛЬ" | chpasswd

# ── Шаг 3: Пакеты ────────────────────────────────────────────────────────────
# apk update
# apk add curl kmod-tun bash coreutils ca-bundle ruby ruby-yaml

# ── Шаг 4: OpenClash ─────────────────────────────────────────────────────────
# curl -sSL -o /tmp/openclash.ipk "https://github.com/vernesong/OpenClash/releases/..."
# apk add --allow-untrusted /tmp/openclash.ipk

# ── Шаг 5: Mihomo core ───────────────────────────────────────────────────────
# curl -sSL -o /tmp/mihomo.gz "https://github.com/MetaCubeX/mihomo/releases/..."
# gunzip /tmp/mihomo.gz && mv /tmp/mihomo /etc/openclash/core/clash
# chmod +x /etc/openclash/core/clash

# ── Шаг 6: Конфиг OpenClash ──────────────────────────────────────────────────
# curl -sSL -o /etc/openclash/config.yaml "$SUB_URL"

# ── Шаг 7: Wi-Fi ─────────────────────────────────────────────────────────────
# uci set wireless.radio0.disabled=0
# uci set wireless.default_radio0.ssid="SSID"
# uci set wireless.default_radio0.key="PASS"
# uci set wireless.default_radio0.encryption=psk2
# uci commit wireless && wifi reload
