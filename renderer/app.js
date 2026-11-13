const DEFAULT_URL = 'https://iptv-org.github.io/iptv/countries/tr.m3u';
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const store = {
  get(k, d) { try { const v = localStorage.getItem(k); return v === null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} }
};

const state = {
  channels: [], view: [], group: 'Tümü', q: '', current: null,
  favs: new Set(store.get('favs', [])), url: store.get('url', DEFAULT_URL)
};
const video = $('#video'), stage = $('#stage');
let hideTimer = null, toastTimer = null;

/* ---------- M3U ---------- */
function attr(line, key) {
  const m = line.match(new RegExp(key + '="([^"]*)"'));
  return m && m[1] ? m[1] : null;
}
function parse(text) {
  const out = [];
  let cur = null;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (line.startsWith('#EXTINF')) {
      const c = line.lastIndexOf(',');
      const name = (c >= 0 ? line.slice(c + 1).trim() : '') || attr(line, 'tvg-name') || 'Kanal';
      cur = { name, logo: attr(line, 'tvg-logo'), group: (attr(line, 'group-title') || 'Diğer').split(';')[0] };
    } else if (line.startsWith('#EXTVLCOPT:') && cur) {
      const [k, ...v] = line.slice(11).split('=');
      const val = v.join('=');
      if (k === 'http-referrer') cur.referrer = val;
      if (k === 'http-user-agent') cur.ua = val;
    } else if (line && !line.startsWith('#') && cur) {
      cur.url = line;
      cur.id = cur.name + '|' + line;
      out.push(cur);
      cur = null;
    }
  }
  return out;
}

/* ---------- Liste ---------- */
function renderGroups() {
  const gs = ['Tümü', 'Favoriler', ...[...new Set(state.channels.map((c) => c.group))].sort((a, b) => a.localeCompare(b, 'tr'))];
  $('#groups').innerHTML = gs.map((g) => `<button class="chip ${g === state.group ? 'on' : ''}" data-g="${esc(g)}">${esc(g)}</button>`).join('');
}
function renderList() {
  $('#count').textContent = state.view.length + ' kanal';
  $('#list').innerHTML = state.view.map((c, i) => `
    <div class="item ${state.current && state.current.id === c.id ? 'on' : ''}" data-i="${i}">
      <div class="logo"><span>${esc((c.name[0] || '?').toUpperCase())}</span>${c.logo ? `<img loading="lazy" src="${esc(c.logo)}" onerror="this.remove()">` : ''}</div>
      <div class="meta"><div class="n">${esc(c.name)}</div><div class="g">${esc(c.group)}</div></div>
      <button class="star ${state.favs.has(c.id) ? 'on' : ''}" data-f="${i}">★</button>
    </div>`).join('') || '<div class="none">Kanal bulunamadı</div>';
}
function applyFilter() {
  const q = state.q.toLocaleLowerCase('tr');
  state.view = state.channels.filter((c) =>
    (state.group === 'Tümü' || (state.group === 'Favoriler' ? state.favs.has(c.id) : c.group === state.group)) &&
    (!q || c.name.toLocaleLowerCase('tr').includes(q)));
  renderList();
}
function toggleFav(c) {
  state.favs.has(c.id) ? state.favs.delete(c.id) : state.favs.add(c.id);
  store.set('favs', [...state.favs]);
  $('#btnFav').textContent = state.favs.has(c.id) ? '★' : '☆';
  applyFilter();
}

/* ---------- Oynatma ---------- */
let engine = null, playId = 0, playedId = 0, methods = [], watchdog = null;

function toast(msg, ms = 3000) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('on');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('on'), ms);
}
const isHls = (u) => /\.m3u8(\?|$)/i.test(u);
function methodsFor(c) {
  if (isHls(c.url)) return ['hls'];
  if (/\.(mp4|webm|mkv|mp3|aac)(\?|$)/i.test(c.url)) return ['native'];
  return ['mpegts', 'hls'];            // uzantisiz / .ts : canli MPEG-TS (Xtream tarzi)
}
const hlsUrl = (c) => (isHls(c.url) ? c.url : c.url.replace(/\.ts$/i, '') + '.m3u8');

