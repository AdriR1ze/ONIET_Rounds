extends Node

const SCRIPT_PATH := "user://oniet_instalar_keyd.sh"
const WINDOWS_HELPER_CS_PATH := "user://OnietRawKeyboardHelper.cs"
const WINDOWS_HELPER_PS_PATH := "user://instalar_raw_keyboard_helper.ps1"
const WINDOWS_HELPER_EXE_PATH := "user://OnietRawKeyboardHelper.exe"
const WINDOWS_CONFIG_PATH := "user://keyboard_setup.cfg"
const WINDOWS_PORT := 38571
const INSTALL_SCRIPT := """#!/usr/bin/env bash
set -euo pipefail

MAP_DIR=/etc/keyd
CONF_P2="$MAP_DIR/jugador2-oniet.conf"
CONF_DEFAULT="$MAP_DIR/default.conf"
MAPA="${MAPA:-arrows}"

log()  { printf '==> %s\\n' "$*"; }
warn() { printf 'AVISO: %s\\n' "$*" >&2; }
die()  { printf 'ERROR: %s\\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || die "Este instalador es solo para Linux."
[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Se necesitan permisos de administrador."
command -v python3 >/dev/null 2>&1 || die "Falta python3."

log "Detectando teclados..."
mapfile -t TECLADOS < <(python3 - <<'PY'
import re
from pathlib import Path

ruta = Path("/proc/bus/input/devices")
excluir = (
	"power button", "sleep button", "lid switch", "video bus", "pc speaker",
	"hdmi", "acpi", "hotkeys", "wmi",
)

if not ruta.exists():
	raise SystemExit(1)

for bloque in ruta.read_text(errors="replace").strip().split("\\n\\n"):
	m_handlers = re.search(r"^H:\\s*Handlers=(.+)$", bloque, re.MULTILINE)
	if not m_handlers or "kbd" not in m_handlers.group(1).split():
		continue
	m_ident = re.search(r"^I:\\s*Bus=\\S+\\s+Vendor=([0-9a-fA-F]{4})\\s+Product=([0-9a-fA-F]{4})", bloque, re.MULTILINE)
	m_nombre = re.search(r'^N:\\s*Name="?(.*?)"?\\s*$', bloque, re.MULTILINE)
	if not m_ident:
		continue
	nombre = m_nombre.group(1) if m_nombre else "?"
	if any(x in nombre.lower() for x in excluir):
		continue
	print("%s:%s  %s" % (m_ident.group(1).lower(), m_ident.group(2).lower(), nombre))
PY
)

if [[ "${#TECLADOS[@]}" -lt 2 ]]; then
	die "Conecta al menos dos teclados. Detectados: ${#TECLADOS[@]}."
fi

printf '  %s\\n' "${TECLADOS[@]}"
IDS=()
for t in "${TECLADOS[@]}"; do
	IDS+=("$(awk '{print $1}' <<<"$t")")
done

if [[ "$(printf '%s\\n' "${IDS[@]}" | sort -u | wc -l)" -lt "${#IDS[@]}" ]]; then
	warn "Hay teclados con el mismo id de modelo."
	warn "keyd no puede distinguir teclados fisicamente identicos."
	exit 1
fi

KB2="${KB2_ID:-${IDS[1]}}"
if [[ ! " ${IDS[*]} " =~ " $KB2 " ]]; then
	die "KB2_ID=$KB2 no esta entre los detectados: ${IDS[*]}"
fi
log "Teclado 2 (se remapea): $KB2"

case "$MAPA" in
	arrows)
		MAPA_TXT=$'w = up\\na = left\\ns = down\\nd = right'
		;;
	ijkl)
		MAPA_TXT=$'w = i\\na = j\\ns = k\\nd = l'
		;;
	*)
		die "MAPA debe ser 'arrows' o 'ijkl'."
		;;
esac

if ! command -v keyd >/dev/null 2>&1; then
	log "Instalando keyd..."
	if command -v apt-get >/dev/null 2>&1; then
		apt-get update -qq || true
		if ! apt-cache show keyd >/dev/null 2>&1; then
			if command -v add-apt-repository >/dev/null 2>&1; then
				log "Agregando PPA ppa:keyd-team/ppa..."
				add-apt-repository -y ppa:keyd-team/ppa
				apt-get update -qq
			fi
		fi
		apt-get install -y keyd
	else
		die "No encontre apt-get. Instala keyd manualmente desde https://github.com/rvaiya/keyd"
	fi
else
	log "keyd ya esta instalado."
fi

log "Escribiendo configuracion..."
mkdir -p "$MAP_DIR"
if [[ -f "$CONF_DEFAULT" ]]; then
	cp "$CONF_DEFAULT" "$CONF_DEFAULT.bak.$(date +%Y%m%d%H%M%S)"
fi

TMP_DEFAULT="$(mktemp)"
cat >"$TMP_DEFAULT" <<EOF
# Generado por UNIMALS. No editar a mano.
# El teclado 2 ($KB2) se remapea en jugador2-oniet.conf.
[ids]
*
-$KB2

[main]
EOF

TMP_P2="$(mktemp)"
cat >"$TMP_P2" <<EOF
# Generado por UNIMALS. Layout de movimiento para el teclado 2.
[ids]
$KB2

[main]
$MAPA_TXT
EOF

install -m 0644 "$TMP_DEFAULT" "$CONF_DEFAULT"
install -m 0644 "$TMP_P2" "$CONF_P2"
rm -f "$TMP_DEFAULT" "$TMP_P2"

log "Validando configuracion..."
if ! keyd check; then
	rm -f "$CONF_P2"
	die "Config invalida; se revirtio $CONF_P2."
fi

log "Activando servicio keyd..."
systemctl enable --now keyd
keyd reload

cat <<EOF

Listo. El teclado 2 ahora emite: $(tr '\\n' ' ' <<<"$MAPA_TXT")
Si algo sale mal: presiona backspace+escape+enter.
EOF
"""
const WINDOWS_HELPER_CS := """
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

public sealed class RawKeyboardForm : Form
{
    const int WM_INPUT = 0x00FF;
    const uint RID_INPUT = 0x10000003;
    const uint RIM_TYPEKEYBOARD = 1;
    const uint RIDEV_INPUTSINK = 0x00000100;
    const ushort HID_USAGE_PAGE_GENERIC = 0x01;
    const ushort HID_USAGE_GENERIC_KEYBOARD = 0x06;
    const ushort RI_KEY_BREAK = 0x0001;

    readonly UdpClient udp = new UdpClient();
    readonly IPEndPoint target;
    readonly Dictionary<IntPtr, int> players = new Dictionary<IntPtr, int>();

    public RawKeyboardForm(int port)
    {
        target = new IPEndPoint(IPAddress.Loopback, port);
        ShowInTaskbar = false;
        WindowState = FormWindowState.Minimized;
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        Opacity = 0;
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        RAWINPUTDEVICE[] devices = new RAWINPUTDEVICE[1];
        devices[0].usUsagePage = HID_USAGE_PAGE_GENERIC;
        devices[0].usUsage = HID_USAGE_GENERIC_KEYBOARD;
        devices[0].dwFlags = RIDEV_INPUTSINK;
        devices[0].hwndTarget = Handle;
        if (!RegisterRawInputDevices(devices, (uint)devices.Length, (uint)Marshal.SizeOf(typeof(RAWINPUTDEVICE))))
        {
            Environment.Exit(2);
        }
    }

    protected override void WndProc(ref Message message)
    {
        if (message.Msg == WM_INPUT)
        {
            HandleRawInput(message.LParam);
        }
        base.WndProc(ref message);
    }

    void HandleRawInput(IntPtr inputHandle)
    {
        uint size = 0;
        GetRawInputData(inputHandle, RID_INPUT, IntPtr.Zero, ref size, (uint)Marshal.SizeOf(typeof(RAWINPUTHEADER)));
        if (size == 0)
        {
            return;
        }

        IntPtr buffer = Marshal.AllocHGlobal((int)size);
        try
        {
            if (GetRawInputData(inputHandle, RID_INPUT, buffer, ref size, (uint)Marshal.SizeOf(typeof(RAWINPUTHEADER))) != size)
            {
                return;
            }

            RAWINPUT raw = (RAWINPUT)Marshal.PtrToStructure(buffer, typeof(RAWINPUT));
            if (raw.header.dwType != RIM_TYPEKEYBOARD || raw.header.hDevice == IntPtr.Zero)
            {
                return;
            }

            int player = PlayerFor(raw.header.hDevice);
            if (player == 0)
            {
                return;
            }

            bool down = (raw.keyboard.Flags & RI_KEY_BREAK) == 0;
            Send(player, raw.keyboard.VKey, down);
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    int PlayerFor(IntPtr device)
    {
        int player;
        if (players.TryGetValue(device, out player))
        {
            return player;
        }
        if (players.Count >= 2)
        {
            return 0;
        }
        player = players.Count + 1;
        players[device] = player;
        return player;
    }

    void Send(ushort vkey, bool down)
    {
        Send(0, vkey, down);
    }

    void Send(int player, ushort vkey, bool down)
    {
		string line = player.ToString() + "|" + vkey.ToString() + "|" + (down ? "1" : "0");
        byte[] bytes = Encoding.ASCII.GetBytes(line);
        udp.Send(bytes, bytes.Length, target);
    }

	[DllImport("user32.dll", SetLastError = true)]
    static extern bool RegisterRawInputDevices(RAWINPUTDEVICE[] pRawInputDevices, uint uiNumDevices, uint cbSize);

	[DllImport("user32.dll", SetLastError = true)]
    static extern uint GetRawInputData(IntPtr hRawInput, uint uiCommand, IntPtr pData, ref uint pcbSize, uint cbSizeHeader);

    [StructLayout(LayoutKind.Sequential)]
    struct RAWINPUTDEVICE
    {
        public ushort usUsagePage;
        public ushort usUsage;
        public uint dwFlags;
        public IntPtr hwndTarget;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct RAWINPUTHEADER
    {
        public uint dwType;
        public uint dwSize;
        public IntPtr hDevice;
        public IntPtr wParam;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct RAWKEYBOARD
    {
        public ushort MakeCode;
        public ushort Flags;
        public ushort Reserved;
        public ushort VKey;
        public uint Message;
        public uint ExtraInformation;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct RAWINPUT
    {
        public RAWINPUTHEADER header;
        public RAWKEYBOARD keyboard;
    }
}

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        int port = 38571;
        if (args.Length > 0)
        {
            int.TryParse(args[0], out port);
        }
        Application.EnableVisualStyles();
        Application.Run(new RawKeyboardForm(port));
    }
}
"""
const WINDOWS_INSTALL_PS := """
$ErrorActionPreference = 'Stop'
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $Base 'OnietRawKeyboardHelper.cs'
$Out = Join-Path $Base 'OnietRawKeyboardHelper.exe'
$Candidates = @(
	"$env:WINDIR/Microsoft.NET/Framework64/v4.0.30319/csc.exe",
	"$env:WINDIR/Microsoft.NET/Framework/v4.0.30319/csc.exe"
)
$Csc = $null
foreach ($Candidate in $Candidates) {
	if (Test-Path $Candidate) {
		$Csc = $Candidate
		break
	}
}
if ($null -eq $Csc) {
	$Command = Get-Command csc.exe -ErrorAction SilentlyContinue
	if ($null -ne $Command) {
		$Csc = $Command.Source
	}
}
if ($null -eq $Csc) {
	throw 'No encontre csc.exe. Instala .NET Framework Developer Pack o Visual Studio Build Tools.'
}
& $Csc /nologo /target:winexe /out:$Out /r:System.Windows.Forms.dll /r:System.Drawing.dll $Source
exit $LASTEXITCODE
"""

