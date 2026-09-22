#!/usr/bin/env bash
# Verificación de Godot para el flujo agéntico (planner/coder/tester/evaluator).
#
# Uso:
#   bash scripts/godot-check.sh              # valida TODOS los scripts + smoke test
#   bash scripts/godot-check.sh ruta1.gd ...  # lo mismo, exigiendo que esos archivos existan
#
# Variables opcionales:
#   GODOT_BIN      binario de Godot (si no está en PATH se autodetecta)
#   GODOT_PROJECT  ruta al proyecto Godot (por defecto <repo>/rounds)
#
# Sale con 0 si todo compila y no hay errores de script; con 1 si algo falla;
# con 2 si no encuentra el binario de Godot.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${GODOT_PROJECT:-$ROOT/rounds}"

find_godot() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		printf '%s' "$GODOT_BIN"
		return 0
	fi
	local c
	for c in godot godot4 godot-4; do
		if command -v "$c" >/dev/null 2>&1; then
			command -v "$c"
			return 0
		fi
	done
	# Fallback: binario descargado en Downloads (el más nuevo).
	# En WSL/Windows el binario queda en /mnt/c/Users/<usuario>/Downloads.
	local pat dir f
	for pat in 'Godot_v*_win64_console.exe' 'Godot_v*_win64.exe' 'Godot_v*_linux.x86_64'; do
		for dir in "$HOME"/Downloads /mnt/c/Users/*/Downloads; do
			f="$(ls -1 "$dir"/$pat 2>/dev/null | sort -V | tail -1)"
			if [[ -n "$f" && -x "$f" ]]; then
				printf '%s' "$f"
				return 0
			fi
		done
	done
	return 1
}

GODOT="$(find_godot || true)"
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
	echo "ERROR: no encontré el binario de Godot. Definí GODOT_BIN=/ruta/a/godot." >&2
	exit 2
fi

# Godot de Windows no entiende rutas /mnt/c/...: se las traducimos con wslpath.
PROJECT_ARG="$PROJECT"
if [[ "$GODOT" == *.exe && "$PROJECT" == /* ]] && command -v wslpath >/dev/null 2>&1; then
	PROJECT_ARG="$(wslpath -w "$PROJECT")"
fi

echo "Godot:   $GODOT"
echo "Proyecto: $PROJECT"
echo

# 1) Todos los scripts del proyecto deben compilar (autoloads registrados).
echo "== Validando scripts =="
VALIDATE_OUT="$("$GODOT" --headless --path "$PROJECT_ARG" res://tools/validate_all.tscn 2>&1)"
echo "$VALIDATE_OUT" | grep -E '^VALIDATE' || true
if echo "$VALIDATE_OUT" | grep -q 'VALIDATE FAIL' || ! echo "$VALIDATE_OUT" | grep -q '^VALIDATE: checked'; then
	echo "RESULT: FAIL (scripts que no compilan)" >&2
	exit 1
fi

# 2) Smoke test: la escena de gameplay debe arrancar sin errores de script.
echo
echo "== Smoke test (test_level) =="
# timeout no está garantizado en todos los entornos (p.ej. Git Bash): usarlo si existe.
TIMEOUT=""
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT="timeout 90"
fi
SMOKE_OUT="$($TIMEOUT "$GODOT" --headless --path "$PROJECT_ARG" res://levels/test_level.tscn --quit-after 120 2>&1)"
if echo "$SMOKE_OUT" | grep -qE 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script'; then
	echo "$SMOKE_OUT" | grep -E 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script'
	echo "RESULT: FAIL (errores en runtime)" >&2
	exit 1
fi

# 3) Si pidieron archivos puntuales, confirmar que existen.
if [[ "$#" -gt 0 ]]; then
	for f in "$@"; do
		if [[ ! -f "$ROOT/$f" && ! -f "$PROJECT/$f" ]]; then
			echo "RESULT: FAIL (no existe $f)" >&2
			exit 1
		fi
	done
fi

echo
echo "RESULT: PASS"
