// Nombres de las reglas para renderizar switches en el editor
const RULE_DEFINITIONS = {
    disableWeapons: { label: "Desarmar al entrar", desc: "Guarda las armas automáticamente" },
    disableFiring: { label: "Bloquear disparos", desc: "Deshabilita el disparo de armas" },
    disableMelee: { label: "Bloquear combate cuerpo a cuerpo", desc: "Previene golpes físicos" },
    disableDriveBy: { label: "Bloquear driveby", desc: "Deshabilita disparos de autos" },
    disableVehicleDamage: { label: "Vehículos indestructibles", desc: "Previene daño a vehículos" },
    invinciblePlayers: { label: "Jugadores invencibles", desc: "El jugador no recibe daño" },
    invincibleVehicles: { label: "Vehículos invencibles", desc: "El vehículo no recibe daño" },
    disableCollisions: { label: "Sin colisiones", desc: "Evita choques entre vehículos" },
    maxVehicleSpeed: { label: "Velocidad máxima", desc: "Límite de velocidad en km/h" },
    allowEmergencyWeapons: { label: "Bypass servicios emergencia", desc: "Policías pueden portar armas" },
    hideWeaponOnEnter: { label: "Guardar arma al entrar", desc: "Oculta el arma al ingresar" },
    restoreWeaponOnExit: { label: "Restaurar arma al salir", desc: "Equipa el arma anterior al salir" },
    blockVehicleTheft: { label: "Bloquear robo de vehículos", desc: "Previene robar autos de otros" },
    blockFrisk: { label: "Bloquear cacheos", desc: "Previene cachear al jugador" },
    blockHandcuffs: { label: "Bloquear esposas", desc: "Previene esposar al jugador" },
    blockKidnap: { label: "Bloquear secuestros", desc: "Previene cargar/secuestrar" },
    blockInventory: { label: "Bloquear inventario", desc: "Previene abrir inventarios" },
    disableRoleplayActions: { label: "Bloquear acciones de Rol", desc: "Restringe esposas, cacheos y secuestros" }
};

let activeZonesList = {};
let currentEditingZone = null;
let currentFramework = "standalone";

function GetZoneById(zoneId) {
    zoneId = parseInt(zoneId);
    for (const [_, zone] of Object.entries(activeZonesList)) {
        if (zone && zone.id === zoneId) {
            return zone;
        }
    }
    return null;
}

// ==========================================
// ESCUCHADOR DE MENSAJES NUI DE CLIENTE
// ==========================================
window.addEventListener('message', function(event) {
    const data = event.data;
    
    // 1. Mostrar/Ocultar HUD Inferior
    if (data.action === "showSafezone") {
        const container = document.getElementById('safezone-container');
        const card = document.getElementById('safezone-card');
        const zoneName = document.getElementById('zone-name');
        const tag = document.getElementById('zone-tag');
        
        if (data.state) {
            zoneName.textContent = data.zoneName;
            tag.textContent = data.roleplayType;
            
            card.className = '';
            card.classList.add('type-' + data.roleplayType.toLowerCase());
            
            const rules = data.rules || {};
            document.getElementById('badge-weapons').style.display = rules.disableWeapons ? 'flex' : 'none';
            document.getElementById('badge-melee').style.display = rules.disableMelee ? 'flex' : 'none';
            document.getElementById('badge-god').style.display = rules.invinciblePlayers ? 'flex' : 'none';
            
            const badgeSpeed = document.getElementById('badge-speed');
            if (rules.maxVehicleSpeed && rules.maxVehicleSpeed > 0) {
                badgeSpeed.style.display = 'flex';
                document.getElementById('speed-limit-text').textContent = Math.round(rules.maxVehicleSpeed) + ' km/h';
            } else {
                badgeSpeed.style.display = 'none';
            }
            
            container.classList.remove('hide');
        } else {
            container.classList.add('hide');
        }
    }
    
    // 2. Abrir Tablet de Administración
    if (data.action === "openTablet") {
        activeZonesList = data.zones || [];
        currentFramework = data.framework || "standalone";
        
        document.getElementById('settings-framework').textContent = currentFramework.toUpperCase();
        document.getElementById('settings-debug').textContent = data.debug ? "Activo" : "Desactivado";
        document.getElementById('settings-locale').textContent = data.locale || "es";
        
        RenderZonesList();
        switchTab('manage-tab');
        
        document.getElementById('admin-tablet').classList.remove('hide-tablet');
    }
    
    // 3. Sincronizar zonas en tiempo real
    if (data.action === "updateZones") {
        activeZonesList = data.zones || [];
        RenderZonesList();
        
        if (currentEditingZone) {
            const updated = GetZoneById(currentEditingZone.id);
            if (updated) {
                currentEditingZone = updated;
            }
        }
    }
});

