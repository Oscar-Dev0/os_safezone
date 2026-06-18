# os_safezone 2.0

Sistema unificado y persistente de zonas seguras para FiveM.

## Dependencias

- `ox_lib`
- `oxmysql`
- Uno de estos frameworks: Qbox, QBCore, ESX; también funciona en modo standalone.

## Instalación

1. Copia `os_safezone` dentro de `resources`.
2. Importa `sql/os_safezone.sql` o deja que el recurso cree la tabla automáticamente.
3. Asegura el orden:

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core # o qb-core / es_extended
ensure os_safezone
```

4. Otorga el permiso administrativo:

```cfg
add_ace group.admin safezones.admin allow
```

5. Abre el panel con `/safezones`.

## Estructura

- `shared/schema.lua`: normalización, copias seguras y validación de datos.
- `server/security.lua`: permisos y rate limit.
- `server/logger.lua`: consola, archivo y Discord.
- `server/database.lua`: persistencia y migración.
- `server/main.lua`: casos de uso y sincronización.
- `client/zones.lua`: creación y detección espacial.
- `client/restrictions.lua`: reglas aplicadas al jugador.
- `client/main.lua`: estado, exports y callbacks NUI.
- `bridge/`: adaptadores para cada framework.

## Exports cliente

```lua
exports.os_safezone:IsPlayerInSafeZone()
exports.os_safezone:GetCurrentSafeZone()
exports.os_safezone:IsActionBlocked('inventory')
exports.os_safezone:createSafe(data)
```

## Exports servidor

```lua
exports.os_safezone:GetSafeZones()
exports.os_safezone:GetSafeZoneById(id)
exports.os_safezone:SetSafeZoneState(id, true)
```

`SetSafeZoneState` es un export de servidor; no existe un evento de red público equivalente.
