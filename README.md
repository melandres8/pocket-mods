# Pocket mods

Scripts y mods para la RadioMaster Pocket (EdgeTX, pantalla de 128x64). Probados con EdgeTX 2.12 y ExpressLRS.

| Carpeta | Qué es | Va en la SD |
|---|---|---|
| [`fpv-radar/`](fpv-radar/) | **FPV Radar**: encuentra tu dron estrellado por la señal ELRS | `SCRIPTS/TOOLS/` |
| [`fpv-hub/`](fpv-hub/) | **FPV Hub**: menú con tiles para abrir todo lo demás | `SCRIPTS/TOOLS/` |
| [`telemetria/`](telemetria/) | Pantallas de telemetría: `sticks` (4 layouts) y `dash` | `SCRIPTS/TELEMETRY/` |
| [`alertas/`](alertas/) | Avisos de voz y vibración por batería baja y señal | `SCRIPTS/FUNCTIONS/` |
| [`betaflight/`](betaflight/) | Betaflight TX Lua Scripts 1.8.0, sin modificar (GPL-3.0) | `SCRIPTS/` |

¿Vienes del TikTok? Lo que buscas está en [`fpv-radar/`](fpv-radar/).

## Instalación general

1. Conecta la radio al computador en modo USB Storage (SD).
2. Copia cada archivo `.lua` a la carpeta que indica la tabla.
3. Expulsa la radio. EdgeTX compila los scripts (`.luac`) la primera vez que los abre.