// ==========================================
// CONTROLES DE LA TABLET (NAVEGACIÓN)
// ==========================================

// Cambiar de pestaña en la tablet
function switchTab(tabId) {
    // Desactivar pestañas actuales
    document.querySelectorAll('.tab-pane').forEach(tab => tab.classList.remove('active'));
    document.querySelectorAll('.menu-item').forEach(item => item.classList.remove('active'));
    
    // Activar pestaña elegida
    const targetPane = document.getElementById(tabId);
    if (targetPane) targetPane.classList.add('active');
    
    const menuItem = document.querySelector(`.menu-item[data-tab="${tabId}"]`);
    if (menuItem) menuItem.classList.add('active');
    
    // Cambiar títulos superiores
    const title = document.getElementById('tab-title');
    const subtitle = document.getElementById('tab-subtitle');
    
    if (tabId === 'manage-tab') {
        title.textContent = "Gestionar Zonas";
        subtitle.textContent = "Ver, editar y eliminar zonas seguras del servidor";
    } else if (tabId === 'create-tab') {
        title.textContent = "Crear Nueva Zona";
        subtitle.textContent = "Configurar un área segura con reglas heredadas o manuales";
        renderDimensionInputs(); // Cargar inputs de dimensiones correctos
    } else if (tabId === 'settings-tab') {
        title.textContent = "Ajustes";
        subtitle.textContent = "Detalles y estado global del recurso safezones";
    } else if (tabId === 'edit-tab') {
        title.textContent = "Editor de Zona";
        subtitle.textContent = "Modificar las reglas y visualización de forma individual";
    }
}

// Event Listeners para el menú
document.querySelectorAll('.menu-item').forEach(item => {
    item.addEventListener('click', function() {
        const tab = this.getAttribute('data-tab');
        switchTab(tab);
    });
});

// Cerrar panel
document.getElementById('close-tablet-btn').addEventListener('click', function() {
    document.getElementById('admin-tablet').classList.add('hide-tablet');
    fetch(`https://${GetParentResourceName()}/closeTablet`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    });
});

