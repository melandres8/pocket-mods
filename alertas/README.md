# Alertas de voz

`alerts.lua` avisa con voz y vibración cuando:

| Condición | Aviso | Crítico |
|---|---|---|
| Batería por celda (`RxBt`, las celdas se detectan solas) | 3,5 V: sonido `lowbat` y el voltaje | 3,3 V: sonido `clobat` y vibración |
| Calidad de enlace (`RQly`) | 50 %: sonido `siglow` | 25 %: sonido `sigcrt` y vibración |

Solo avisa si la condición se mantiene 3 s, así que un golpe de acelerador no lo dispara. Mientras el receptor no está conectado no dice nada, así que en el simulador queda callado.

## Instalación

1. Copia `alerts.lua` a `SCRIPTS/FUNCTIONS/`.
2. En el modelo, ve a MDL → Special Functions y agrega: interruptor **ON** → **Lua Script** → **alerts**, con repetición **On**.

Los sonidos vienen del paquete en inglés de EdgeTX (`SOUNDS/en/`).
