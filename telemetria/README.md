# Pantallas de telemetría

Dos pantallas para 128x64. Se copian a `SCRIPTS/TELEMETRY/` y se asignan en MDL → Display (Pantallas) → tipo Script.

## sticks.lua

Muestra la posición de los sticks para Modo 2, con cuatro layouts. **ENTER** cambia de uno a otro.

- **BOXES:** cuadros grandes de cada stick, con estela.
- **TRAIL:** estelas de los sticks y una barra de acelerador.
- **MINI:** cuatro tarjetas.
- **CHRONO:** timer grande y estelas.

`sticks.cfg` guarda el layout inicial; el FPV Hub lo cambia desde su pestaña TELE LAYOUT.

Opcional: en `FPV_SINCE`, al inicio del archivo, pon la fecha de tu primer vuelo para mostrar el contador de días volando. Si la pones en `nil`, se oculta.

## dash.lua

Dashboard de vuelo con el timer 1, el modo de vuelo, el estado de armado y la telemetría ELRS/Betaflight. Los sensores que falten aparecen como `--`.
