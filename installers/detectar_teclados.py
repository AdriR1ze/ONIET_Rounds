#!/usr/bin/env python3
"""Detecta teclados en Linux leyendo /proc/bus/input/devices.

Salida (una linea por teclado):
    <vendor>:<product>  <event>  <nombre>

El id vendor:product es el que usa keyd en su seccion [ids].
No requiere root para leer /proc.
"""
import re
import sys
from pathlib import Path

RUTA = Path("/proc/bus/input/devices")

# Dispositivos que el kernel expone con handler "kbd" pero no son teclados reales.
EXCLUIR = (
    "power button",
    "sleep button",
    "lid switch",
    "video bus",
    "pc speaker",
    "hdmi",
    "acpi",
    "hotkeys",
    "wmi",
)


def detectar(ruta=RUTA):
    if not ruta.exists():
        return []
    texto = ruta.read_text(errors="replace")
    teclados = []
    for bloque in texto.strip().split("\n\n"):
        m_handlers = re.search(r"^H:\s*Handlers=(.+)$", bloque, re.MULTILINE)
        if not m_handlers or "kbd" not in m_handlers.group(1).split():
            continue
        m_ident = re.search(r"^I:\s*Bus=\S+\s+Vendor=([0-9a-fA-F]{4})\s+Product=([0-9a-fA-F]{4})", bloque, re.MULTILINE)
        m_nombre = re.search(r'^N:\s*Name="?(.*?)"?\s*$', bloque, re.MULTILINE)
        if not m_ident:
            continue
        nombre = m_nombre.group(1) if m_nombre else "?"
        if any(x in nombre.lower() for x in EXCLUIR):
            continue
        evento = ""
        for token in m_handlers.group(1).split():
            if token.startswith("event"):
                evento = token
                break
        teclados.append({
            "id": "%s:%s" % (m_ident.group(1).lower(), m_ident.group(2).lower()),
            "event": evento,
            "name": nombre,
        })
    return teclados


def main():
    teclados = detectar()
    if not teclados:
        print("No se detectaron teclados.", file=sys.stderr)
        return 1
    for t in teclados:
        print("%s  %s  %s" % (t["id"], t["event"], t["name"]))
    ids = [t["id"] for t in teclados]
    if len(set(ids)) < len(ids):
        print("AVISO: hay teclados con el mismo id (modelo identico).", file=sys.stderr)
        print("keyd no puede distinguirlos; se necesita un helper por dispositivo.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
