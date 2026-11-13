# FPV Hub

Un menú para la Pocket con barra de título, cuatro tiles con iconos y tres óvalos abajo. Desde aquí se abre todo lo demás sin tener que entrar a los menús de EdgeTX.

**Instalación:** copia `FPVHub.lua` a `SCRIPTS/TOOLS/`. Para abrirlo: SYS → Tools → FPV Hub.

| Tile | Abre | Necesita |
|---|---|---|
| STICKS | Pantalla de sticks | `SCRIPTS/TELEMETRY/sticks.lua` |
| TELEM | Dashboard de vuelo | `SCRIPTS/TELEMETRY/dash.lua` |
| BTFL | Betaflight setup | `SCRIPTS/TOOLS/bf.lua` |
| ELRS | ExpressLRS | `SCRIPTS/TOOLS/elrs.lua` |

Un tile solo aparece si su script está en la SD.

| Óvalo | Hace |
|---|---|
| LOCATE | Abre el FPV Radar, si está instalado |
| TELE LAYOUT | Elige el layout de `sticks` (BOXES, TRAIL, MINI, CHRONO): ENTER abre el selector, NEXT/PREV cambia, ENTER guarda en `sticks.cfg`, EXIT cancela |
| LIGHT | Cambia el color del LED. Solo aparece en radios con LED RGB |

**Controles:** NEXT/PREV para moverte, ENTER para abrir o cambiar, EXIT para volver.
