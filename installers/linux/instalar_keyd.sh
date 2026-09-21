#!/usr/bin/env bash
# Instala y configura keyd para separar DOS teclados fisicos en Linux.
#
# Objetivo: que el 2do teclado emita teclas distintas y asi dos jugadores
# puedan usar el mismo layout (p.ej. WASD cada uno en su teclado).
#
# Uso:
#   sudo bash installers/linux/instalar_keyd.sh
#
# Variables opcionales:
#   KB2_ID=<vendor:product>   Id del teclado a remapear (si hay dudas).
#   MAPA=arrows|ijkl          Destino del remapeo (default: arrows).
#   DRY_RUN=1                 Muestra lo que haria, sin tocar el sistema.
#
# Desinstalar: sudo bash installers/linux/desinstalar_keyd.sh
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTOR="$AQUI/../detectar_teclados.py"
MAP_DIR=/etc/keyd
CONF_P2="$MAP_DIR/jugador2-oniet.conf"
CONF_DEFAULT="$MAP_DIR/default.conf"
MAPA="${MAPA:-arrows}"
DRY_RUN="${DRY_RUN:-0}"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mAVISO:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

run() {
	if [[ "$DRY_RUN" == "1" ]]; then
		printf '  [dry-run] %s\n' "$*"
	else
		"$@"
	fi
}

[[ "$(uname -s)" == "Linux" ]] || die "Este instalador es solo para Linux."
[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Ejecutalo con sudo."
command -v python3 >/dev/null 2>&1 || die "Falta python3."

log "Detectando teclados..."
mapfile -t TECLADOS < <(python3 "$DETECTOR" 2>/dev/null || true)
if [[ "${#TECLADOS[@]}" -lt 2 ]]; then
	die "Se necesita mas de un teclado conectado. Detectados: ${#TECLADOS[@]}."
fi

printf '  %s\n' "${TECLADOS[@]}"
IDS=()
for t in "${TECLADOS[@]}"; do
	IDS+=("$(awk '{print $1}' <<<"$t")")
done
if [[ "$(printf '%s\n' "${IDS[@]}" | sort -u | wc -l)" -lt "${#IDS[@]}" ]]; then
	warn "Hay teclados con el MISMO id (modelo identico)."
	warn "keyd no puede distinguirlos. Conecta un teclado de otro modelo"
	warn "o pedi el helper por-dispositivo (evdev/uinput)."
	exit 1
fi

if [[ -n "${KB2_ID:-}" ]]; then
	KB2="$KB2_ID"
else
	KB2="${IDS[1]}"
fi
if [[ ! " ${IDS[*]} " =~ " $KB2 " ]]; then
	die "KB2_ID=$KB2 no esta entre los detectados: ${IDS[*]}"
fi
KB1_EXCLUDE="$KB2"
log "Teclado 2 (se remapea): $KB2"

case "$MAPA" in
	arrows)
		MAPA_TXT=$'w = up\na = left\ns = down\nd = right'
		;;
	ijkl)
		MAPA_TXT=$'w = i\na = j\ns = k\nd = l'
		;;
	*)
		die "MAPA debe ser 'arrows' o 'ijkl' (recibi '$MAPA')."
		;;
esac

if ! command -v keyd >/dev/null 2>&1; then
	log "Instalando keyd..."
	if command -v apt-get >/dev/null 2>&1; then
		run apt-get update -qq || true
		if ! apt-cache show keyd >/dev/null 2>&1; then
			# keyd esta empaquetado en Ubuntu >= 25.04 y Debian >= 13.
			# En versiones anteriores se usa el PPA oficial.
			if command -v add-apt-repository >/dev/null 2>&1; then
				log "Agregando PPA ppa:keyd-team/ppa..."
				run add-apt-repository -y ppa:keyd-team/ppa
				run apt-get update -qq
			fi
		fi
		run apt-get install -y keyd
	else
		die "No encontre apt-get. Instala keyd manualmente desde https://github.com/rvaiya/keyd"
	fi
else
	log "keyd ya esta instalado."
fi

log "Escribiendo configuracion..."
run mkdir -p "$MAP_DIR"
if [[ -f "$CONF_DEFAULT" && "$DRY_RUN" != "1" ]]; then
	cp "$CONF_DEFAULT" "$CONF_DEFAULT.bak.$(date +%Y%m%d%H%M%S)"
fi

# Teclado 1 (y cualquier otro): passthrough, excluyendo el teclado 2.
TMP_DEFAULT="$(mktemp)"
cat >"$TMP_DEFAULT" <<EOF
# Generado por ONIET Rounds. No editar a mano.
# El teclado 2 ($KB2) se remapea en jugador2-oniet.conf.
[ids]
*
-$KB1_EXCLUDE

[main]
EOF

TMP_P2="$(mktemp)"
cat >"$TMP_P2" <<EOF
# Generado por ONIET Rounds. Layout de movimiento para el teclado 2.
[ids]
$KB2

[main]
$MAPA_TXT
EOF

if [[ "$DRY_RUN" == "1" ]]; then
	echo "  [dry-run] escribir $CONF_DEFAULT:"; sed 's/^/    /' "$TMP_DEFAULT"
	echo "  [dry-run] escribir $CONF_P2:"; sed 's/^/    /' "$TMP_P2"
else
	install -m 0644 "$TMP_DEFAULT" "$CONF_DEFAULT"
	install -m 0644 "$TMP_P2" "$CONF_P2"
fi
rm -f "$TMP_DEFAULT" "$TMP_P2"

if command -v keyd >/dev/null 2>&1; then
	log "Validando configuracion..."
	if ! run keyd check; then
		run rm -f "$CONF_P2"
		die "Config invalida; se revirtio $CONF_P2. Revisa 'keyd check'."
	fi
	log "Activando servicio keyd..."
	run systemctl enable --now keyd
	run keyd reload
fi

cat <<EOF

Listo. El teclado 2 ahora emite: $(tr '\n' ' ' <<<"$MAPA_TXT")

Probar:            sudo keyd monitor
Ver estado:        systemctl status keyd
Desinstalar:       sudo bash installers/linux/desinstalar_keyd.sh
Panico (si algo sale mal): presionar backspace+escape+enter
EOF
