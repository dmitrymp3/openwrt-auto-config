#!/bin/sh
# setup.sh — Автонастройка OpenWrt роутера
# Запуск (скачать, потом выполнить — нужен интерактивный ввод):
#   wget -O /tmp/setup.sh "https://raw.githubusercontent.com/dmitrymp3/openwrt-auto-config/refs/heads/main/setup.sh?$(date +%s)" && sh /tmp/setup.sh

VERSION="1.3"

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
echo "  v$VERSION"
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
# Интерфейсы специфичны для QWRT на WH3000 PRO (MediaTek mt_dbdc драйвер):
#   ra / ra0  — 2.4GHz
#   rax / rax0 — 5GHz
log "Шаг 2: Настройка Wi-Fi 2.4GHz (ra0)..."

uci set wireless.ra0.ssid="$WIFI_SSID" && ok "2.4G ssid = $WIFI_SSID" || fail "uci set ra0 ssid"
uci set wireless.ra0.encryption='psk2'  && ok "2.4G encryption = psk2" || fail "uci set ra0 encryption"
uci set wireless.ra0.key="$WIFI_PASS"   && ok "2.4G key set"           || fail "uci set ra0 key"

log "Шаг 2: Настройка Wi-Fi 5GHz (rax0)..."

uci set wireless.rax0.ssid="$WIFI_SSID" && ok "5G ssid = $WIFI_SSID" || fail "uci set rax0 ssid"
uci set wireless.rax0.encryption='psk2'  && ok "5G encryption = psk2" || fail "uci set rax0 encryption"
uci set wireless.rax0.key="$WIFI_PASS"   && ok "5G key set"           || fail "uci set rax0 key"

uci commit wireless && ok "wireless commit" || fail "uci commit wireless"
wifi reload && ok "wifi reload" || fail "wifi reload"

echo ""

# ── Шаг 3: Пароль root ───────────────────────────────────────────────────────
# log "Шаг 3: Установка пароля root..."
# echo "root:ПАРОЛЬ" | chpasswd && ok "пароль установлен" || fail "chpasswd"

# ── Шаг 4: Пакеты ────────────────────────────────────────────────────────────
log "Шаг 4: Установка пакетов..."

apk update && ok "apk update" || fail "apk update"
apk add bash iptables dnsmasq-full curl ca-bundle ipset ip-full \
    iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun \
    kmod-inet-diag unzip luci-compat luci luci-base \
    && ok "пакеты установлены" || fail "apk add"

echo ""

# ── Шаг 5: OpenClash ─────────────────────────────────────────────────────────
log "Шаг 5: Установка OpenClash..."

curl -L --retry 2 https://api.github.com/repos/vernesong/OpenClash/releases/latest \
    -o /tmp/openclash_version && ok "версия получена" || fail "получение версии OpenClash"

download_url=$(cat /tmp/openclash_version | jsonfilter -e '@.assets[*].browser_download_url' | grep '\.apk$')
[ -n "$download_url" ] && ok "URL: $download_url" || fail "URL .apk не найден"

curl -L --retry 2 "$download_url" -o /tmp/openclash.apk && ok "OpenClash скачан" || fail "скачивание OpenClash"

apk add -q --force-overwrite --clean-protected --allow-untrusted /tmp/openclash.apk \
    && ok "OpenClash установлен" || fail "установка OpenClash"

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
