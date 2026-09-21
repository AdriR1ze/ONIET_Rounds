#!/usr/bin/env bash
# Revierte lo que hizo instalar_keyd.sh.
#   sudo bash installers/linux/desinstalar_keyd.sh
#
# Por defecto NO desinstala keyd (puede que lo uses para otra cosa).
# Para desinstalarlo tambien:  QUITAR_KEYD=1 sudo -E bash installers/linux/desinstalar_keyd.sh
set -euo pipefail

MAP_DIR=/etc/keyd
CONF_P2="$MAP_DIR/jugador2-oniet.conf"
CONF_DEFAULT="$MAP_DIR/default.conf"
QUITAR_KEYD="${QUITAR_KEYD:-0}"

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Ejecutalo con sudo."

if [[ -f "$CONF_P2" ]]; then
	log "Eliminando $CONF_P2"
	rm -f "$CONF_P2"
fi

ULTIMO_BAK="$(ls -1t "$CONF_DEFAULT".bak.* 2>/dev/null | head -n1 || true)"
if [[ -n "$ULTIMO_BAK" ]]; then
	log "Restaurando respaldo $ULTIMO_BAK"
	mv -f "$ULTIMO_BAK" "$CONF_DEFAULT"
else
	log "Sin respaldo: dejo $CONF_DEFAULT como estaba."
fi

if command -v keyd >/dev/null 2>&1; then
	keyd reload 2>/dev/null || systemctl restart keyd 2>/dev/null || true
fi

if [[ "$QUITAR_KEYD" == "1" ]] && command -v apt-get >/dev/null 2>&1; then
	log "Desinstalando keyd..."
	apt-get remove -y keyd || true
fi

log "Listo."
