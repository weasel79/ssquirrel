"""
build_mapgen.py — generates art/tiles/terrain/terrain_mapgen.html
Self-contained terrain map generator with all tilesets embedded as base64.
Run from ssquirel/ directory.
"""
import base64, os

_HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.normpath(os.path.join(_HERE, '..')) + os.sep

ALL = [
    'grass','grass2','sand','water','gravel','dark','tile',
    'water_on_grass','sand_on_water','dirt_on_grass',
    'lava','abyss','abyss2','hole_t','toxic',
    'dirt_bright','dirt_dark','dirt3',
    'crop1','crop2','bush','corn',
]
AVAIL = [t for t in ALL if os.path.exists(DIR + t + '.png')]

b64 = {}
for t in AVAIL:
    with open(DIR + t + '.png', 'rb') as f:
        b64[t] = base64.b64encode(f.read()).decode()

tdata_js = 'const TDATA = {\n'
for t in AVAIL:
    tdata_js += '  "' + t + '": "data:image/png;base64,' + b64[t] + '",\n'
tdata_js += '};'

# Singles atlas (terrain_atlas_singles.png)
singles_path = DIR + 'terrain_atlas_singles.png'
if os.path.exists(singles_path):
    with open(singles_path, 'rb') as f:
        s64 = base64.b64encode(f.read()).decode()
    sdata_js = 'const SDATA = "data:image/png;base64,' + s64 + '";'
else:
    sdata_js = 'const SDATA = null;'
    s64 = ''

groups_js = r"""const GROUPS = [
  {label:'Terrain', items:[
    {id:'grass',       label:'grass',         def:60},
    {id:'grass2',      label:'grass 2',       def:0},
    {id:'sand',        label:'sand',          def:15},
    {id:'water',       label:'water',         def:0},
    {id:'gravel',      label:'gravel',        def:0},
    {id:'dark',        label:'dark',          def:0},
    {id:'tile',        label:'tile',          def:0},
  ]},
  {label:'Overlay', items:[
    {id:'water_on_grass', label:'water on grass', def:20},
    {id:'sand_on_water',  label:'sand on water',  def:0},
    {id:'dirt_on_grass',  label:'dirt on grass',  def:0},
  ]},
  {label:'Hazard', items:[
    {id:'lava',   label:'lava',   def:5},
    {id:'abyss',  label:'abyss',  def:0},
    {id:'abyss2', label:'abyss2', def:0},
    {id:'hole_t', label:'hole t', def:0},
    {id:'toxic',  label:'toxic',  def:0},
  ]},
  {label:'Dirt', items:[
    {id:'dirt_bright', label:'dirt bright', def:0},
    {id:'dirt_dark',   label:'dirt dark',   def:0},
    {id:'dirt3',       label:'dirt 3',      def:0},
  ]},
  {label:'Vegetation', items:[
    {id:'crop1', label:'crop 1', def:0},
    {id:'crop2', label:'crop 2', def:0},
    {id:'bush',  label:'bush',   def:0},
    {id:'corn',  label:'corn',   def:0},
  ]},
];"""

html = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Terrain Map Generator</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{display:flex;flex-direction:column;height:100vh;background:#111;
  color:#ccc;font:12px/1.5 'Consolas',monospace;overflow:hidden}
#bar{background:#1c1c1c;border-bottom:1px solid #2e2e2e;padding:5px 10px;
  display:flex;align-items:center;flex-wrap:wrap;gap:7px;flex-shrink:0}