const WINDOWS_VKEY_ACTIONS := {
	65: "left",
	68: "right",
	87: "up",
	83: "down",
	86: "fire",
	67: "grab",
	81: "ragdoll",
	66: "strafe",
	9: "lock",
	69: "quack",
}

var _udp := PacketPeerUDP.new()
var _windows_bridge_active: bool = false
var _windows_bridge_started: bool = false
var _windows_enabled: bool = false
var _helper_pid: int = -1
var _raw_pressed := {1: {}, 2: {}}
var _raw_just_pressed := {1: {}, 2: {}}
var _raw_just_released := {1: {}, 2: {}}
var _raw_consumed_pressed := {1: {}, 2: {}}
var _raw_consumed_released := {1: {}, 2: {}}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar_estado()
	if _windows_enabled and OS.get_name() == "Windows" and FileAccess.file_exists(WINDOWS_HELPER_EXE_PATH):
		_iniciar_windows_helper()


func _process(_delta: float) -> void:
	if not _windows_bridge_started:
		return
	while _udp.get_available_packet_count() > 0:
		_recibir_windows_packet(_udp.get_packet().get_string_from_ascii())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_detener_windows_helper()


func etiqueta_boton() -> String:
	if OS.get_name() == "Windows" and _windows_bridge_active:
		return "Desactivar 2 teclados"
	match OS.get_name():
		"Linux":
			return "Instalar 2 teclados"
		"Windows":
			return "Instalar 2 teclados"
		_:
			return "2 teclados no disponible"


