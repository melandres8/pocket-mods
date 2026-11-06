# FPV Radar para RadioMaster Pocket

Encuentra tu dron estrellado usando la señal ELRS. Funciona como "frío o caliente": mientras más cerca estás, más sube el porcentaje y más rápido y agudo pita la radio.

No dice hacia dónde está el dron. El receptor solo reporta qué tan fuerte llega la señal, no de qué dirección viene. El barrido que gira en la pantalla es decoración.

## Qué necesitas

- RadioMaster Pocket (pantalla de 128x64) con EdgeTX. Probado con EdgeTX 2.12.
- Un receptor ExpressLRS con telemetría activa. El script lee `RQly`, `1RSS`, `2RSS` y `TPWR`.
- El dron caído tiene que seguir con batería, porque si no, el receptor no transmite.

## Instalación

1. Conecta la radio al computador en modo almacenamiento USB (USB Storage / SD).
2. Copia `FPVRadar.lua` a `SCRIPTS/TOOLS/` en la tarjeta SD.
3. Expulsa la radio y desconéctala.
4. Para abrirlo: SYS → Tools → **FPV Radar**.

## Antes de buscar: fija la potencia

En el script ELRS (SYS → Tools → ExpressLRS), pon la **potencia en 25 mW** y apaga **Dynamic Power**.

Con Dynamic Power, la radio baja su potencia a medida que te acercas. Eso aplana la señal y deja de subir justo cuando más la necesitas. Si la potencia no está en 25 mW, el script muestra un "!" parpadeando arriba a la derecha.

## Cómo leer la pantalla

| Elemento | Qué significa |
|---|---|
| % grande | Fuerza de la señal: -115 dBm es 0 % (lejos) y -45 dBm es 100 % (encima) |
| FAR / WARM / CLOSE / HERE! | Menos de 30 %, de 30 a 60 %, de 60 a 85 %, y más de 85 % |
| Flecha ↑ ↓ | Si la señal sube o baja respecto a hace 1,5 s. Si baja, vas para el lado equivocado |
| Anillo que se achica | Mientras más pequeño, más cerca |
| Barra de abajo | La señal, y una línea punteada con la mejor señal que has tenido |
| Pitido | Cada 1,2 s cuando estás lejos, hasta cada 0,12 s encima. También se vuelve más agudo |

## Controles

- **ENTER**: activa o silencia el sonido.
- **NEXT / PREV** (las teclas de navegación): reinician la mejor señal.
- **EXIT**: cierra el radar.

## Tips de búsqueda

- Camina despacio y fíjate en la flecha. Si baja, date la vuelta.
- Levanta la radio por encima de la cabeza. El pasto y tu cuerpo bloquean la señal.
- Cuando estés cerca y el porcentaje deje de subir, busca en círculos pequeños.

## Versión con dirección (experimental)

`con-direccion/` trae una versión con **giro guiado**. Pegas la radio al pecho, presionas ENTER y giras 45° a la derecha en cada pitido. Tu cuerpo bloquea la señal que viene de atrás, así que el paso con más señal es hacia donde está el dron. Al terminar, el radar dibuja una flecha hacia esa dirección.

En esa versión ENTER arranca el giro y se silencia manteniendo presionado ENTER. Solo está probada en un simulador, todavía no en campo. `test_radar.lua` es ese simulador; se corre con `lua test_radar.lua FPVRadar.lua`.
