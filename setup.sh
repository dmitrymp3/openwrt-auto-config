#!/bin/sh
# setup.sh — Автонастройка OpenWrt роутера
# Запуск (скачать, потом выполнить — нужен интерактивный ввод):
#   curl -sSL "https://raw.githubusercontent.com/USER/REPO/main/setup.sh" -o /tmp/setup.sh && sh /tmp/setup.sh

# ── Шаг 1: LAN подсеть ───────────────────────────────────────────────────────
uci set network.lan.ipaddr='192.168.10.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network reload

echo "LAN: $(uci get network.lan.ipaddr)/$(uci get network.lan.netmask)"

# ── Шаг 2: Wi-Fi ─────────────────────────────────────────────────────────────
printf "Wi-Fi SSID [FreeDom]: " > /dev/tty
read WIFI_SSID < /dev/tty
WIFI_SSID="${WIFI_SSID:-FreeDom}"

printf "Wi-Fi пароль [88888888]: " > /dev/tty
read WIFI_PASS < /dev/tty
WIFI_PASS="${WIFI_PASS:-88888888}"

uci set wireless.radio0.disabled=0
uci set wireless.default_radio0.ssid="$WIFI_SSID"
uci set wireless.default_radio0.key="$WIFI_PASS"
uci set wireless.default_radio0.encryption=psk2

uci set wireless.radio1.disabled=0
uci set wireless.default_radio1.ssid="$WIFI_SSID"
uci set wireless.default_radio1.key="$WIFI_PASS"
uci set wireless.default_radio1.encryption=psk2

uci commit wireless
wifi reload

echo "Wi-Fi: $WIFI_SSID / $WIFI_PASS"

# ── Шаг 3: Пароль root ───────────────────────────────────────────────────────
# echo "root:ПАРОЛЬ" | chpasswd

# ── Шаг 4: Пакеты ────────────────────────────────────────────────────────────
# apk update
# apk add curl kmod-tun bash coreutils ca-bundle ruby ruby-yaml

# ── Шаг 5: OpenClash ─────────────────────────────────────────────────────────
# curl -sSL -o /tmp/openclash.ipk "https://github.com/vernesong/OpenClash/releases/..."
# apk add --allow-untrusted /tmp/openclash.ipk

# ── Шаг 6: Mihomo core ───────────────────────────────────────────────────────
# curl -sSL -o /tmp/mihomo.gz "https://github.com/MetaCubeX/mihomo/releases/..."
# gunzip /tmp/mihomo.gz && mv /tmp/mihomo /etc/openclash/core/clash
# chmod +x /etc/openclash/core/clash

# ── Шаг 7: Конфиг OpenClash ──────────────────────────────────────────────────
# curl -sSL -o /etc/openclash/config.yaml "$SUB_URL"