func puede_configurar() -> bool:
	return OS.get_name() == "Linux" or OS.get_name() == "Windows"


func configurar_dos_teclados() -> Dictionary:
	match OS.get_name():
		"Linux":
			return _configurar_linux()
		"Windows":
			if _windows_bridge_active:
				_detener_windows_helper()
				_windows_enabled = false
				_guardar_estado()
				return {"ok": true, "mensaje": "Modo 2 teclados desactivado. Vuelve el input normal."}
			return _configurar_windows()
	return {
		"ok": false,
		"mensaje": "Este instalador solo esta preparado para Linux. Godot no distingue dos teclados por si solo.",
	}


func _configurar_linux() -> Dictionary:
	var pkexec := _buscar_comando("pkexec")
	if pkexec.is_empty():
		return {
			"ok": false,
			"mensaje": "Falta pkexec. Instala policykit o ejecuta el instalador Linux desde una terminal con sudo.",
		}

	var ruta_script := ProjectSettings.globalize_path(SCRIPT_PATH)
	var file := FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"mensaje": "No pude preparar el instalador en user://.",
		}
	file.store_string(INSTALL_SCRIPT)
	file.close()

	var salida: Array = []
	var codigo := OS.execute(pkexec, ["bash", ruta_script], salida, true)
	if codigo == OK:
		return {
			"ok": true,
			"mensaje": "Listo: el segundo teclado queda remapeado para Jugador 2.",
			"salida": "\n".join(salida),
		}

	var detalle := "\n".join(salida).strip_edges()
	if detalle.is_empty():
		detalle = "La instalacion fue cancelada o no se pudieron elevar permisos."
	return {
		"ok": false,
		"mensaje": detalle,
	}