.sep{width:1px;height:20px;background:#333;flex-shrink:0}
label{display:flex;align-items:center;gap:4px;color:#999;white-space:nowrap}
input[type=number]{width:52px;padding:2px 4px;background:#222;color:#ddd;
  border:1px solid #383838;border-radius:2px}
button{padding:3px 9px;background:#1a4a78;color:#ccc;border:none;
  border-radius:2px;cursor:pointer;font:inherit}
button:hover{background:#2a6aaa}
button:disabled{background:#1c1c1c;color:#444;cursor:default}
#stat{margin-left:auto;font-size:10px;color:#444;white-space:nowrap}
/* main layout */
#main{flex:1;display:flex;overflow:hidden}
/* left panel */
#panel{width:270px;min-width:270px;background:#161616;
  border-right:1px solid #2a2a2a;overflow-y:auto;flex-shrink:0;padding:2px 0}
.grp-head{padding:4px 8px;color:#555;font-size:10px;letter-spacing:.08em;
  text-transform:uppercase;background:#1a1a1a;
  border-top:1px solid #222;border-bottom:1px solid #222;
  cursor:pointer;user-select:none;display:flex;justify-content:space-between}
.grp-head:hover{color:#888}
.grp-body{padding:1px 0}
.mrow{display:flex;align-items:center;gap:4px;padding:2px 5px;transition:opacity .1s}
.mrow.zero{opacity:.32}
.mrow.is-main{background:#1d2a1d}
.mrow input[type=radio]{flex-shrink:0;accent-color:#4caf50;cursor:pointer;
  width:11px;height:11px;margin:0}
.mrow canvas{flex-shrink:0;image-rendering:pixelated;border:1px solid #2a2a2a;border-radius:1px}
.mlabel{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;
  white-space:nowrap;color:#bbb;font-size:11px}
.mrow.is-main .mlabel{color:#8bc34a}
.mslider{width:138px;cursor:pointer;accent-color:#3a7cba}
.mslider:disabled{opacity:.3;cursor:default}
.mpct{width:30px;text-align:right;color:#555;font-size:10px}
.mpct.main-lbl{color:#4a7a4a;font-size:9px}
.srow{padding-top:0;padding-bottom:3px;opacity:.7}
.mrow.zero + .srow{opacity:.18}
.slabel{width:28px;flex-shrink:0;color:#444;font-size:10px;text-align:right}
/* canvas area */
#cwrap{flex:1;overflow:auto;background:#0d0d0d;padding:12px;position:relative;
  display:flex;align-items:flex-start}
#map{image-rendering:pixelated;image-rendering:crisp-edges;display:block}
#empty{color:#2a2a2a;font-size:13px;position:absolute;top:50%;left:50%;
  transform:translate(-50%,-50%);pointer-events:none;white-space:nowrap}
</style>
</head>
<body>
<div id="bar">
  <label>W <input id="inW" type="number" value="24" min="4" max="200"></label>
  <label>H <input id="inH" type="number" value="12" min="4" max="120"></label>
  <div class="sep"></div>
  <label>Seed <input id="inSeed" type="number" value="42" min="0" max="9999999" style="width:66px"></label>
  <div class="sep"></div>
  <button id="btnGen" disabled onclick="doGenerate()">Generate</button>
  <button id="btnRnd" disabled onclick="doRandomSeed()" title="Pick random seed and generate">&#x1f3b2; Random</button>
  <div class="sep"></div>
  <button id="btnSave" disabled onclick="doSave()">Save .tmap</button>
  <button onclick="$('lfi').click()">Load .tmap</button>
  <input id="lfi" type="file" accept=".tmap,.json" style="display:none">
  <button id="btnPng" disabled onclick="doExportPNG()">Export PNG</button>
  <span id="stat">loading…</span>
</div>
<div id="main">
  <div id="panel"></div>
  <div id="cwrap">
    <div id="empty">Generate a map or load a .tmap file</div>
    <canvas id="map"></canvas>
  </div>
</div>
<script>
// ── Injected data ──────────────────────────────────────────────────────────
<<<TDATA>>>

<<<SDATA>>>

// ── Groups config ──────────────────────────────────────────────────────────
<<<GROUPS>>>

// ── Constants ──────────────────────────────────────────────────────────────
const TILE = 32;
const POS = {
  small:[0,0], icTL:[1,0], icTR:[2,0],
  small2:[0,1],icBL:[1,1], icBR:[2,1],
  cTL:[0,2], wT:[1,2], cTR:[2,2],
  wL:[0,3], solid:[1,3], wR:[2,3],
  cBL:[0,4], wB:[1,4], cBR:[2,4],
  alt1:[0,5], alt2:[1,5], alt3:[2,5],
};
const SINGLES_COLS = 32;
const SINGLES_ROWS = 3;

// ── State ──────────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);
const imgs  = {};   // id -> HTMLImageElement
const AVAIL = [];   // ids actually loaded
let singlesImg     = null;
let singlesDensity = 0;
let mainTerrain = 'grass';  // fills entire map as solid/alt background
let grid        = null;
let rng         = null;
let renderSeed  = 0;  // separate seed for render pass (alt tiles + singles)

// ── Seeded RNG (Mulberry32) ────────────────────────────────────────────────
function mkRng(s) {
  let seed = (s >>> 0) || 1;
  return () => {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

// ── Flat list of material items (filtered to loaded tilesets) ──────────────
function flatMats() {
  const out = [];
  for (const g of GROUPS)
    for (const m of g.items)
      if (AVAIL.includes(m.id)) out.push(m);
  return out;
}

// ── Tileset loading ────────────────────────────────────────────────────────
function loadTilesets() {
  const ps = Object.entries(TDATA).map(([id, src]) => new Promise(res => {
    const img = new Image();
    img.onload = () => { imgs[id] = img; AVAIL.push(id); res(); };
    img.onerror = res;
    img.src = src;
  }));
  return Promise.all(ps);
}

// ── Singles image loading ─────────────────────────────────────────────────
function loadSingles() {
  if (!SDATA) return Promise.resolve();
  return new Promise(res => {
    singlesImg = new Image();
    singlesImg.onload  = res;
    singlesImg.onerror = res;
    singlesImg.src = SDATA;
  });
}

// ── Panel / sliders ────────────────────────────────────────────────────────
function buildPanel() {
  const panel = $('panel');
  panel.innerHTML = '';

  for (const g of GROUPS) {
    const valid = g.items.filter(m => AVAIL.includes(m.id));
    if (!valid.length) continue;

    const hd = document.createElement('div');
    hd.className = 'grp-head';
    hd.innerHTML = g.label + '<span style="color:#333">&#9660;</span>';
    const body = document.createElement('div');
    body.className = 'grp-body';
    hd.onclick = () => {
      const hidden = body.style.display === 'none';
      body.style.display = hidden ? '' : 'none';
      hd.querySelector('span').style.transform = hidden ? '' : 'rotate(-90deg)';
    };
    panel.append(hd, body);

    for (const m of valid) {
      if (m.pct === undefined) m.pct = m.def ?? 0;

      const row = document.createElement('div');
      const isMain = m.id === mainTerrain;
      row.className = 'mrow' + (isMain ? ' is-main' : m.pct === 0 ? ' zero' : '');
      row.id = 'row_' + m.id;

      // Radio button — selects this terrain as main background
      const rb = document.createElement('input');
      rb.type = 'radio'; rb.name = 'mainTerrain'; rb.value = m.id;
      rb.checked = isMain;
      rb.addEventListener('change', () => setMainTerrain(m.id));
      row.appendChild(rb);

      // Swatch (solid tile col1 row3, 16×16)
      const sw = document.createElement('canvas');
      sw.width = sw.height = 16; sw.title = m.id;
      const ctx = sw.getContext('2d');
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(imgs[m.id], TILE, 3*TILE, TILE, TILE, 0, 0, 16, 16);
      row.appendChild(sw);

      const lbl = document.createElement('span');
      lbl.className = 'mlabel'; lbl.textContent = m.label;
      row.appendChild(lbl);

      const sl = document.createElement('input');
      sl.type = 'range'; sl.className = 'mslider';
      sl.min = 0; sl.max = 100; sl.value = m.pct;
      sl.id = 'sl_' + m.id;
      sl.addEventListener('input', () => onSlider(m.id, +sl.value));
      row.appendChild(sl);

      const sp = document.createElement('span');
      sp.className = 'mpct';
      sp.id = 'pct_' + m.id;
      sp.textContent = m.pct + '%';
      row.appendChild(sp);

      body.appendChild(row);

      // Size sub-row (blob count control)
      if (m.size === undefined) m.size = 80;
      const srow = document.createElement('div');
      srow.className = 'mrow srow';
      srow.id = 'srow_' + m.id;

      // Indent to align slider under the amount slider
      // radio(11) + gap(4) + swatch(16) + gap(4) = 35px
      const indent = document.createElement('span');
      indent.style.cssText = 'width:35px;flex-shrink:0';
      srow.appendChild(indent);

      const slbl = document.createElement('span');
      slbl.className = 'slabel'; slbl.textContent = 'size';
      srow.appendChild(slbl);

      const ssl = document.createElement('input');
      ssl.type = 'range'; ssl.className = 'mslider';
      ssl.min = 0; ssl.max = 100; ssl.value = m.size;
      ssl.id = 'sz_' + m.id;
      ssl.addEventListener('input', () => {
        m.size = +ssl.value;
        const sv = $('szv_' + m.id); if (sv) sv.textContent = sizeLabel(m.size);
      });
      srow.appendChild(ssl);

      const szv = document.createElement('span');
      szv.className = 'mpct'; szv.id = 'szv_' + m.id;
      szv.textContent = sizeLabel(m.size);
      srow.appendChild(szv);

      body.appendChild(srow);
    }
  }

  // ── Singles section ───────────────────────────────────────────────────
  if (singlesImg) {
    const hd = document.createElement('div');
    hd.className = 'grp-head';
    hd.innerHTML = 'Singles<span style="color:#333">&#9660;</span>';
    const body = document.createElement('div');
    body.className = 'grp-body';
    hd.onclick = () => {
      const hidden = body.style.display === 'none';
      body.style.display = hidden ? '' : 'none';
      hd.querySelector('span').style.transform = hidden ? '' : 'rotate(-90deg)';
    };

    const row = document.createElement('div');
    row.className = 'mrow' + (singlesDensity === 0 ? ' zero' : '');
    row.id = 'row_singles';

    // Spacer to align with terrain rows (no radio for singles)
    const spacer = document.createElement('span');
    spacer.style.cssText = 'width:11px;flex-shrink:0';
    row.appendChild(spacer);

    // Swatch: first tile from singles atlas
    const sw = document.createElement('canvas');
    sw.width = sw.height = 16; sw.title = 'singles';
    const sctx = sw.getContext('2d');
    sctx.imageSmoothingEnabled = false;
    sctx.drawImage(singlesImg, 0, 0, TILE, TILE, 0, 0, 16, 16);
    row.appendChild(sw);

    const lbl = document.createElement('span');
    lbl.className = 'mlabel'; lbl.textContent = 'density';
    row.appendChild(lbl);

    const sl = document.createElement('input');
    sl.type = 'range'; sl.className = 'mslider';
    sl.min = 0; sl.max = 100; sl.value = singlesDensity;
    sl.id = 'sl_singles';
    sl.addEventListener('input', () => {
      singlesDensity = +sl.value;
      const sp = $('pct_singles'); if (sp) sp.textContent = singlesDensity + '%';
      const r  = $('row_singles'); if (r) r.classList.toggle('zero', singlesDensity === 0);
      if (grid) { rng = mkRng(renderSeed); doRender(grid, grid[0].length, grid.length); }
    });
    row.appendChild(sl);

    const sp = document.createElement('span');
    sp.className = 'mpct'; sp.id = 'pct_singles';
    sp.textContent = singlesDensity + '%';
    row.appendChild(sp);

    body.appendChild(row);
    panel.append(hd, body);
  }

  updateSliderUI();
}

// Returns a short label describing approximate blob count for the size value
function sizeLabel(v) {
  if (v >= 90) return '\xd71';
  if (v >= 65) return 'few';
  if (v >= 35) return 'mid';
  if (v >= 10) return 'many';
  return 'scatter';
}

// ── Set main terrain ───────────────────────────────────────────────────────
// Just updates which terrain is the background fill — all sliders stay enabled.
function setMainTerrain(id) {
  const prev = mainTerrain;
  mainTerrain = id;
  const oldRow = $('row_' + prev);
  if (oldRow) {
    oldRow.classList.remove('is-main');
    const oldMat = flatMats().find(m => m.id === prev);
    oldRow.classList.toggle('zero', (oldMat?.pct ?? 0) === 0);
  }
  const newRow = $('row_' + id);
  if (newRow) { newRow.classList.add('is-main'); newRow.classList.remove('zero'); }
  updateSliderUI();
}

// Sliders are free — no auto-scaling. Generation normalises non-main pcts internally.
function onSlider(changedId, newVal) {
  const m = flatMats().find(m => m.id === changedId);
  if (m) m.pct = newVal;
  updateSliderUI();
}

function updateSliderUI() {
  const mats = flatMats();
  const total = mats.reduce((s, m) => s + m.pct, 0);
  for (const m of mats) {
    const sl  = $('sl_'  + m.id); if (!sl) continue;
    const sp  = $('pct_' + m.id);
    const row = $('row_' + m.id);
    sl.value = m.pct;
    sp.textContent = m.pct + '%';
    // main terrain row never dims to zero (it's always the background)
    row.classList.toggle('zero', m.pct === 0 && m.id !== mainTerrain);
  }
  if (!grid) $('stat').textContent = 'sum: ' + total + '%';
}

// ── 8-neighbour tile type resolution ──────────────────────────────────────
// Main terrain: always solid/alt — no walls or corners ever.
// Other terrains: full 8-neighbour logic, including at map border.
// Inner corner rule (corrected, see terraintileset.md):
//   void at NE diagonal → icBL   void at NW → icBR
//   void at SE diagonal → icTL   void at SW → icTR
function tileTypeFor(x, y, g, mat) {
  // Main terrain: interior fill only (solid + alt variations)
  if (mat === mainTerrain) {
    const r = rng();
    if (r < 0.07) return 'alt1';
    if (r < 0.14) return 'alt2';
    if (r < 0.21) return 'alt3';
    return 'solid';
  }

  const W = g[0].length, H = g.length;
  const s = (dx, dy) => {
    const nx=x+dx, ny=y+dy;
    return nx>=0 && nx<W && ny>=0 && ny<H && g[ny][nx]===mat;
  };
  const n=s(0,-1), so=s(0,1), w=s(-1,0), e=s(1,0);
  const nw=s(-1,-1), ne=s(1,-1), sw=s(-1,1), se=s(1,1);

  if (n && so && w && e) {
    if (!ne) return 'icBL';
    if (!nw) return 'icBR';
    if (!se) return 'icTL';
    if (!sw) return 'icTR';
    const r = rng();
    if (r < 0.07) return 'alt1';
    if (r < 0.14) return 'alt2';
    if (r < 0.21) return 'alt3';
    return 'solid';
  }
  if (!n && !w && so && e) return 'cTL';
  if (!n && !e && so && w) return 'cTR';
  if (!so && !w && n && e) return 'cBL';
  if (!so && !e && n && w) return 'cBR';
  if (!n) return 'wT';
  if (!so) return 'wB';
  if (!w) return 'wL';
  if (!e) return 'wR';
  return 'small';
}

// Returns true if all 4 cardinal neighbours share the same material
function isInterior(x, y, g) {
  const W = g[0].length, H = g.length;
  const mat = g[y][x];
  const ok = (dx, dy) => {
    const nx=x+dx, ny=y+dy;
    return nx>=0 && nx<W && ny>=0 && ny<H && g[ny][nx]===mat;
  };
  return ok(0,-1) && ok(0,1) && ok(-1,0) && ok(1,0);
}

// ── Minimum 2-tile width erosion ───────────────────────────────────────────
// Iteratively removes non-main cells that have zero same-material backing
// in either the horizontal or vertical axis.
// Map edges count as backing (terrain can end cleanly at the map border).
function erodeBlobs(g, W, H) {
  let changed = true;
  while (changed) {
    changed = false;
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const mat = g[y][x];
        if (mat === mainTerrain) continue;

        // Horizontal axis: map edge or same-material neighbour counts as backing
        let hBacking = 0;
        if (x === 0     || g[y][x-1] === mat) hBacking++;
        if (x === W - 1 || g[y][x+1] === mat) hBacking++;

        // Vertical axis
        let vBacking = 0;
        if (y === 0     || g[y-1][x] === mat) vBacking++;
        if (y === H - 1 || g[y+1][x] === mat) vBacking++;

        // Must have backing in BOTH axes to ensure minimum 2-tile width
        if (hBacking === 0 || vBacking === 0) {
          g[y][x] = mainTerrain;
          changed = true;
        }
      }
    }
  }
}

// ── BFS organic blob ───────────────────────────────────────────────────────
function growBlob(g, mat, target, claimed) {
  const W = g[0].length, H = g.length;

  const free = [];
  for (let y=0; y<H; y++)
    for (let x=0; x<W; x++)
      if (g[y][x] === mainTerrain && !claimed.has(y*W+x)) free.push({x,y});
  if (!free.length) return;

  const seed = free[Math.floor(rng() * free.length)];
  const frontier = [seed];
  const inQ = new Set([seed.y*W+seed.x]);
  let count = 0;

  while (frontier.length && count < target) {
    const fi = Math.floor(rng() * frontier.length);
    const {x, y} = frontier.splice(fi, 1)[0];
    const key = y*W+x;
    if (g[y][x] !== mainTerrain || claimed.has(key)) continue;
    g[y][x] = mat;
    claimed.add(key);
    count++;
    if (count >= target) break;
    for (const [dx,dy] of [[-1,0],[1,0],[0,-1],[0,1]]) {
      const nx=x+dx, ny=y+dy, nk=ny*W+nx;
      if (nx>=0 && nx<W && ny>=0 && ny<H &&
          g[ny][nx]===mainTerrain && !claimed.has(nk) && !inQ.has(nk) && rng()<0.65) {
        frontier.push({x:nx,y:ny});
        inQ.add(nk);
      }
    }
  }
}

// ── Generate map ───────────────────────────────────────────────────────────
function doGenerate() {
  const W    = Math.max(4, +$('inW').value);
  const H    = Math.max(4, +$('inH').value);
  const seed = +$('inSeed').value;
  rng = mkRng(seed);

  // Fill entire map with main terrain
  const g = Array.from({length:H}, () => new Array(W).fill(mainTerrain));
  const claimed = new Set();

  // Place other terrains as BFS blobs.
  // Sliders are free values — normalise non-main pcts among themselves so they
  // collectively fill however much of the map the user intends (their relative
  // proportions are preserved; main terrain covers whatever remains).
  const mats = flatMats()
    .filter(m => m.id !== mainTerrain && m.pct > 0)
    .sort((a,b) => b.pct - a.pct);

  const rawSum = mats.reduce((s, m) => s + m.pct, 0);

  for (const m of mats) {
    // Normalise: each terrain's share of the non-main area is m.pct / rawSum.
    // Scale to at most 100% of total tiles (clamp so blobs never exceed the map).
    const normPct = rawSum > 0 ? Math.min(100, m.pct / rawSum * 100) : 0;
    const totalTarget = Math.max(1, Math.round(W * H * normPct / 100));
    const sz = m.size ?? 80;
    // blobSize: lerp from 4 tiles (sz=0) to totalTarget (sz=100)
    const blobSize = Math.min(totalTarget, Math.max(4, Math.round(4 + (totalTarget - 4) * sz / 100)));
    const numBlobs = Math.max(1, Math.round(totalTarget / blobSize));
    const perBlob  = Math.max(4, Math.round(totalTarget / numBlobs));
    for (let i = 0; i < numBlobs; i++) growBlob(g, m.id, perBlob, claimed);
  }

  // Enforce minimum 2-tile width on all non-main blobs
  erodeBlobs(g, W, H);

  grid = g;
  renderSeed = seed ^ 0x3f7a2b1c;
  rng = mkRng(renderSeed);

  $('stat').textContent = W + 'x' + H + ' · ' + (W*H) + ' tiles · seed ' + seed;
  $('btnSave').disabled = $('btnPng').disabled = false;
  $('empty').style.display = 'none';
  doRender(g, W, H);
}

// ── Random seed ────────────────────────────────────────────────────────────
function doRandomSeed() {
  $('inSeed').value = Math.floor(Math.random() * 9999999);
  doGenerate();
}

// ── Render ─────────────────────────────────────────────────────────────────
// Pass 1: main terrain drawn on EVERY cell (provides background so
//         non-main terrain transparent pixels show correct tiles below).
// Pass 2: non-main terrains drawn on their cells (alpha-composited over pass 1).
// Pass 3: singles overlay.
function doRender(g, W, H) {
  const cv = $('map');
  cv.width = W*TILE; cv.height = H*TILE;
  const ctx = cv.getContext('2d');
  ctx.clearRect(0, 0, cv.width, cv.height);

  // 1. Main terrain covers every cell (background for transparent overlays)
  for (let y=0; y<H; y++)
    for (let x=0; x<W; x++)
      drawCell(ctx, g, x, y, mainTerrain);

  // 2. Non-main terrain layers (group order = render order)
  for (const grp of GROUPS)
    for (const m of grp.items) {
      if (!AVAIL.includes(m.id) || m.id === mainTerrain) continue;
      for (let y=0; y<H; y++)
        for (let x=0; x<W; x++)
          if (g[y][x] === m.id) drawCell(ctx, g, x, y, m.id);
    }

  // 3. Singles overlay (decorative plants/items on interior cells)
  drawSingles(ctx, g, W, H);
}

function drawCell(ctx, g, x, y, mat) {
  const img = imgs[mat]; if (!img) return;
  const ttype = tileTypeFor(x, y, g, mat);
  const [tc, tr] = POS[ttype];
  ctx.drawImage(img, tc*TILE, tr*TILE, TILE, TILE, x*TILE, y*TILE, TILE, TILE);
}

// ── Singles scatter pass ───────────────────────────────────────────────────
// Spawns random plant/item tiles from terrain_atlas_singles.png on interior
// cells only. singlesDensity 0-100 maps to 0-40% probability per cell.
function drawSingles(ctx, g, W, H) {
  if (!singlesImg || singlesDensity === 0) return;
  const prob = singlesDensity / 100 * 0.4;
  const N = SINGLES_COLS * SINGLES_ROWS;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!isInterior(x, y, g)) continue;
      if (rng() >= prob) continue;
      const idx = Math.floor(rng() * N);
      const sc = idx % SINGLES_COLS;
      const sr = Math.floor(idx / SINGLES_COLS);
      ctx.drawImage(singlesImg, sc*TILE, sr*TILE, TILE, TILE, x*TILE, y*TILE, TILE, TILE);
    }
  }
}

// ── Save .tmap ─────────────────────────────────────────────────────────────
function doSave() {
  if (!grid) return;
  const pct = {}, size = {};
  flatMats().forEach(m => {
    if (m.pct > 0) pct[m.id] = m.pct;
    if ((m.size ?? 80) !== 80) size[m.id] = m.size;
  });
  const data = {
    v:1, w:grid[0].length, h:grid.length,
    main:mainTerrain, seed:+$('inSeed').value,
    pct, size, singles:singlesDensity, grid,
  };
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([JSON.stringify(data)],{type:'application/json'}));
  a.download = 'map.tmap'; a.click();
  URL.revokeObjectURL(a.href);
}

// ── Load .tmap ─────────────────────────────────────────────────────────────
function doLoadFile(file) {
  const reader = new FileReader();
  reader.onload = e => {
    let data;
    try { data = JSON.parse(e.target.result); } catch { alert('Invalid .tmap'); return; }
    $('inW').value = data.w; $('inH').value = data.h;
    $('inSeed').value = data.seed ?? 42;

    if (data.main && AVAIL.includes(data.main)) {
      mainTerrain = data.main;
      document.querySelectorAll('input[name="mainTerrain"]').forEach(rb => {
        rb.checked = rb.value === mainTerrain;
      });
      flatMats().forEach(m => {
        const row = $('row_' + m.id); if (!row) return;
        const sl  = $('sl_'  + m.id);
        const sp  = $('pct_' + m.id);
        const isM = m.id === mainTerrain;
        row.classList.toggle('is-main', isM);
        if (sl) sl.disabled = isM;
        if (sp) { sp.className = 'mpct' + (isM ? ' main-lbl' : ''); }
      });
    }

    flatMats().forEach(m => {
      m.pct  = data.pct?.[m.id]  ?? 0;
      m.size = data.size?.[m.id] ?? 80;
      const ssl = $('sz_'  + m.id); if (ssl) ssl.value = m.size;
      const szv = $('szv_' + m.id); if (szv) szv.textContent = sizeLabel(m.size);
    });

    singlesDensity = data.singles ?? 0;
    const slS = $('sl_singles');  if (slS) slS.value = singlesDensity;
    const spS = $('pct_singles'); if (spS) spS.textContent = singlesDensity + '%';
    const rS  = $('row_singles'); if (rS)  rS.classList.toggle('zero', singlesDensity === 0);

    updateSliderUI();
    grid = data.grid;
    renderSeed = (data.seed ?? 42) ^ 0x3f7a2b1c;
    rng = mkRng(renderSeed);
    $('stat').textContent = data.w + 'x' + data.h + ' tiles · loaded from ' + file.name;
    $('btnSave').disabled = $('btnPng').disabled = false;
    $('empty').style.display = 'none';
    doRender(data.grid, data.w, data.h);
  };
  reader.readAsText(file);
}

// ── Export PNG ─────────────────────────────────────────────────────────────
function doExportPNG() {
  const a = document.createElement('a');
  a.href = $('map').toDataURL('image/png');
  a.download = 'terrain_map.png'; a.click();
}

// ── Init ───────────────────────────────────────────────────────────────────
Promise.all([loadTilesets(), loadSingles()]).then(() => {
  for (const g of GROUPS) g.items = g.items.filter(m => AVAIL.includes(m.id));
  flatMats().forEach(m => { m.pct = m.def ?? 0; m.size = 80; });
  buildPanel();
  $('btnGen').disabled = $('btnRnd').disabled = false;
  $('stat').textContent = AVAIL.length + ' tilesets ready';
});
$('lfi').addEventListener('change', e => e.target.files[0] && doLoadFile(e.target.files[0]));
</script>
</body>
</html>"""

html = (html
    .replace('<<<TDATA>>>', tdata_js)
    .replace('<<<SDATA>>>', sdata_js)
    .replace('<<<GROUPS>>>', groups_js))

out = os.path.join(_HERE, 'terrain_mapgen.html')
with open(out, 'w', encoding='utf-8') as f:
    f.write(html)

singles_kb = len(s64) // 1024 if os.path.exists(singles_path) else 0
total_kb = sum(len(v) for v in b64.values()) // 1024
print('Written:', out)
print('Tilesets:', len(AVAIL), '(' + str(total_kb) + ' KB base64)')
print('Singles atlas:', singles_kb, 'KB base64')
print('HTML size:', os.path.getsize(out) // 1024, 'KB')
