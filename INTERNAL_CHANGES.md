# os_safezone 3.0.0 — cambios internos

La interfaz visual se mantiene. Esta versión se concentra en estabilidad, seguridad y mantenibilidad.

## Núcleo
- Caché autoritativa en servidor con revisiones incrementales.
- Los clientes descartan actualizaciones antiguas o fuera de orden.
- Resincronización completa periódica como red de seguridad.
- Bloqueos de escritura por zona para evitar editar, eliminar o activar simultáneamente.
- Límite configurable de zonas y puntos de polígonos.
- Exports del servidor devuelven copias; otros recursos ya no pueden mutar la caché accidentalmente.

## Geometría
- Formato canónico para cajas: `length`, `width`, `height`, además de alias `x`, `y`, `z`.
- Rotación de cajas unificada en `dimensions.heading`.
- Centro vertical correcto para polígonos de ox_lib.
- Validación de altura, coordenadas, radio y dimensiones.
- Compatibilidad con zonas antiguas que usaban `x/y/z`.

## Seguridad
- Teletransporte administrativo autorizado por el servidor.
- Rate limit separado por acción.
- IDs y datos se validan nuevamente en servidor.
- La auto-inyección de zonas heredadas queda desactivada por defecto.

## Persistencia
- Filas cargadas desde MySQL se normalizan y validan antes de entrar en caché.
- Una fila corrupta se ignora con log en lugar de romper todo el recurso.
- Índices SQL para estado, prioridad y fecha de actualización.
- Confirmación real de MySQL antes de modificar la caché y sincronizar clientes.

## Configuración nueva
```lua
Config.Database.AutoInjectLegacyZones = false
Config.Sync.FullResyncIntervalMs = 300000
Config.Sync.MaxZones = 500
Config.ZoneLimits.MaxPolygonPoints = 64
```