func _buscar_comando(nombre: String) -> String:
	var salida: Array = []
	var codigo := OS.execute("which", [nombre], salida, true)
	if codigo != OK or salida.is_empty():
		return ""
	return String(salida[0]).strip_edges()


func raw_input_activo() -> bool:
	return OS.get_name() == "Windows" and _windows_bridge_active


func raw_move_axis(jugador: int) -> float:
	var right := 1.0 if raw_action_pressed(jugador, "right") else 0.0
	var left := 1.0 if raw_action_pressed(jugador, "left") else 0.0
	return right - left


func raw_aim(jugador: int) -> Vector2:
	var direction := Vector2.ZERO
	if raw_action_pressed(jugador, "left") and not raw_action_pressed(jugador, "right"):
		direction.x = -1.0
	elif raw_action_pressed(jugador, "right") and not raw_action_pressed(jugador, "left"):
		direction.x = 1.0
	if raw_action_pressed(jugador, "up") and not raw_action_pressed(jugador, "down"):
		direction.y = -1.0
	elif raw_action_pressed(jugador, "down") and not raw_action_pressed(jugador, "up"):
		direction.y = 1.0
	return direction


func raw_action_pressed(jugador: int, accion: String) -> bool:
	accion = _raw_alias(accion)
	return bool(_raw_pressed.get(jugador, {}).get(accion, false))


func raw_action_just_pressed(jugador: int, accion: String) -> bool:
	accion = _raw_alias(accion)
	return _raw_consumir(_raw_just_pressed, _raw_consumed_pressed, jugador, accion)


func raw_action_just_released(jugador: int, accion: String) -> bool:
	accion = _raw_alias(accion)
	return _raw_consumir(_raw_just_released, _raw_consumed_released, jugador, accion)