// Escuchar tecla ESC para cerrar
window.addEventListener('keydown', function(event) {
    if (event.key === "Escape" || event.keyCode === 27) {
        document.getElementById('admin-tablet').classList.add('hide-tablet');
        fetch(`https://${GetParentResourceName()}/closeTablet`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
    }
});

// ==========================================
// RENDERIZADO Y GESTIÓN DE LA LISTA DE ZONAS
// ==========================================

function RenderZonesList() {
    const container = document.getElementById('zones-list-container');
    container.innerHTML = '';
    
    const searchVal = document.getElementById('zone-search').value.toLowerCase();
    
    for (const [_, zone] of Object.entries(activeZonesList)) {
        if (!zone) continue; // Seguridad ante arrays sparse de FiveM
        
        if (searchVal && !zone.name.toLowerCase().includes(searchVal) && !String(zone.id).includes(searchVal)) {
            continue;
        }
        
        const card = document.createElement('div');
        card.className = 'zone-item-card';
        
        const enabledCheck = zone.enabled ? 'checked' : '';
        
        card.innerHTML = `
            <div class="zone-card-top">
                <h3>${zone.name}</h3>
                <span class="zone-type-badge ${zone.roleplayType.toLowerCase()}">${zone.roleplayType}</span>
            </div>
            <div class="zone-card-details">
                <span><strong>ID:</strong> ${zone.id} | <strong>Tipo:</strong> ${zone.zoneType.toUpperCase()}</span>
                <span><strong>Coords:</strong> X: ${zone.coords.x.toFixed(1)}, Y: ${zone.coords.y.toFixed(1)}, Z: ${zone.coords.z.toFixed(1)}</span>
            </div>
            <div class="zone-card-actions">
                <button class="btn btn-primary btn-edit" data-id="${zone.id}"><i class="fa-solid fa-pen-to-square"></i> Editar</button>
                <button class="btn btn-secondary btn-tp" data-id="${zone.id}"><i class="fa-solid fa-location-arrow"></i> TP</button>
                <label class="switch-label">
                    <input type="checkbox" class="toggle-active-btn" data-id="${zone.id}" ${enabledCheck}>
                    <span class="slider"></span>
                </label>
            </div>
        `;
        container.appendChild(card);
    }
    
    // Registrar Eventos de botones
    container.querySelectorAll('.btn-edit').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            OpenZoneForEdit(id);
        });
    });
    
    container.querySelectorAll('.btn-tp').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            fetch(`https://${GetParentResourceName()}/teleportToZone`, {
                method: 'POST',
                body: JSON.stringify({ id: id })
            });
        });
    });
    
    container.querySelectorAll('.toggle-active-btn').forEach(check => {
        check.addEventListener('change', function() {
            const id = this.getAttribute('data-id');
            const state = this.checked;
            
            // Sincronizar estado local en memoria de la Tablet
            const zone = GetZoneById(id);
            if (zone) zone.enabled = state;
            
            fetch(`https://${GetParentResourceName()}/toggleZone`, {
                method: 'POST',
                body: JSON.stringify({ id: id, state: state })
            });
        });
    });
}

// Búsqueda instantánea
document.getElementById('zone-search').addEventListener('input', RenderZonesList);

// ==========================================
// CREACIÓN DE NUEVA ZONA
// ==========================================

const typeSelect = document.getElementById('create-zone-type');
typeSelect.addEventListener('change', renderDimensionInputs);

function renderDimensionInputs() {
    const type = typeSelect.value;
    const container = document.getElementById('dimension-inputs-container');
    container.innerHTML = '';
    
    if (type === 'circle') {
        container.innerHTML = `
            <label>Radio de la Zona (en metros)</label>
            <input type="number" id="create-radius" value="30" step="0.5" required>
        `;
    } else if (type === 'box') {
        container.innerHTML = `
            <div style="display: flex; gap: 10px;">
                <div style="flex: 1;">
                    <label>Largo (X)</label>
                    <input type="number" id="create-size-x" value="20" required>
                </div>
                <div style="flex: 1;">
                    <label>Ancho (Y)</label>
                    <input type="number" id="create-size-y" value="20" required>
                </div>
                <div style="flex: 1;">
                    <label>Alto (Z)</label>
                    <input type="number" id="create-size-z" value="15" required>
                </div>
            </div>
        `;
    } else if (type === 'poly') {
        container.innerHTML = `
            <div style="display: flex; gap: 10px;">
                <div style="flex: 1;">
                    <label>Altura Min (Z)</label>
                    <input type="number" id="create-min-z" placeholder="Auto" step="0.1">
                </div>
                <div style="flex: 1;">
                    <label>Altura Max (Z)</label>
                    <input type="number" id="create-max-z" placeholder="Auto" step="0.1">
                </div>
            </div>
            <p style="font-size: 11px; color: #10b981; margin-top: 5px;"><i class="fa-solid fa-circle-info"></i> Iniciarás la herramienta de dibujado en el mundo al crear.</p>
        `;
    }
}

