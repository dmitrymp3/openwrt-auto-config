#!/bin/sh
# setup.sh — Автонастройка OpenWrt роутера
# Запуск (скачать, потом выполнить — нужен интерактивный ввод):
#   wget -O /tmp/setup.sh "https://raw.githubusercontent.com/dmitrymp3/openwrt-auto-config/refs/heads/main/setup.sh?$(date +%s)" && sh /tmp/setup.sh

VERSION="1.17"

# ── Константы ──────────────────────────────────────────────────────────────────
SUB_NAME="mp3-rules"   # имя подписки OpenClash (используется в UCI и при обновлении)

log()  { echo ">>> $*"; }
ok()   { echo "    OK: $*"; }
fail() { echo "    ОШИБКА: $*"; exit 1; }

# ── Параметры ─────────────────────────────────────────────────────────────────
# Использование (все флаги опциональны, порядок не важен):
#   sh setup.sh [--generate] [--ssid NAME] [--pass PASS] [--admin PASS] [--sub URL] [--subnet N]
#
# --generate    сгенерировать случайные SSID (FD-XX) и пароли
# --ssid NAME   имя Wi-Fi сети          (по умолчанию: FreeDom)
# --pass PASS   пароль Wi-Fi            (по умолчанию: 88888888)
# --admin PASS  пароль root             (по умолчанию: не менять)
# --sub URL     URL подписки Remnawave  (по умолчанию: не добавлять)
# --subnet N    третий октет подсети    (например: 15 → 192.168.15.1, по умолчанию: не менять)
# --del-rule    удалить bootstrap firewall правило 'bootstrap-wan-allow' (если есть)

WIFI_SSID="FreeDom"
WIFI_PASS="88888888"
ADMIN_PASS=""
SUB_URL=""
SUBNET=""
GENERATE=0
DEL_RULE=0
ALLOW_WAN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --generate)   GENERATE=1; shift ;;
        --ssid)       WIFI_SSID="$2"; shift 2 ;;
        --pass)       WIFI_PASS="$2"; shift 2 ;;
        --admin)      ADMIN_PASS="$2"; shift 2 ;;
        --sub)        SUB_URL="$2"; shift 2 ;;
        --subnet)     SUBNET="$2"; shift 2 ;;
        --del-rule)   DEL_RULE=1; shift ;;
        --allow-wan)  ALLOW_WAN=1; shift ;;
        *) echo "Неизвестный параметр: $1"; exit 1 ;;
    esac
done

if [ "$GENERATE" = "1" ]; then
    WIFI_SSID="FD-$(cat /dev/urandom | tr -dc '0-9' | head -c 2)"
    WIFI_PASS=$(cat /dev/urandom | tr -dc '0-9' | head -c 8)
fi

# Пароль root генерируется всегда если не задан явно (10 букв+цифр + 2 спецсимвола)
if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS="$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10)$(cat /dev/urandom | tr -dc '!@#%^*_+=' | head -c 2)"
fi

echo ""
echo "====================================="
echo "  OpenWrt auto-config setup script"
echo "  v$VERSION"
echo "====================================="
echo "  SSID:       $WIFI_SSID"
echo "  Wi-Fi pass: $WIFI_PASS"
echo "  Admin pass: $ADMIN_PASS"
if [ -n "$SUBNET" ]; then
echo "  Subnet:     192.168.$SUBNET.0/24"
fi
if [ -n "$SUB_URL" ]; then
echo "  Sub URL:    $SUB_URL"
fi
echo "====================================="
echo ""

# ── Шаг 1: LAN подсеть (только staging, без применения) ─────────────────────
if [ -n "$SUBNET" ]; then
    log "Шаг 1: Подготовка LAN подсети (192.168.$SUBNET.0/24)..."
    uci set network.lan.ipaddr="192.168.$SUBNET.1/24" && ok "ipaddr = 192.168.$SUBNET.1/24" || fail "uci set ipaddr"
else
    log "Шаг 1: --subnet не передан, LAN не меняем"
fi

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

# commit и reload — в самом конце скрипта

echo ""

# ── Шаг 3: SSH-ключ ──────────────────────────────────────────────────────────
log "Шаг 3: Установка SSH-ключа..."
mkdir -p /etc/dropbear
wget -qO /etc/dropbear/authorized_keys \
    "https://raw.githubusercontent.com/dmitrymp3/openwrt-auto-config/refs/heads/main/authorized_keys" \
    && ok "SSH-ключ установлен" || fail "wget authorized_keys"
chmod 600 /etc/dropbear/authorized_keys

# ── Шаг 4: Пароль root ───────────────────────────────────────────────────────
log "Шаг 4: Установка пароля root..."
printf '%s\n%s\n' "$ADMIN_PASS" "$ADMIN_PASS" | passwd root && ok "пароль установлен" || fail "passwd root"

# ── Шаг 4: Пакеты ────────────────────────────────────────────────────────────
log "Шаг 4: Установка пакетов..."

# Firewall может блокировать wget при установке kmod-модулей (EPERM).
# Временно останавливаем его на время установки пакетов.
/etc/init.d/firewall stop 2>/dev/null; ok "firewall остановлен"