func _configurar_windows() -> Dictionary:
	if not _escribir_archivo(WINDOWS_HELPER_CS_PATH, WINDOWS_HELPER_CS):
		return {"ok": false, "mensaje": "No pude escribir el helper de teclado en user://."}
	if not _escribir_archivo(WINDOWS_HELPER_PS_PATH, WINDOWS_INSTALL_PS):
		return {"ok": false, "mensaje": "No pude escribir el instalador de Windows en user://."}

	var salida: Array = []
	var script := ProjectSettings.globalize_path(WINDOWS_HELPER_PS_PATH)
	var codigo := OS.execute("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script], salida, true)
	if codigo != OK:
		var detalle := "\n".join(salida).strip_edges()
		if detalle.is_empty():
			detalle = "No pude compilar el helper. Instala .NET Framework Developer Pack o Visual Studio Build Tools."
		return {"ok": false, "mensaje": detalle}
	var resultado := _iniciar_windows_helper()
	if bool(resultado.get("ok", false)):
		_windows_enabled = true
		_guardar_estado()
	return resultado


func _iniciar_windows_helper() -> Dictionary:
	if _windows_bridge_started:
		_windows_bridge_active = true
		return {"ok": true, "mensaje": "Listo: puente de teclado de Windows activo."}
	if not FileAccess.file_exists(WINDOWS_HELPER_EXE_PATH):
		return {"ok": false, "mensaje": "Todavia no esta instalado el helper de Windows."}

	var bind_result := _udp.bind(WINDOWS_PORT, "127.0.0.1")
	if bind_result != OK:
		return {"ok": false, "mensaje": "No pude abrir el puerto local para los teclados."}

	var exe := ProjectSettings.globalize_path(WINDOWS_HELPER_EXE_PATH)
	_helper_pid = OS.create_process(exe, [str(WINDOWS_PORT)], false)
	if _helper_pid <= 0:
		_udp.close()
		return {"ok": false, "mensaje": "No pude iniciar el helper de teclado de Windows."}

	_windows_bridge_started = true
	_windows_bridge_active = true
	return {"ok": true, "mensaje": "Listo: cada teclado usa WASD por separado para Jugador 1 y 2."}


func _detener_windows_helper() -> void:
	if _helper_pid > 0:
		OS.kill(_helper_pid)
	_helper_pid = -1
	if _windows_bridge_started:
		_udp.close()
	_windows_bridge_started = false
	_windows_bridge_active = false
	_limpiar_raw_state()


func _recibir_windows_packet(packet: String) -> void:
	var partes := packet.strip_edges().split("|")
	if partes.size() != 3:
		return
	var jugador := int(partes[0])
	if jugador < 1 or jugador > 2:
		return
	var accion = WINDOWS_VKEY_ACTIONS.get(int(partes[1]), "")
	if accion.is_empty():
		return
	var pressed := partes[2] == "1"
	var previo := bool(_raw_pressed[jugador].get(accion, false))
	if previo == pressed:
		return
	_raw_pressed[jugador][accion] = pressed
	if pressed:
		_raw_just_pressed[jugador][accion] = int(_raw_just_pressed[jugador].get(accion, 0)) + 1
	else:
		_raw_just_released[jugador][accion] = int(_raw_just_released[jugador].get(accion, 0)) + 1


func _limpiar_raw_state() -> void:
	for jugador in [1, 2]:
		_raw_pressed[jugador].clear()
		_raw_just_pressed[jugador].clear()
		_raw_just_released[jugador].clear()
		_raw_consumed_pressed[jugador].clear()
		_raw_consumed_released[jugador].clear()


func _raw_consumir(origen: Dictionary, consumidos: Dictionary, jugador: int, accion: String) -> bool:
	var total := int(origen.get(jugador, {}).get(accion, 0))
	var usado := int(consumidos.get(jugador, {}).get(accion, 0))
	if usado >= total:
		return false
	consumidos[jugador][accion] = usado + 1
	return true


func _raw_alias(accion: String) -> String:
	if accion == "jump":
		return "up"
	return accion


func _cargar_estado() -> void:
	_windows_enabled = false
	var cfg := ConfigFile.new()
	if cfg.load(WINDOWS_CONFIG_PATH) != OK:
		return
	_windows_enabled = bool(cfg.get_value("windows", "enabled", false))


func _guardar_estado() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("windows", "enabled", _windows_enabled)
	cfg.save(WINDOWS_CONFIG_PATH)


func _escribir_archivo(ruta: String, contenido: String) -> bool:
	var file := FileAccess.open(ruta, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contenido)
	file.close()
	return true