// Enviar formulario para Crear Zona
document.getElementById('create-zone-form').addEventListener('submit', function(e) {
    e.preventDefault();
    
    const name = document.getElementById('create-name').value;
    const zType = document.getElementById('create-zone-type').value;
    const rpType = document.getElementById('create-rp-type').value;
    
    const zoneData = {
        name: name,
        zoneType: zType,
        roleplayType: rpType,
    };
    
    if (zType === 'circle') {
        zoneData.dimensions = { radius: parseFloat(document.getElementById('create-radius').value) };
    } else if (zType === 'box') {
        zoneData.dimensions = {
            x: parseFloat(document.getElementById('create-size-x').value),
            y: parseFloat(document.getElementById('create-size-y').value),
            z: parseFloat(document.getElementById('create-size-z').value)
        };
    } else if (zType === 'poly') {
        zoneData.dimensions = {
            minZ: parseFloat(document.getElementById('create-min-z').value) || 0.0,
            maxZ: parseFloat(document.getElementById('create-max-z').value) || 0.0
        };
    }
    
    if (zType === 'poly') {
        // Para polígonos, cerrar la tablet y activar el trazador
        document.getElementById('admin-tablet').classList.add('hide-tablet');
        fetch(`https://${GetParentResourceName()}/drawPolygon`, {
            method: 'POST',
            body: JSON.stringify(zoneData)
        });
    } else {
        // Enviar creación normal (usa la posición del jugador en cliente)
        fetch(`https://${GetParentResourceName()}/createZone`, {
            method: 'POST',
            body: JSON.stringify(zoneData)
        });
        
        // Volver a la lista
        document.getElementById('create-name').value = '';
        switchTab('manage-tab');
    }
});

// Botón Usar Mi Posición Actual
document.getElementById('use-my-pos-btn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/requestMyPos`, {
        method: 'POST'
    });
});

// ==========================================
// EDITOR DE ZONA ESPECÍFICA (MODAL)
// ==========================================

function OpenZoneForEdit(id) {
    currentEditingZone = GetZoneById(id);
    if (!currentEditingZone) return;
    
    document.getElementById('editing-zone-name').textContent = currentEditingZone.name;
    document.getElementById('edit-name-input').value = currentEditingZone.name;
    
    // Checkboxes visuales
    document.getElementById('edit-blip-checkbox').checked = currentEditingZone.visual.blip || false;
    document.getElementById('edit-radius-checkbox').checked = currentEditingZone.visual.radiusBlip || false;
    document.getElementById('edit-marker-checkbox').checked = currentEditingZone.visual.marker || false;
    document.getElementById('edit-priority-input').value = currentEditingZone.priority || 0;
    
    // Picker de Color
    const visual = currentEditingZone.visual || {};
    const color = visual.color || { r: 40, g: 180, b: 90, a: 100 };
    
    // Convertir RGB a HEX
    const rgbToHex = (r, g, b) => '#' + [r, g, b].map(x => {
        const hex = x.toString(16);
        return hex.length === 1 ? '0' + hex : hex;
    }).join('');
    
    document.getElementById('edit-color-picker').value = rgbToHex(color.r, color.g, color.b);
    document.getElementById('edit-color-alpha').value = color.a;
    document.getElementById('alpha-val').textContent = color.a;
    
    // Renderizar switches de reglas
    const rulesContainer = document.getElementById('edit-rules-container');
    rulesContainer.innerHTML = '';
    
    const activeRules = currentEditingZone.rules || {};
    
    for (const [key, def] of Object.entries(RULE_DEFINITIONS)) {
        const item = document.createElement('div');
        item.className = 'rule-toggle-item';
        
        const currentVal = activeRules[key] !== undefined ? activeRules[key] : false;
        
        let controlHtml = '';
        if (typeof currentVal === 'boolean') {
            const checked = currentVal ? 'checked' : '';
            controlHtml = `
                <label class="switch-label">
                    <input type="checkbox" class="rule-checkbox-btn" data-key="${key}" ${checked}>
                    <span class="slider"></span>
                </label>
            `;
        } else if (typeof currentVal === 'number') {
            controlHtml = `
                <input type="number" class="rule-number-input" data-key="${key}" value="${currentVal}" style="width: 80px; padding: 6px; font-size:12px;">
            `;
        }
        
        item.innerHTML = `
            <div class="toggle-info">
                <span>${def.label}</span>
                <small>${def.desc}</small>
            </div>
            ${controlHtml}
        `;
        rulesContainer.appendChild(item);
    }
    
    switchTab('edit-tab');
}