apk update && ok "apk update" || fail "apk update"
apk add bash iptables dnsmasq-full curl ca-bundle ipset ip-full \
    iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun \
    kmod-inet-diag unzip luci-compat luci luci-base \
    && ok "пакеты установлены" || fail "apk add"

/etc/init.d/firewall start 2>/dev/null; ok "firewall запущен"

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
    uci set openclash.@config_subscribe[-1].name="$SUB_NAME"
    uci set openclash.@config_subscribe[-1].address="$SUB_URL"
    uci set openclash.@config_subscribe[-1].sub_ua='clash-verge/v2.4.5'
    uci set openclash.@config_subscribe[-1].sub_convert='0'
    uci commit openclash && ok "подписка добавлена" || fail "uci commit openclash"
else
    log "Шаг 7: sub_url не передан, пропускаем подписку"
fi

# ── Шаг 8: Запуск и автообновление OpenClash ─────────────────────────────────
log "Шаг 8: Настройка и запуск OpenClash..."
uci set openclash.config.enable='1'
uci set openclash.config.auto_update='1'
uci set openclash.config.auto_update_time='60'
uci set openclash.config.config_auto_update_mode='1'
uci set openclash.config.config_update_interval='60'
uci commit openclash && ok "OpenClash включён, автообновление 60 мин" || fail "uci commit openclash"
log "Пауза 10 сек перед загрузкой конфига подписки..."
sleep 10
bash /usr/share/openclash/openclash.sh "$SUB_NAME" && ok "конфиг подписки загружен" || ok "конфиг подписки: см. лог /tmp/openclash.log"

# ── Шаг 9: Удаление bootstrap firewall правила ───────────────────────────────
if [ "$DEL_RULE" = "1" ]; then
    log "Шаг 9: Удаление bootstrap firewall правила..."
    DELETED=0
    for i in $(seq 0 20); do
        name=$(uci get firewall.@rule[$i].name 2>/dev/null) || break
        if [ "$name" = "bootstrap-wan-allow" ]; then
            uci delete firewall.@rule[$i] && ok "правило удалено (индекс $i)" || fail "uci delete firewall.@rule[$i]"
            uci commit firewall && ok "firewall commit" || fail "uci commit firewall"
            /etc/init.d/firewall reload && ok "firewall reload"
            DELETED=1
            break
        fi
    done
    [ "$DELETED" = "0" ] && ok "правило bootstrap-wan-allow не найдено, пропускаем"
else
    log "Шаг 9: --del-rule не передан, firewall правило не трогаем"
fi

# ── Шаг 10: Отключение IPv6 ──────────────────────────────────────────────────
log "Шаг 10: Отключение IPv6 на LAN..."
uci set network.lan.ipv6='0'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci commit dhcp && ok "IPv6 отключён (dhcp commit)"
# network commit — в финальном блоке ниже

# ── Шаг 11: Firewall — разрешить SSH (и опционально веб) с WAN ───────────────
log "Шаг 11: Открытие SSH (порт 22) с WAN..."
uci add firewall rule > /dev/null
uci set firewall.@rule[-1].name='allow-ssh-wan'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall && ok "SSH с WAN разрешён"

if [ "$ALLOW_WAN" = "1" ]; then
    log "Шаг 11: Открытие веб-интерфейса (80/443) с WAN..."
    uci add firewall rule > /dev/null
    uci set firewall.@rule[-1].name='allow-web-wan'
    uci set firewall.@rule[-1].src='wan'
    uci set firewall.@rule[-1].dest_port='443'
    uci set firewall.@rule[-1].proto='tcp'
    uci set firewall.@rule[-1].target='ACCEPT'
    uci commit firewall && ok "веб-интерфейс с WAN разрешён"
fi

# ── Шаг 12: Прочее ───────────────────────────────────────────────────────────
log "Шаг 12: Прочие настройки..."
uci set attendedsysupgrade.client.login_check_for_upgrades='1'
uci commit attendedsysupgrade && ok "attendedsysupgrade настроен"

echo "====================================="
echo "  Готово! Ошибок нет."
echo "====================================="
echo "  Admin pass: $ADMIN_PASS"
echo "====================================="
echo ""

# ── Применение сетевых настроек ──────────────────────────────────────────────
# Все uci commit выполняются здесь — это только запись в файлы, SSH не рвётся.
# Реальный обрыв соединения происходит при reload ниже.
log "Применение сетевых настроек..."

uci commit network  && ok "network commit"
uci commit wireless && ok "wireless commit"

echo ""
echo "====================================="
echo "  ⚠  Сетевые настройки применяются."
echo "     Соединение МОЖЕТ оборваться."
if [ -n "$SUBNET" ]; then
echo "     Новый LAN: 192.168.$SUBNET.1"
fi
echo "     Wi-Fi SSID: $WIFI_SSID"
echo "     Wi-Fi pass: $WIFI_PASS"
echo "====================================="
echo ""

# Запускаем reload отвязанно от терминала — SIGHUP при обрыве SSH не убьёт процесс
( /etc/init.d/network reload; wifi reload ) </dev/null >/tmp/network-reload.log 2>&1 &
