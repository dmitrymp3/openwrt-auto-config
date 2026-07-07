#!/bin/sh
# setup.sh — Автонастройка OpenWrt роутера
# Запуск (скачать, потом выполнить — нужен интерактивный ввод):
#   wget -O /tmp/setup.sh "https://raw.githubusercontent.com/dmitrymp3/openwrt-auto-config/refs/heads/main/setup.sh?$(date +%s)" && sh /tmp/setup.sh

VERSION="1.4"

log()  { echo ">>> $*"; }
ok()   { echo "    OK: $*"; }
fail() { echo "    ОШИБКА: $*"; exit 1; }

# ── Параметры ─────────────────────────────────────────────────────────────────
# Использование (все флаги опциональны, порядок не важен):
#   sh setup.sh [--generate] [--ssid NAME] [--pass PASS] [--admin PASS] [--sub URL]
#
# --generate   сгенерировать случайные SSID (FD-XX) и пароли
# --ssid NAME  имя Wi-Fi сети       (по умолчанию: FreeDom)
# --pass PASS  пароль Wi-Fi         (по умолчанию: 88888888)
# --admin PASS пароль root          (по умолчанию: не менять)
# --sub URL    URL подписки Remnawave (по умолчанию: не добавлять)

WIFI_SSID="FreeDom"
WIFI_PASS="88888888"
ADMIN_PASS=""
SUB_URL=""
GENERATE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --generate) GENERATE=1; shift ;;
        --ssid)     WIFI_SSID="$2"; shift 2 ;;
        --pass)     WIFI_PASS="$2"; shift 2 ;;
        --admin)    ADMIN_PASS="$2"; shift 2 ;;
        --sub)      SUB_URL="$2"; shift 2 ;;
        *) echo "Неизвестный параметр: $1"; exit 1 ;;
    esac
done

if [ "$GENERATE" = "1" ]; then
    WIFI_SSID="FD-$(cat /dev/urandom | tr -dc '0-9' | head -c 2)"
    WIFI_PASS=$(cat /dev/urandom | tr -dc '0-9' | head -c 8)
    ADMIN_PASS=$(cat /dev/urandom | tr -dc '0-9' | head -c 8)
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
if [ -n "$SUB_URL" ]; then
echo "  Sub URL:    $SUB_URL"
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
# Стандартные интерфейсы OpenWrt (mac80211):
#   radio0 / default_radio0 — 2.4GHz
#   radio1 / default_radio1 — 5GHz
log "Шаг 2: Настройка Wi-Fi 2.4GHz (radio0)..."

uci set wireless.radio0.disabled='0'          && ok "2.4G radio включён"      || fail "uci set radio0 disabled"
uci set wireless.default_radio0.disabled='0'  && ok "2.4G iface включён"      || fail "uci set default_radio0 disabled"
uci set wireless.default_radio0.ssid="$WIFI_SSID" && ok "2.4G ssid = $WIFI_SSID" || fail "uci set default_radio0 ssid"
uci set wireless.default_radio0.encryption='psk2' && ok "2.4G encryption = psk2" || fail "uci set default_radio0 encryption"
uci set wireless.default_radio0.key="$WIFI_PASS"  && ok "2.4G key set"           || fail "uci set default_radio0 key"

log "Шаг 2: Настройка Wi-Fi 5GHz (radio1)..."

uci set wireless.radio1.disabled='0'          && ok "5G radio включён"        || fail "uci set radio1 disabled"
uci set wireless.default_radio1.disabled='0'  && ok "5G iface включён"        || fail "uci set default_radio1 disabled"
uci set wireless.default_radio1.ssid="$WIFI_SSID" && ok "5G ssid = $WIFI_SSID"   || fail "uci set default_radio1 ssid"
uci set wireless.default_radio1.encryption='psk2' && ok "5G encryption = psk2"   || fail "uci set default_radio1 encryption"
uci set wireless.default_radio1.key="$WIFI_PASS"  && ok "5G key set"             || fail "uci set default_radio1 key"

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

/etc/init.d/rpcd restart && ok "rpcd перезапущен"

# ── Шаг 6: Mihomo core ───────────────────────────────────────────────────────
log "Шаг 6: Установка mihomo core..."
sh /usr/share/openclash/openclash_core.sh Meta && ok "mihomo core установлен" || fail "openclash_core.sh Meta"

# ── Шаг 7: Подписка OpenClash ────────────────────────────────────────────────
if [ -n "$SUB_URL" ]; then
    log "Шаг 7: Добавление подписки OpenClash..."
    uci add openclash config_subscribe > /dev/null
    uci set openclash.@config_subscribe[-1].enabled='1'
    uci set openclash.@config_subscribe[-1].name='remnawave'
    uci set openclash.@config_subscribe[-1].address="$SUB_URL"
    uci set openclash.@config_subscribe[-1].sub_ua='clash-verge/v2.4.5'
    uci set openclash.@config_subscribe[-1].sub_convert='0'
    uci commit openclash && ok "подписка добавлена" || fail "uci commit openclash"
else
    log "Шаг 7: sub_url не передан, пропускаем подписку"
fi

echo "====================================="
echo "  Готово! Ошибок нет."
echo "====================================="
echo ""