// Slider de Alfa
document.getElementById('edit-color-alpha').addEventListener('input', function() {
    document.getElementById('alpha-val').textContent = this.value;
});

// Botón Volver
document.getElementById('back-to-list-btn').addEventListener('click', function() {
    switchTab('manage-tab');
});

// Guardar Edición
document.getElementById('save-zone-btn').addEventListener('click', function() {
    if (!currentEditingZone) return;
    
    const hexToRgb = (hex) => {
        const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        return result ? {
            r: parseInt(result[1], 16),
            g: parseInt(result[2], 16),
            b: parseInt(result[3], 16)
        } : { r: 40, g: 180, b: 90 };
    };
    
    const hexColor = document.getElementById('edit-color-picker').value;
    const rgb = hexToRgb(hexColor);
    const alpha = parseInt(document.getElementById('edit-color-alpha').value);
    
    currentEditingZone.name = document.getElementById('edit-name-input').value;
    currentEditingZone.priority = parseInt(document.getElementById('edit-priority-input').value) || 0;
    
    currentEditingZone.visual = {
        blip: document.getElementById('edit-blip-checkbox').checked,
        radiusBlip: document.getElementById('edit-radius-checkbox').checked,
        marker: document.getElementById('edit-marker-checkbox').checked,
        sprite: currentEditingZone.visual.sprite || 389,
        scale: currentEditingZone.visual.scale || 0.8,
        colorIndex: currentEditingZone.visual.colorIndex || 2,
        color: {
            r: rgb.r,
            g: rgb.g,
            b: rgb.b,
            a: alpha
        }
    };
    
    // Guardar reglas editadas
    const rules = {};
    document.querySelectorAll('.rule-checkbox-btn').forEach(btn => {
        const key = btn.getAttribute('data-key');
        rules[key] = btn.checked;
    });
    document.querySelectorAll('.rule-number-input').forEach(input => {
        const key = input.getAttribute('data-key');
        rules[key] = parseFloat(input.value);
    });
    
    currentEditingZone.rules = rules;
    
    // Enviar al cliente
    fetch(`https://${GetParentResourceName()}/updateZone`, {
        method: 'POST',
        body: JSON.stringify({ id: currentEditingZone.id, data: currentEditingZone })
    });
    
    switchTab('manage-tab');
});

// Teletransportarse
document.getElementById('teleport-zone-btn').addEventListener('click', function() {
    if (!currentEditingZone) return;
    fetch(`https://${GetParentResourceName()}/teleportToZone`, {
        method: 'POST',
        body: JSON.stringify({ id: currentEditingZone.id })
    });
});

// Eliminar
document.getElementById('delete-zone-btn').addEventListener('click', function() {
    if (!currentEditingZone) return;
    const confirm = window.confirm("¿Seguro que deseas eliminar esta zona segura de forma permanente?");
    if (confirm) {
        fetch(`https://${GetParentResourceName()}/deleteZone`, {
            method: 'POST',
            body: JSON.stringify({ id: currentEditingZone.id })
        });
        switchTab('manage-tab');
    }
});
