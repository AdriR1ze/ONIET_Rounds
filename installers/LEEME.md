# Reparto de teclados (2 teclados)

Godot **no puede distinguir dos teclados**: el sistema operativo fusiona los
eventos en un solo flujo y `InputEventKey.device` no sirve para separarlos. Por
eso, para que **cada jugador use el mismo layout** (p. ej. los dos con WASD),
hay que usar un puente por dispositivo o reasignar el **segundo teclado** antes
de que llegue al input normal de Godot.

Si a cada jugador le sirve un layout distinto (P1 WASD, P2 flechas, P3 numpad,
P4 TFGH), **no hace falta nada de esto**: ya funciona con 4 jugadores.

- Desde el juego: **Opciones > Instalar 2 teclados** (Windows y Linux)
- Detector Linux: `python3 installers/detectar_teclados.py`
- Instalador Linux manual: `sudo bash installers/linux/instalar_keyd.sh`
- Desinstalador Linux: `sudo bash installers/linux/desinstalar_keyd.sh`
- Detector Windows: `powershell -ExecutionPolicy Bypass -File installers\windows\detectar_teclados.ps1`

## Linux (automatico)

El juego puede lanzar el instalador desde **Opciones > Instalar 2 teclados**. En
Linux usa `pkexec` para pedir permisos de administrador y configurar
[keyd](https://github.com/rvaiya/keyd). Si falta `pkexec` o queres hacerlo a
mano, `instalar_keyd.sh` instala keyd (por apt o su PPA si tu Ubuntu es <
25.04), detecta los teclados y escribe la config para que el segundo teclado
emita el layout alternativo.

```bash
# Default: el teclado 2 manda flechas (sirve con los controles por defecto de P2)
sudo bash installers/linux/instalar_keyd.sh

# Otra opcion: el teclado 2 manda IJKL (usalo si queres bindear P2 con IJKL)
sudo -E MAPA=ijkl bash installers/linux/instalar_keyd.sh

# Si hay mas de 2 teclados, elegi cual:
sudo -E KB2_ID=1234:abcd bash installers/linux/instalar_keyd.sh

# Ver que haria, sin tocar nada:
sudo -E DRY_RUN=1 bash installers/linux/instalar_keyd.sh
```

Panico de keyd si algo sale mal: **backspace + escape + enter**.

### Limite importante

keyd identifica teclados por `vendor:product`. Si tus dos teclados son **el
mismo modelo**, comparten id y keyd **no puede** distinguirlos. En ese caso se
necesita un helper que lea por dispositivo (`/dev/input/eventN` + `uinput`),
que todavia no esta incluido.

## Windows (automatico sin driver)

El juego puede compilar e iniciar un helper local desde **Opciones > Instalar 2
teclados**. Ese helper usa Raw Input de Windows para leer cada teclado fisico por
separado y manda los eventos al juego por UDP local (`127.0.0.1`). No instala
drivers ni requiere permisos de administrador.

Con el helper activo, los jugadores 1 y 2 usan el mismo layout fisico:

| Accion | Tecla |
|--------|-------|
| Mover / apuntar | W A S D |
| Saltar | W |
| Disparar | V |
| Agarrar | C |
| Trompezar | Q |
| Strafe | B |
| Bloquear | Tab |
| Graznar | E |

El primer teclado que mande una tecla queda como Jugador 1 y el segundo como
Jugador 2.

### Si queres interceptar teclas globalmente

Opciones conocidas:

1. **reWASD** o **Keyboard Splitter** (usan ViGEmBus): permiten asociar cada
   teclado a jugadores distintos. Instalacion GUI.
2. **AutoHotInterception** (AutoHotkey + driver Interception): distingue
   dispositivos por id, incluso iguales. Requiere instalar el driver una vez.

El juego ya soporta esto: una vez que cada teclado emite teclas distintas, se
ata cada jugador con sus teclas en **Opciones > Controles** (remapeo por
jugador, tambien gamepads).

## Layout por defecto del juego

| Jugador | Mover | Saltar | Disparar | Agarrar | Trompezar | Strafe | Bloquear |
|--------:|-------|--------|----------|---------|-----------|--------|----------|
| 1 | A / D / W / S | W | V | C | Q | B | Tab |
| 2 | Flechas | Arriba | , | L | I | K | O |
| 3 | Numpad 4/6/8/5 | Numpad 8 | Numpad + | Numpad 9 | Numpad 7 | Numpad 0 | Numpad - |
| 4 | T / F / G / H | T | Y | E | Z | X | N |

Todo es remapeable en **Opciones > Controles**, con deteccion de conflictos.
