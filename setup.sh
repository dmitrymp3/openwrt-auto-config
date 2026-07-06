#!/bin/sh
# setup.sh — Настройка OpenWrt роутера с OpenClash + Remnawave
#
# Запуск на роутере:
#   wget -qO /tmp/setup.sh https://raw.githubusercontent.com/USER/REPO/main/setup.sh
#   sh /tmp/setup.sh <subscription_url> [wifi_ssid] [wifi_pass] [admin_pass]
#
# Аргументы:
#   $1 - Subscription URL из Remnawave (обязательно)
#   $2 - Wi-Fi SSID              (по умолчанию: VPN_Router)
#   $3 - Wi-Fi пароль            (по умолчанию: changeme123)
#   $4 - Пароль admin/root       (по умолчанию: не менять)

SUB_URL="$1"
WIFI_SSID="${2:-VPN_Router}"
WIFI_PASS="${3:-changeme123}"
ADMIN_PASS="$4"

OPENCLASH_VER="0.47.110"
OPENCLASH_URL="https://github.com/vernesong/OpenClash/releases/download/v${OPENCLASH_VER}/luci-app-openclash_${OPENCLASH_VER}-beta_all.ipk"
MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-arm64.gz"

# ── Цвета ────────────────────────────────────────────────────────────────────
B='\033[0;34m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'
log() { printf "${B}▶ %s${N}\n" "$*"; }
ok()  { printf "${G}✓ %s${N}\n" "$*"; }
warn(){ printf "${Y}⚠ %s${N}\n" "$*"; }
die() { printf "${R}✗ %s${N}\n" "$*"; exit 1; }

# ── Проверка аргументов ───────────────────────────────────────────────────────
[ -z "$SUB_URL" ] && die "Укажи subscription URL первым аргументом"

printf "\n${B}════════════════════════════════════${N}\n"
printf "${B}  OpenClash setup for Remnawave${N}\n"
printf "${B}════════════════════════════════════${N}\n\n"

# ── 1. Пароль ─────────────────────────────────────────────────────────────────
if [ -n "$ADMIN_PASS" ]; then
    log "Установка пароля root..."
    printf "root:%s" "$ADMIN_PASS" | chpasswd
    ok "Пароль установлен"
fi

# ── 2. Пакеты ─────────────────────────────────────────────────────────────────
log "Обновление пакетов apk..."
apk update --quiet

log "Установка зависимостей..."
apk add --quiet curl kmod-tun bash coreutils ca-bundle ipset ip-full iptables
# ruby нужен для обработки конфига OpenClash
apk add --quiet ruby ruby-yaml 2>/dev/null && ok "ruby установлен" || warn "ruby не найден в репозитории"
ok "Зависимости установлены"

# ── 3. OpenClash ──────────────────────────────────────────────────────────────
log "Скачивание OpenClash v${OPENCLASH_VER}..."
curl -sSL -o /tmp/openclash.ipk "$OPENCLASH_URL" || die "Не удалось скачать OpenClash"

log "Установка OpenClash..."
apk add --quiet --allow-untrusted /tmp/openclash.ipk || die "Установка OpenClash не удалась"
rm /tmp/openclash.ipk
ok "OpenClash установлен"

# ── 4. Mihomo ядро ────────────────────────────────────────────────────────────
log "Скачивание mihomo Meta core (arm64)..."
mkdir -p /etc/openclash/core
curl -sSL -o /tmp/mihomo.gz "$MIHOMO_URL" || die "Не удалось скачать mihomo"
gunzip -f /tmp/mihomo.gz
mv /tmp/mihomo /etc/openclash/core/clash
chmod +x /etc/openclash/core/clash
CORE_VER=$(/etc/openclash/core/clash -v 2>&1 | head -1)
ok "Ядро: $CORE_VER"

# ── 5. Конфиг из Remnawave ────────────────────────────────────────────────────
log "Загрузка конфига из подписки..."
mkdir -p /etc/openclash
curl -sSL -o /etc/openclash/config.yaml "$SUB_URL" || die "Не удалось загрузить конфиг"
LINES=$(wc -l < /etc/openclash/config.yaml)
ok "Конфиг загружен ($LINES строк)"

# ── 6. Cron: авто-обновление конфига ─────────────────────────────────────────
log "Настройка авто-обновления конфига (каждые 6 часов)..."
(crontab -l 2>/dev/null | grep -v 'openclash.*config.yaml'
 printf "0 */6 * * * curl -sSL -o /etc/openclash/config.yaml '%s' && /etc/init.d/openclash restart\n" "$SUB_URL") \
 | crontab -
ok "Cron настроен"

# ── 7. Wi-Fi ──────────────────────────────────────────────────────────────────
log "Настройка Wi-Fi..."
uci set wireless.radio0.disabled=0
uci set wireless.default_radio0.ssid="$WIFI_SSID"
uci set wireless.default_radio0.key="$WIFI_PASS"
uci set wireless.default_radio0.encryption=psk2
uci set wireless.radio1.disabled=0
uci set wireless.default_radio1.ssid="${WIFI_SSID}_5G"
uci set wireless.default_radio1.key="$WIFI_PASS"
uci set wireless.default_radio1.encryption=psk2
uci commit wireless
wifi reload 2>/dev/null || true
ok "Wi-Fi: ${WIFI_SSID} / ${WIFI_SSID}_5G"

# ── 8. Перезапуск LuCI ───────────────────────────────────────────────────────
log "Обновление LuCI..."
rm -rf /tmp/luci-*
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true

# ── 9. Запуск OpenClash ───────────────────────────────────────────────────────
log "Включение OpenClash..."
/etc/init.d/openclash enable
/etc/init.d/openclash start 2>/dev/null \
    && ok "OpenClash запущен" \
    || warn "OpenClash не стартовал — запусти вручную в LuCI"

# ── Итог ─────────────────────────────────────────────────────────────────────
printf "\n${G}════════════════════════════════════${N}\n"
printf "${G}  Готово!${N}\n"
printf "${G}  LuCI:   http://192.168.1.1${N}\n"
printf "${G}  Wi-Fi:  %s / %s${N}\n" "$WIFI_SSID" "$WIFI_PASS"
printf "${G}════════════════════════════════════${N}\n\n"
