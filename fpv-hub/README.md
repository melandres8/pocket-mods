# FPV Hub

Un menú para la Pocket con barra de título, cuatro tiles con iconos y tres óvalos abajo. Desde aquí se abre todo lo demás sin tener que entrar a los menús de EdgeTX.

**Qué necesitas:** una radio con pantalla de 128x64 y EdgeTX (probado en la RadioMaster Pocket con EdgeTX 2.12).

**Instalación:** copia `FPVHub.lua` a `SCRIPTS/TOOLS/`. Para abrirlo: SYS → Tools → FPV Hub.

El hub funciona solo. Los tiles y los óvalos aparecen según lo que tengas en la SD, así que puedes empezar con el hub y sumar el resto cuando quieras.

| Tile | Abre | Necesita |
|---|---|---|
| STICKS | Pantalla de sticks | `SCRIPTS/TELEMETRY/sticks.lua`, de [`telemetria/`](../telemetria/) |
| TELEM | Dashboard de vuelo | `SCRIPTS/TELEMETRY/dash.lua`, de [`telemetria/`](../telemetria/) |
| BTFL | Betaflight setup | `SCRIPTS/TOOLS/bf.lua`, de [`betaflight/`](../betaflight/) |
| ELRS | ExpressLRS | `SCRIPTS/TOOLS/elrs.lua`, viene con ExpressLRS |

Un tile solo aparece si su script está en la SD.

| Óvalo | Hace |
|---|---|
| LOCATE | Abre el [FPV Radar](../fpv-radar/), si está instalado |
| TELE LAYOUT | Elige el layout de `sticks` (BOXES, TRAIL, MINI, CHRONO): ENTER abre el selector, NEXT/PREV cambia, ENTER guarda en `sticks.cfg`, EXIT cancela. Solo aparece si tienes `sticks.lua` |
| LIGHT | Cambia el color del LED. Solo aparece en radios con LED RGB |

**Controles:** NEXT/PREV para moverte, ENTER para abrir o cambiar, EXIT para volver.
