const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

const API = window.API_BASE || '';

const state = {
    users: [],
    editId: null
};

async function fetchServerInfo() {
    // If env provides server info at container runtime, use it for instant display
    if (window.__SERVER_INFO__) {
        const s = window.__SERVER_INFO__;
        $('#si-hostname').textContent = s.inventory_hostname || 'N/A';
        $('#si-clientip').textContent = s.ansible_host || s.clientIp || (s.ips && s.ips[0]) || 'N/A';
        $('#si-privateip').textContent = s.private_ip || (s.ips && s.ips.join(', ')) || 'N/A';
        $('#backend-panel').textContent = JSON.stringify({region: s.region, deployment_version: s.deployment_version}, null, 2);
        // Still attempt to refresh from /info endpoint to show dynamic values
    }

    try {
        const res = await fetch(`${API}/info`);
        if (!res.ok) throw new Error('Info endpoint failed');
        const data = await res.json();

        $('#si-hostname').textContent = data.hostname || $('#si-hostname').textContent;
        $('#si-clientip').textContent = (data.clientIp || data.ips?.[0]) || $('#si-clientip').textContent;
        $('#si-privateip').textContent = (data.ips && data.ips.join(', ')) || $('#si-privateip').textContent;

        $('#backend-panel').textContent = JSON.stringify({platform:data.platform, arch:data.arch, timestamp:data.timestamp}, null, 2);
    } catch (err) {
        console.warn('fetchServerInfo', err);
        if (!$('#backend-panel').textContent) {
            $('#backend-panel').textContent = 'Impossible de récupérer les informations du backend.';
        }
    }
}

async function loadUsers() {
    try {
        const res = await fetch(`${API}/db/users`);
        if (!res.ok) throw new Error('Échec récupération utilisateurs');
        const data = await res.json();
        state.users = data.users || [];
        renderUsers();
    } catch (err) {
        console.error(err);
        showToast('Erreur lors du chargement des utilisateurs');
    }
}

function renderUsers() {
    const tbody = $('#users-table tbody');
    tbody.innerHTML = '';
    for (const u of state.users) {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${u.id}</td>
            <td>${escapeHtml(u.name)}</td>
            <td>${escapeHtml(u.email)}</td>
            <td>${new Date(u.created_at || u.createdAt || Date.now()).toLocaleString()}</td>
            <td>
                <button class="action-btn btn-edit" data-id="${u.id}">✎</button>
                <button class="action-btn btn-del" data-id="${u.id}">🗑</button>
            </td>
        `;
        tbody.appendChild(tr);
    }

    $$('.btn-edit').forEach(b => b.addEventListener('click', onEditClick));
    $$('.btn-del').forEach(b => b.addEventListener('click', onDeleteClick));
}

function escapeHtml(s){ if(!s) return ''; return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

async function createUser() {
    const name = $('#name-input').value.trim();
    const email = $('#email-input').value.trim();
    if (!name || !email) { showToast('Nom et email requis'); return; }

    try {
        const res = await fetch(`${API}/db/users`, {
            method: 'POST', headers: {'Content-Type':'application/json'},
            body: JSON.stringify({ name, email })
        });
        if (res.status === 409) { showToast('Email déjà existant'); return; }
        if (!res.ok) throw new Error('Création échouée');
        $('#name-input').value=''; $('#email-input').value='';
        showToast('Utilisateur créé');
        await loadUsers();
    } catch (err) {
        console.error(err); showToast('Erreur création utilisateur');
    }
}

function onEditClick(e){
    const id = e.currentTarget.dataset.id;
    const user = state.users.find(u=>String(u.id)===String(id));
    if(!user) return showToast('Utilisateur introuvable');
    state.editId = id;
    $('#edit-name').value = user.name || '';
    $('#edit-email').value = user.email || '';
    $('#edit-modal').classList.remove('hidden');
}

function onDeleteClick(e){
    const id = e.currentTarget.dataset.id;
    if(!confirm('Supprimer cet utilisateur ?')) return;
    fetch(`${API}/db/users/${id}`, { method: 'DELETE' })
        .then(r=>{ if(!r.ok) throw new Error('delete failed'); return r.json(); })
        .then(()=>{ showToast('Utilisateur supprimé'); loadUsers(); })
        .catch(err=>{ console.error(err); showToast('Erreur suppression'); });
}

async function saveEdit(){
    const id = state.editId; if(!id) return;
    const name = $('#edit-name').value.trim();
    const email = $('#edit-email').value.trim();
    if(!name||!email) return showToast('Nom et email requis');
    try{
        const res = await fetch(`${API}/db/users/${id}`, { method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({name,email}) });
        if(!res.ok) throw new Error('update failed');
        $('#edit-modal').classList.add('hidden'); state.editId = null; showToast('Utilisateur mis à jour'); loadUsers();
    }catch(err){ console.error(err); showToast('Erreur mise à jour'); }
}

async function searchUsers(term){
    if(!term) return loadUsers();
    try{
        const res = await fetch(`${API}/db/users/search/${encodeURIComponent(term)}`);
        if(!res.ok) throw new Error('search failed');
        const data = await res.json(); state.users = data.users || []; renderUsers();
    }catch(err){ console.error(err); showToast('Erreur recherche'); }
}

function showToast(msg, ms=2500){ const t = $('#toast'); t.textContent=msg; t.classList.remove('hidden'); setTimeout(()=>t.classList.add('hidden'), ms); }

function setupHandlers(){
    $('#create-btn').addEventListener('click', createUser);
    $('#refresh-btn').addEventListener('click', loadUsers);
    $('#search-btn').addEventListener('click', ()=>searchUsers($('#search-input').value.trim()));
    $('#search-input').addEventListener('keydown', (e)=>{ if(e.key==='Enter') searchUsers(e.target.value.trim()); });
    $('#cancel-edit').addEventListener('click', ()=>{ $('#edit-modal').classList.add('hidden'); state.editId=null; });
    $('#save-edit').addEventListener('click', saveEdit);
}

document.addEventListener('DOMContentLoaded', ()=>{
    setupHandlers();
    fetchServerInfo();
    loadUsers();
});
