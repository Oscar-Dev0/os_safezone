const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'os_safezone';

const RULE_DEFINITIONS = {
  disableWeapons: ['Desarmar al entrar', 'Guarda y bloquea las armas'],
  disableFiring: ['Bloquear disparos', 'Impide cualquier disparo'],
  disableMelee: ['Bloquear melee', 'Deshabilita golpes y patadas'],
  disableDriveBy: ['Bloquear drive-by', 'Impide disparar desde vehículos'],
  disableVehicleDamage: ['Proteger vehículos', 'Reduce o bloquea daños'],
  invinciblePlayers: ['Jugadores invencibles', 'Evita daño al jugador'],
  invincibleVehicles: ['Vehículos invencibles', 'Evita daño al vehículo'],
  disableCollisions: ['Sin colisiones', 'Evita choques en la zona'],
  maxVehicleSpeed: ['Velocidad máxima', 'Límite en km/h'],
  allowEmergencyWeapons: ['Armas de emergencia', 'Permite bypass a servicios'],
  hideWeaponOnEnter: ['Ocultar arma', 'Guarda el arma al entrar'],
  restoreWeaponOnExit: ['Restaurar arma', 'Recupera el arma al salir'],
  blockVehicleTheft: ['Bloquear robo', 'Impide robar vehículos'],
  blockFrisk: ['Bloquear cacheos', 'Impide revisar jugadores'],
  blockHandcuffs: ['Bloquear esposas', 'Impide esposar'],
  blockKidnap: ['Bloquear secuestro', 'Impide cargar o secuestrar'],
  blockInventory: ['Bloquear inventario', 'Impide abrir inventarios'],
  disableRoleplayActions: ['Bloquear acciones RP', 'Restringe acciones de rol']
};

let zones = [];
let editingZone = null;
let pendingDeleteId = null;
let tabletOpen = false;

const $ = (id) => document.getElementById(id);
const clone = (value) => JSON.parse(JSON.stringify(value));
const number = (value, fallback = 0) => Number.isFinite(Number(value)) ? Number(value) : fallback;
const esc = (value) => String(value ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));