function stopEngine() {
  clearTimeout(watchdog);
  if (engine) { try { engine.destroy(); } catch {} engine = null; }
  video.removeAttribute('src');
  video.load();
}
function fail(id) {
  if (id !== playId) return;
  if (methods.length) return startNext(id);
  stopEngine();
  toast('Yayın açılamadı. Hesabınız/bağlantı sınırı aktif mi kontrol edin veya VLC düğmesini deneyin.', 7000);
}
function startNext(id) {
  const c = state.current, kind = methods.shift();
  stopEngine();
  if (kind === 'mpegts' && window.mpegts && mpegts.isSupported()) {
    const p = mpegts.createPlayer({ type: 'mpegts', isLive: true, url: c.url }, { enableWorker: true, liveBufferLatencyChasing: true });
    p.attachMediaElement(video);
    p.load();
    p.on(mpegts.Events.ERROR, () => fail(id));
    engine = { destroy() { try { p.pause(); p.unload(); p.detachMediaElement(); } catch {} p.destroy(); } };
  } else if (kind === 'hls' && window.Hls && Hls.isSupported()) {
    const h = new Hls({ enableWorker: true });
    h.loadSource(hlsUrl(c));
    h.attachMedia(video);
    h.on(Hls.Events.ERROR, (_e, d) => { if (d.fatal) fail(id); });
    engine = { destroy() { h.destroy(); } };
  } else if (kind === 'native') {
    video.src = c.url;
  } else {
    return fail(id);
  }
  video.play().catch(() => {});
  watchdog = setTimeout(() => { if (playedId !== id) fail(id); }, 12000);   // 12 sn'de goruntu gelmezse sonraki yontem
}
function play(c) {
  state.current = c;
  store.set('last', c.id);
  $('#empty').style.display = 'none';
  $('#chName').textContent = c.name;
  $('#chGroup').textContent = c.group;
  $('#chLogo').innerHTML = `<span>${esc((c.name[0] || '?').toUpperCase())}</span>${c.logo ? `<img src="${esc(c.logo)}" onerror="this.remove()">` : ''}`;
  $('#btnFav').textContent = state.favs.has(c.id) ? '★' : '☆';
  window.api.setHeaders({ referrer: c.referrer, ua: c.ua });
  const id = ++playId;
  methods = methodsFor(c);
  startNext(id);
  renderList();
  const el = document.querySelector('.item.on');
  if (el) el.scrollIntoView({ block: 'nearest' });
  showOsd();
}
video.addEventListener('playing', () => { playedId = playId; });
video.addEventListener('error', () => { if (state.current && !engine) fail(playId); });
video.addEventListener('play', () => ($('#btnPlay').textContent = '⏸'));
video.addEventListener('pause', () => ($('#btnPlay').textContent = '▶'));

function showOsd() {
  stage.classList.add('show');
  stage.classList.remove('idle');
  clearTimeout(hideTimer);
  hideTimer = setTimeout(() => { stage.classList.remove('show'); stage.classList.add('idle'); }, 3000);
}
function step(d) {
  if (!state.view.length) return;
  const i = state.view.findIndex((c) => state.current && c.id === state.current.id);
  play(state.view[(i + d + state.view.length) % state.view.length]);
}
function toggleFs() { document.fullscreenElement ? document.exitFullscreen() : stage.requestFullscreen(); }
function toggleMute() { video.muted = !video.muted; $('#btnMute').textContent = video.muted ? '🔇' : '🔊'; }

