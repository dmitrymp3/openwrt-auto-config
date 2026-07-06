#!/bin/sh
# setup.sh — Автонастройка OpenWrt роутера
# Запуск (скачать, потом выполнить — нужен интерактивный ввод):
#   wget -O /tmp/setup.sh "https://raw.githubusercontent.com/USER/REPO/main/setup.sh?$(date +%s)" && sh /tmp/setup.sh

log()  { echo ">>> $*"; }
ok()   { echo "    OK: $*"; }
fail() { echo "    ОШИБКА: $*"; exit 1; }

# ── Параметры ─────────────────────────────────────────────────────────────────
# Использование:
#   sh setup.sh generate                     — сгенерировать SSID, пароли
#   sh setup.sh <ssid> <wifi_pass> <admin_pass> — задать вручную
if [ "$1" = "generate" ]; then
    WIFI_SSID="FD-$(cat /dev/urandom | tr -dc '0-9' | head -c 2)"
    WIFI_PASS=$(cat /dev/urandom | tr -dc '0-9' | head -c 8)
    ADMIN_PASS=$(cat /dev/urandom | tr -dc '0-9' | head -c 8)
else
    WIFI_SSID="${1:-FreeDom}"
    WIFI_PASS="${2:-88888888}"
    ADMIN_PASS="${3:-}"
fi

echo ""
echo "====================================="
echo "  OpenWrt auto-config setup script"
echo "====================================="
echo "  SSID:       $WIFI_SSID"
echo "  Wi-Fi pass: $WIFI_PASS"
if [ -n "$ADMIN_PASS" ]; then
echo "  Admin pass: $ADMIN_PASS"
fi
echo "====================================="
echo ""

# ── Шаг 1: LAN подсеть ───────────────────────────────────────────────────────
log "Шаг 1: Настройка LAN подсети..."

uci set network.lan.ipaddr='192.168.10.1' && ok "ipaddr = 192.168.10.1" || fail "uci set ipaddr"
uci set network.lan.netmask='255.255.255.0' && ok "netmask = 255.255.255.0" || fail "uci set netmask"
uci commit network && ok "network commit" || fail "uci commit network"
/etc/init.d/network reload && ok "network reload" || fail "network reload"

echo ""

# ── Шаг 2: Wi-Fi ─────────────────────────────────────────────────────────────
log "Шаг 2: Настройка Wi-Fi..."

uci set wireless.radio0.disabled=0
uci set wireless.default_radio0.ssid="$WIFI_SSID"
uci set wireless.default_radio0.key="$WIFI_PASS"
uci set wireless.default_radio0.encryption=psk2
uci set wireless.radio1.disabled=0
uci set wireless.default_radio1.ssid="$WIFI_SSID"
uci set wireless.default_radio1.key="$WIFI_PASS"
uci set wireless.default_radio1.encryption=psk2
uci commit wireless && ok "wireless commit" || fail "uci commit wireless"
wifi reload && ok "wifi reload" || fail "wifi reload"

echo ""

# ── Шаг 3: Пароль root ───────────────────────────────────────────────────────
# log "Шаг 3: Установка пароля root..."
# echo "root:ПАРОЛЬ" | chpasswd && ok "пароль установлен" || fail "chpasswd"

# ── Шаг 4: Пакеты ────────────────────────────────────────────────────────────
# log "Шаг 4: Установка пакетов..."
# apk update && ok "apk update" || fail "apk update"
# apk add curl kmod-tun bash coreutils ca-bundle ruby ruby-yaml && ok "пакеты установлены" || fail "apk add"

# ── Шаг 5: OpenClash ─────────────────────────────────────────────────────────
# log "Шаг 5: Установка OpenClash..."
# wget -O /tmp/openclash.ipk "https://github.com/vernesong/OpenClash/releases/..." && ok "IPK скачан" || fail "wget openclash"
# apk add --allow-untrusted /tmp/openclash.ipk && ok "OpenClash установлен" || fail "apk add openclash"

# ── Шаг 6: Mihomo core ───────────────────────────────────────────────────────
# log "Шаг 6: Установка mihomo core..."
# wget -O /tmp/mihomo.gz "https://github.com/MetaCubeX/mihomo/releases/..." && ok "mihomo скачан" || fail "wget mihomo"
# gunzip /tmp/mihomo.gz && mv /tmp/mihomo /etc/openclash/core/clash
# chmod +x /etc/openclash/core/clash && ok "mihomo готов" || fail "mihomo setup"

# ── Шаг 7: Конфиг OpenClash ──────────────────────────────────────────────────
# log "Шаг 7: Загрузка конфига OpenClash..."
# wget -O /etc/openclash/config.yaml "$SUB_URL" && ok "конфиг загружен" || fail "wget config"

echo "====================================="
echo "  Готово! Ошибок нет."
echo "====================================="
echo ""