async function post(endpoint, payload = {}) {
  try {
    const response = await fetch(`https://${RESOURCE}/${endpoint}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: JSON.stringify(payload)
    });
    const text = await response.text();
    try { return text ? JSON.parse(text) : {ok: true}; }
    catch { return {ok: response.ok, raw: text}; }
  } catch (error) {
    toast(`No se pudo comunicar con el recurso: ${error.message}`, 'error');
    return {ok: false, error: error.message};
  }
}

function toast(message, type = 'success') {
  const item = document.createElement('div');
  item.className = `toast ${type}`;
  item.textContent = message;
  $('toast-stack').appendChild(item);
  setTimeout(() => item.remove(), 3800);
}

function updateClock() {
  $('tablet-clock').textContent = new Date().toLocaleTimeString('es', {hour:'2-digit', minute:'2-digit'});
}
setInterval(updateClock, 1000); updateClock();

function normalizeZones(raw) {
  const list = Array.isArray(raw) ? raw : Object.values(raw || {});
  return list.filter(Boolean).map(z => ({...z, id: number(z.id)})).sort((a,b) => a.id - b.id);
}

function findZone(id) { return zones.find(z => z.id === number(id)) || null; }

function setZoneData(raw) {
  zones = normalizeZones(raw);
  $('zone-count').textContent = zones.length;
  $('settings-zone-count').textContent = zones.length;
  renderZones();
  if (editingZone) {
    const fresh = findZone(editingZone.id);
    if (fresh) editingZone = clone(fresh);
    else { editingZone = null; switchTab('manage-tab'); }
  }
}

function switchTab(id) {
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === id));
  document.querySelectorAll('.nav-item').forEach(b => b.classList.toggle('active', b.dataset.tab === id));
  const labels = {
    'manage-tab': ['Gestionar zonas', 'Administra, activa, edita o elimina zonas en tiempo real.'],
    'create-tab': ['Crear zona', 'Crea una zona usando tu posición actual.'],
    'edit-tab': ['Editor de zona', 'Modifica reglas, apariencia y prioridad.'],
    'settings-tab': ['Estado del sistema', 'Información de la integración activa.']
  };
  const [title, subtitle] = labels[id] || labels['manage-tab'];
  $('tab-title').textContent = title;
  $('tab-subtitle').textContent = subtitle;
  if (id === 'create-tab') renderDimensions();
}

function renderZones() {
  const query = $('zone-search').value.trim().toLowerCase();
  const filtered = zones.filter(z => {
    const haystack = `${z.id} ${z.name || ''} ${z.zoneType || ''} ${z.roleplayType || ''}`.toLowerCase();
    return haystack.includes(query);
  });
  const container = $('zones-list-container');
  container.innerHTML = '';
  $('empty-zones').classList.toggle('hidden', filtered.length !== 0);

  filtered.forEach(zone => {
    const coords = zone.coords || {};
    const card = document.createElement('article');
    card.className = 'zone-card';
    card.innerHTML = `
      <div class="zone-card-head"><h3>${esc(zone.name || `Zona ${zone.id}`)}</h3><span class="type">${esc(zone.roleplayType || 'IC')}</span></div>
      <div class="zone-meta">
        <div><span>ID / Geometría</span><b>#${zone.id} · ${esc(zone.zoneType || 'circle')}</b></div>
        <div><span>Prioridad</span><b>${number(zone.priority)}</b></div>
        <div><span>Coordenada X</span><b>${number(coords.x).toFixed(1)}</b></div>
        <div><span>Coordenada Y</span><b>${number(coords.y).toFixed(1)}</b></div>
      </div>
      <div class="zone-actions">
        <button class="secondary-btn edit-btn" data-id="${zone.id}">Editar</button>
        <button class="secondary-btn tp-btn" data-id="${zone.id}">TP</button>
        <button class="danger-btn quick-delete-btn" data-id="${zone.id}">Eliminar</button>
        <label class="switch" title="Activar o desactivar"><input class="toggle-btn" data-id="${zone.id}" type="checkbox" ${zone.enabled !== false ? 'checked' : ''}><i></i></label>
      </div>`;
    container.appendChild(card);
  });
}

function renderDimensions() {
  const type = $('create-zone-type').value;
  const box = $('dimension-inputs-container');
  if (type === 'circle') box.innerHTML = '<label class="full"><span>Radio (metros)</span><input id="create-radius" type="number" min="1" max="2000" step="0.5" value="30" required></label>';
  else if (type === 'box') box.innerHTML = '<label><span>Largo X</span><input id="create-size-x" type="number" min="1" value="20"></label><label><span>Ancho Y</span><input id="create-size-y" type="number" min="1" value="20"></label><label><span>Alto Z</span><input id="create-size-z" type="number" min="1" value="15"></label>';
  else box.innerHTML = '<label><span>Min Z</span><input id="create-min-z" type="number" step="0.1" placeholder="Auto"></label><label><span>Max Z</span><input id="create-max-z" type="number" step="0.1" placeholder="Auto"></label><div class="full"><span style="color:var(--muted);font-size:10px">Al crear, la tablet se cerrará para dibujar el polígono.</span></div>';
}

function openEditor(id) {
  const zone = findZone(id);
  if (!zone) return toast('La zona ya no existe.', 'error');
  editingZone = clone(zone);
  $('editing-zone-name').textContent = editingZone.name || `Zona ${editingZone.id}`;
  $('edit-name-input').value = editingZone.name || '';
  $('edit-priority-input').value = number(editingZone.priority);
  const visual = editingZone.visual || {};
  $('edit-blip-checkbox').checked = !!visual.blip;
  $('edit-radius-checkbox').checked = !!visual.radiusBlip;
  $('edit-marker-checkbox').checked = !!visual.marker;
  const color = visual.color || {r:40,g:180,b:90,a:100};
  $('edit-color-picker').value = rgbToHex(color.r, color.g, color.b);
  $('edit-color-alpha').value = number(color.a, 100);
  $('alpha-val').textContent = number(color.a, 100);
  renderRules(editingZone.rules || {});
  switchTab('edit-tab');
}

function renderRules(rules) {
  const container = $('edit-rules-container'); container.innerHTML = '';
  Object.entries(RULE_DEFINITIONS).forEach(([key, def]) => {
    const current = rules[key] ?? (key === 'maxVehicleSpeed' ? 0 : false);
    const row = document.createElement('div'); row.className = 'rule-item';
    const control = typeof current === 'number'
      ? `<input class="rule-number" data-rule="${key}" type="number" min="0" step="1" value="${number(current)}">`
      : `<label class="switch"><input class="rule-toggle" data-rule="${key}" type="checkbox" ${current ? 'checked' : ''}><i></i></label>`;
    row.innerHTML = `<div class="rule-copy"><b>${def[0]}</b><small>${def[1]}</small></div>${control}`;
    container.appendChild(row);
  });
}

function rgbToHex(r,g,b) { return '#' + [r,g,b].map(v => Math.max(0,Math.min(255,number(v))).toString(16).padStart(2,'0')).join(''); }
function hexToRgb(hex) { const m = /^#([0-9a-f]{6})$/i.exec(hex); return m ? {r:parseInt(m[1].slice(0,2),16),g:parseInt(m[1].slice(2,4),16),b:parseInt(m[1].slice(4,6),16)} : {r:40,g:180,b:90}; }

function requestDelete(id) {
  const zone = findZone(id);
  if (!zone) return toast('La zona ya no existe.', 'error');
  pendingDeleteId = zone.id;
  $('confirm-message').textContent = `Se eliminará “${zone.name}” (ID ${zone.id}) de la base de datos. Esta acción no se puede deshacer.`;
  $('confirm-modal').classList.remove('hidden');
}

async function closeTablet() {
  tabletOpen = false;
  $('admin-tablet').classList.add('hidden');
  $('admin-tablet').setAttribute('aria-hidden', 'true');
  $('confirm-modal').classList.add('hidden');
  await post('closeTablet');
}

window.addEventListener('message', ({data = {}}) => {
  if (data.action === 'showSafezone') {
    const root = $('safezone-container');
    if (!data.state) return root.classList.add('hidden');
    $('zone-name').textContent = data.zoneName || 'Zona segura';
    $('zone-tag').textContent = data.roleplayType || 'IC';
    $('safezone-card').className = `safezone-card type-${String(data.roleplayType || 'IC').toLowerCase()}`;
    const rules = data.rules || {};
    $('badge-weapons').classList.toggle('hidden', !rules.disableWeapons);
    $('badge-melee').classList.toggle('hidden', !rules.disableMelee);
    $('badge-god').classList.toggle('hidden', !rules.invinciblePlayers);
    $('badge-speed').classList.toggle('hidden', !(number(rules.maxVehicleSpeed) > 0));
    $('speed-limit-text').textContent = `${Math.round(number(rules.maxVehicleSpeed))} km/h`;
    root.classList.remove('hidden');
  }
  if (data.action === 'openTablet') {
    tabletOpen = true;
    setZoneData(data.zones);
    const framework = String(data.framework || 'standalone').toUpperCase();
    $('settings-framework').textContent = framework;
    $('settings-framework-card').textContent = framework;
    $('settings-debug').textContent = data.debug ? 'ACTIVO' : 'DESACTIVADO';
    $('settings-locale').textContent = data.locale || 'es';
    switchTab('manage-tab');
    $('admin-tablet').classList.remove('hidden');
    $('admin-tablet').setAttribute('aria-hidden', 'false');
  }
  if (data.action === 'updateZones') setZoneData(data.zones);
  if (data.action === 'operationResult') {
    toast(data.message || (data.success ? 'Operación completada.' : 'La operación falló.'), data.success ? 'success' : 'error');
    document.querySelectorAll('button:disabled, input:disabled').forEach(el => el.disabled = false);
    if (data.success && data.operation === 'delete') {
      editingZone = null; pendingDeleteId = null; $('confirm-modal').classList.add('hidden'); switchTab('manage-tab');
    }
  }
});

document.querySelectorAll('.nav-item').forEach(btn => btn.addEventListener('click', () => switchTab(btn.dataset.tab)));
$('close-tablet-btn').addEventListener('click', closeTablet);
window.addEventListener('keydown', e => { if (e.key === 'Escape' && tabletOpen) closeTablet(); });
$('zone-search').addEventListener('input', renderZones);
$('refresh-zones-btn').addEventListener('click', async () => { const r = await post('requestRefresh'); if (r?.ok !== false) toast('Sincronización solicitada.', 'info'); });
$('create-zone-type').addEventListener('change', renderDimensions);
$('use-my-pos-btn').addEventListener('click', () => post('requestMyPos'));
$('edit-color-alpha').addEventListener('input', e => $('alpha-val').textContent = e.target.value);
$('back-to-list-btn').addEventListener('click', () => switchTab('manage-tab'));
$('teleport-zone-btn').addEventListener('click', () => editingZone && post('teleportToZone', {id: editingZone.id}));
$('delete-zone-btn').addEventListener('click', () => editingZone && requestDelete(editingZone.id));
$('confirm-cancel').addEventListener('click', () => { pendingDeleteId = null; $('confirm-modal').classList.add('hidden'); });
$('confirm-accept').addEventListener('click', async function() {
  if (!pendingDeleteId) return;
  this.disabled = true;
  const result = await post('deleteZone', {id: pendingDeleteId});
  if (result?.ok === false) { this.disabled = false; toast(result.error || 'Solicitud inválida.', 'error'); }
});

$('zones-list-container').addEventListener('click', e => {
  const btn = e.target.closest('button'); if (!btn) return;
  const id = number(btn.dataset.id);
  if (btn.classList.contains('edit-btn')) openEditor(id);
  else if (btn.classList.contains('tp-btn')) post('teleportToZone', {id});
  else if (btn.classList.contains('quick-delete-btn')) requestDelete(id);
});
$('zones-list-container').addEventListener('change', async e => {
  if (!e.target.classList.contains('toggle-btn')) return;
  const input = e.target; input.disabled = true;
  const result = await post('toggleZone', {id:number(input.dataset.id), state:input.checked});
  if (result?.ok === false) { input.checked = !input.checked; input.disabled = false; }
});

$('create-zone-form').addEventListener('submit', async e => {
  e.preventDefault();
  const submit = e.submitter; if (submit) submit.disabled = true;
  const type = $('create-zone-type').value;
  const data = {name:$('create-name').value.trim(), zoneType:type, roleplayType:$('create-rp-type').value};
  if (!data.name) { if (submit) submit.disabled = false; return toast('Escribe un nombre para la zona.', 'error'); }
  if (type === 'circle') data.dimensions = {radius:number($('create-radius').value,30)};
  else if (type === 'box') data.dimensions = {x:number($('create-size-x').value,20),y:number($('create-size-y').value,20),z:number($('create-size-z').value,15)};
  else data.dimensions = {minZ:number($('create-min-z').value),maxZ:number($('create-max-z').value)};
  const result = await post(type === 'poly' ? 'drawPolygon' : 'createZone', data);
  if (result?.ok === false) { if (submit) submit.disabled = false; return toast(result.error || 'No se pudo enviar la zona.', 'error'); }
  if (type === 'poly') { tabletOpen = false; $('admin-tablet').classList.add('hidden'); }
  else { $('create-name').value = ''; switchTab('manage-tab'); }
  setTimeout(() => { if (submit) submit.disabled = false; }, 1200);
});

$('save-zone-btn').addEventListener('click', async function() {
  if (!editingZone) return;
  const name = $('edit-name-input').value.trim(); if (!name) return toast('El nombre no puede estar vacío.', 'error');
  this.disabled = true;
  const data = clone(editingZone); data.name = name; data.priority = number($('edit-priority-input').value);
  const rgb = hexToRgb($('edit-color-picker').value); const oldVisual = data.visual || {};
  data.visual = {...oldVisual, blip:$('edit-blip-checkbox').checked, radiusBlip:$('edit-radius-checkbox').checked, marker:$('edit-marker-checkbox').checked, color:{...rgb,a:number($('edit-color-alpha').value,100)}};
  data.rules = {...(data.rules || {})};
  document.querySelectorAll('.rule-toggle').forEach(input => data.rules[input.dataset.rule] = input.checked);
  document.querySelectorAll('.rule-number').forEach(input => data.rules[input.dataset.rule] = number(input.value));
  const result = await post('updateZone', {id:data.id, data});
  if (result?.ok === false) { this.disabled = false; toast(result.error || 'No se pudo guardar.', 'error'); }
});

renderDimensions();
