# Estudio Cámara

App nativa para macOS que graba video con la cámara del equipo, permite elegir cámara y micrófono y sustituye el fondo en tiempo real.

## Funciones

- Vista previa en tiempo real y modo espejo.
- Formatos 16:9, 9:16 vertical, 1:1 y 4:5, aplicados también al archivo grabado.
- Salida vertical de 1080 × 1920, adecuada para TikTok, Reels y Shorts.
- Selección de cámara y fuente de audio.
- Fondo original, desenfocado, color sólido o imagen personalizada.
- Detección de personas mediante Vision, procesada en el dispositivo.
- Escala y movimiento de la persona mediante arrastre o controles de posición.
- Filtros creativos y controles de exposición, contraste y saturación.
- Títulos y subtítulos con posición y tamaño configurables.
- Cuadrícula de tercios y captura de fotos en PNG.
- Grabación con video H.264 y audio AAC.
- Guardado automático en `Películas/Estudio Cámara` y `Imágenes/Estudio Cámara`.

## Requisitos

- macOS 14 o posterior.
- Xcode 15 o posterior.
- Permisos de cámara y micrófono.

## Compilar

```sh
./build-app.sh
```

La app queda en `dist/Estudio Cámara.app`. También puedes ejecutar `swift run EstudioCamara` durante el desarrollo.

Si Xcode muestra un aviso de licencia, ábrelo y acepta la licencia antes de compilar. No se requieren dependencias externas.

## Privacidad

La imagen y el audio se procesan localmente. La app no incluye analítica, cuentas, servicios de red ni subida de contenido.

## Apoya el proyecto

Si Estudio Cámara te resulta útil, puedes apoyar su desarrollo en [Buy Me a Coffee](https://buymeacoffee.com/CarlosGuedea).