/* ---------- Yukleme ---------- */
async function load() {
  toast('Kanal listesi yükleniyor…', 8000);
  let text = '';
  if (state.url !== '__local__') {
    try { text = await window.api.fetchText(state.url); window.api.cacheWrite(text); }
    catch (e) { toast('Liste indirilemedi (' + e.message + '). Kayıtlı liste kullanılıyor.', 5000); }
  }
  if (!text) text = await window.api.cacheRead();
  state.channels = parse(text);
  if (!state.channels.length) {
    $('#empty').style.display = '';
    toast('Kanal bulunamadı. Bir M3U dosyası seçin veya Ayarlar’dan bağlantı girin.', 6000);
  } else if (text) toast(state.channels.length + ' kanal yüklendi');
  renderGroups();
  applyFilter();
}
function importFile(f) {
  const r = new FileReader();
  r.onload = async () => {
    await window.api.cacheWrite(r.result);
    state.url = '__local__';
    store.set('url', state.url);
    state.group = 'Tümü';
    if (dlg.open) dlg.close();
    load();
  };
  r.readAsText(f);
}

/* ---------- Olaylar ---------- */
$('#q').addEventListener('input', (e) => { state.q = e.target.value; applyFilter(); });
$('#groups').addEventListener('click', (e) => {
  const b = e.target.closest('.chip');
  if (!b) return;
  state.group = b.dataset.g;
  renderGroups();
  applyFilter();
});
$('#list').addEventListener('click', (e) => {
  const f = e.target.closest('.star');
  if (f) return toggleFav(state.view[+f.dataset.f]);
  const it = e.target.closest('.item');
  if (it) play(state.view[+it.dataset.i]);
});
$('#btnPlay').onclick = () => (video.paused ? video.play() : video.pause());
$('#btnMute').onclick = toggleMute;
$('#vol').oninput = (e) => { video.volume = +e.target.value; video.muted = false; };
$('#btnFs').onclick = toggleFs;
$('#btnPip').onclick = () => { document.pictureInPictureElement ? document.exitPictureInPicture() : video.requestPictureInPicture().catch(() => {}); };
$('#btnFav').onclick = () => state.current && toggleFav(state.current);
video.addEventListener('dblclick', toggleFs);
video.addEventListener('click', () => (video.paused ? video.play() : video.pause()));
stage.addEventListener('mousemove', showOsd);
$('#btnReload').onclick = load;

const dlg = $('#dlg');
$('#btnSettings').onclick = () => { $('#urlInput').value = state.url === '__local__' ? '' : state.url; dlg.showModal(); };
$('#dlgCancel').onclick = () => dlg.close();
$('#btnDefault').onclick = () => { $('#urlInput').value = DEFAULT_URL; };
$('#btnFile').onclick = () => $('#fileInput').click();
$('#fileInput').onchange = (e) => { const f = e.target.files[0]; if (f) importFile(f); e.target.value = ''; };
$('#btnOpen').onclick = () => $('#fileInput').click();
document.addEventListener('dragover', (e) => e.preventDefault());
document.addEventListener('drop', (e) => { e.preventDefault(); const f = e.dataTransfer.files[0]; if (f) importFile(f); });
$('#btnVlc').onclick = async () => {
  if (!state.current) return;
  const ok = await window.api.openVlc(state.current.url);
  toast(ok ? 'VLC’de açılıyor…' : 'VLC bulunamadı. videolan.org adresinden kurabilirsiniz.', 4000);
};
$('#dlgSave').onclick = () => {
  const v = $('#urlInput').value.trim();
  if (!/^https?:\/\//i.test(v)) return toast('Geçerli bir http(s) bağlantısı girin.');
  state.url = v;
  store.set('url', v);
  dlg.close();
  load();
};

document.addEventListener('keydown', (e) => {
  if (/INPUT|TEXTAREA/.test(document.activeElement.tagName) || dlg.open) return;
  switch (e.key) {
    case 'ArrowUp': e.preventDefault(); step(-1); break;
    case 'ArrowDown': e.preventDefault(); step(1); break;
    case ' ': e.preventDefault(); video.paused ? video.play() : video.pause(); break;
    case 'f': case 'F': toggleFs(); break;
    case 'm': case 'M': toggleMute(); break;
  }
});

load().then(() => {
  const last = store.get('last', null);
  const c = last && state.channels.find((x) => x.id === last);
  if (c) play(c);
});
