const express = require('express');
const path = require('path');
const fs = require('fs');
const XLSX = require('xlsx');

const app = express();
const PORT = process.env.PORT || 3000;

// Sajikan aplikasi Flutter penuh (web build = web-deploy, identik dengan APK).
// Folder `public` (aplikasi HTML/JS lama) sudah digantikan.
const STATIC_DIR = path.join(__dirname, 'web-deploy');
const DATA_FILE = path.join(__dirname, 'data', 'inventory.json');
const EXCEL_FILE = path.join(__dirname, global.EXCEL_FILENAME || 'Spesifikasi Komputer DPR (2).xlsx');

const EXACT_EXCEL_NAME = 'Spesifikasi Komputer DPR (2).xlsx';
let EXCEL_PATH = path.join(__dirname, EXACT_EXCEL_NAME);

// ---- Excel helper: convert any date value to ISO string ----
function normalizeDate(value, wb) {
  if (value === null || value === undefined || value === '') return '';
  if (typeof value === 'number') {
    // Excel serial date number
    if (wb) {
      // Use SheetJS date conversion
      const utc = new Date(Math.round((value - 25569) * 86400 * 1000));
      return formatDate(utc);
    }
  }
  if (typeof value === 'string') {
    // Could be dd/mm/yyyy
    const m = value.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})$/);
    if (m) {
      const d = parseInt(m[1], 10);
      const mo = parseInt(m[2], 10);
      let yr = parseInt(m[3], 10);
      if (yr < 100) yr += 2000;
      const dt = new Date(yr, mo - 1, d);
      return formatDate(dt);
    }
    // Could be already formatted
    return String(value).trim();
  }
  if (value instanceof Date) return formatDate(value);
  return String(value).trim();
}

function formatDate(dt) {
  if (isNaN(dt.getTime())) return '';
  const dd = String(dt.getDate()).padStart(2, '0');
  const mm = String(dt.getMonth() + 1).padStart(2, '0');
  const yyyy = dt.getFullYear();
  return `${dd}/${mm}/${yyyy}`;
}

function clean(v) {
  if (v === null || v === undefined) return '';
  if (typeof v === 'boolean') return v ? 'Yes' : 'No';
  return String(v).trim();
}

function findExcelFile() {
  // 1) exact name
  if (fs.existsSync(path.join(__dirname, EXACT_EXCEL_NAME))) {
    return path.join(__dirname, EXACT_EXCEL_NAME);
  }
  // 2) any .xlsx in project root
  const files = fs.readdirSync(__dirname).filter(f => f.toLowerCase().endsWith('.xlsx'));
  if (files.length) return path.join(__dirname, files[0]);
  return null;
}

// ---- Parse excel into array of objects ----
const COLUMNS = [
  'tanggalEvaluasi', 'kodeInventaris', 'plan', 'bagian', 'deviceName',
  'category', 'prosesor', 'motherboard', 'ram', 'storage', 'osWindows',
  'goal', 'perluUpgradeGanti', 'perluUpgradeRepair', 'statusUpgrade',
  'keterangan', 'statusStiker'
];

function parseExcel(filePath) {
  const wb = XLSX.readFile(filePath);
  const ws = wb.Sheets['Spesifikasi Komputer'] || wb.Sheets[wb.SheetNames[0]];
  if (!ws) return [];
  // header:1 -> rows
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });
  if (!rows.length) return [];
  const header = rows[0].map(h => String(h).toLowerCase().replace(/\s+/g, ' '));

  const indexOf = (label) => {
    // find header that contains the label
    return header.findIndex(h => {
      const t = h.toLowerCase();
      return label.split(' ').every(word => t.includes(word));
    });
  };

  const idx = {};
  for (const col of [
    ['tanggalEvaluasi','tanggal evaluasi'], ['kodeInventaris','kode inventaris'],
    ['plan','plan'], ['bagian','bagian'], ['deviceName','device name'],
    ['category','category'], ['prosesor','prosesor'], ['motherboard','motherboard'],
    ['ram','ram'], ['storage','storage'], ['osWindows','os windows'],
    ['goal','goal'], ['perluUpgradeGanti','perlu upgrade ganti'],
    ['perluUpgradeRepair','perlu upgrade repair'], ['statusUpgrade','status upgrade'],
    ['keterangan','keterangan'], ['statusStiker','status stiker']
  ]) {
    const i = indexOf(col[1]);
    idx[col[0]] = i >= 0 ? i : -1;
  }

  const result = [];
  for (let r = 1; r < rows.length; r++) {
    const row = rows[r];
    if (!row || (Array.isArray(row) && row.length === 0)) continue;
    // skip fully empty row
    let hasData = false;
    for (let c = 0; c < row.length; c++) {
      if (row[c] !== '' && row[c] !== null && row[c] !== undefined && row[c] !== false) { hasData = true; break; }
    }
    if (!hasData) continue;

    const get = (key) => {
      const i = idx[key];
      return i >= 0 && i < row.length ? row[i] : '';
    };

    const device = {
      id: `d_${Date.now().toString(36)}_${result.length}_${Math.random().toString(36).slice(2,7)}`,
      tanggalEvaluasi: normalizeDate(get('tanggalEvaluasi'), wb),
      kodeInventaris: clean(get('kodeInventaris')),
      plan: clean(get('plan')),
      bagian: clean(get('bagian')),
      deviceName: clean(get('deviceName')),
      category: clean(get('category')),
      prosesor: clean(get('prosesor')),
      motherboard: clean(get('motherboard')),
      ram: clean(get('ram')),
      storage: clean(get('storage')),
      osWindows: clean(get('osWindows')),
      goal: clean(get('goal')),
      perluUpgradeGanti: clean(get('perluUpgradeGanti')),
      perluUpgradeRepair: clean(get('perluUpgradeRepair')),
      statusUpgrade: clean(get('statusUpgrade')),
      keterangan: clean(get('keterangan')),
      statusStiker: clean(get('statusStiker')),
      createdAt: new Date().toISOString()
    };
    result.push(device);
  }
  return result;
}

// ---- Seed if empty ----
function loadData() {
  EXCEL_PATH = findExcelFile();
  if (fs.existsSync(DATA_FILE)) {
    try {
      const existing = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
      if (Array.isArray(existing) && existing.length > 0) {
        return existing;
      }
    } catch (e) { /* ignore */ }
  }
  // seed from excel
  if (EXCEL_PATH) {
    try {
      const seeded = parseExcel(EXCEL_PATH);
      if (seeded.length) {
        fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
        fs.writeFileSync(DATA_FILE, JSON.stringify(seeded, null, 2), 'utf8');
        return seeded;
      }
    } catch (e) {
      console.error('Gagal membaca Excel saat seed:', e.message);
    }
  }
  return [];
}

let inventory = loadData();

function save() {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(inventory, null, 2), 'utf8');
}

// ---------- MIDDLEWARE ----------
app.use(express.json({ limit: '5mb' }));
app.use(express.static(STATIC_DIR));

// ---------- API ----------
app.get('/api/devices', (req, res) => {
  res.json(inventory);
});

app.get('/api/devices/:id', (req, res) => {
  const d = inventory.find(x => x.id === req.params.id);
  if (!d) return res.status(404).json({ error: 'Tidak ditemukan' });
  res.json(d);
});

app.post('/api/devices', (req, res) => {
  const body = req.body || {};
  const nextNum = inventory
    .map(d => {
      const m = String(d.kodeInventaris || '').match(/K-(\d+)/i);
      return m ? parseInt(m[1], 10) : 0;
    })
    .reduce((a, b) => Math.max(a, b), 0) + 1;
  const kode = body.kodeInventaris || `K-${String(nextNum).padStart(3, '0')}`;
  const device = {
    id: `d_${Date.now().toString(36)}_${Math.random().toString(36).slice(2,8)}`,
    kodeInventaris: String(kode).trim(),
    tanggalEvaluasi: body.tanggalEvaluasi || '',
    plan: body.plan || '',
    bagian: body.bagian || '',
    deviceName: body.deviceName || '',
    category: body.category || 'Komputer',
    prosesor: body.prosesor || '',
    motherboard: body.motherboard || '',
    ram: body.ram || '',
    storage: body.storage || '',
    osWindows: body.osWindows || '',
    goal: body.goal || '',
    perluUpgradeGanti: body.perluUpgradeGanti || '',
    perluUpgradeRepair: body.perluUpgradeRepair || '',
    statusUpgrade: body.statusUpgrade || '',
    keterangan: body.keterangan || '',
    statusStiker: body.statusStiker || '',
    createdAt: new Date().toISOString()
  };
  inventory.unshift(device);
  save();
  res.status(201).json(device);
});

app.put('/api/devices/:id', (req, res) => {
  const i = inventory.findIndex(x => x.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: 'Tidak ditemukan' });
  const body = req.body || {};
  const keys = ['kodeInventaris','tanggalEvaluasi','plan','bagian','deviceName','category','prosesor','motherboard','ram','storage','osWindows','goal','perluUpgradeGanti','perluUpgradeRepair','statusUpgrade','keterangan','statusStiker'];
  for (const k of keys) {
    if (body[k] !== undefined) inventory[i][k] = String(body[k]).trim();
  }
  save();
  res.json(inventory[i]);
});

app.delete('/api/devices/:id', (req, res) => {
  const i = inventory.findIndex(x => x.id === req.params.id);
  if (i < 0) return res.status(404).json({ error: 'Tidak ditemukan' });
  const removed = inventory.splice(i, 1)[0];
  save();
  res.json(removed);
});

// Reimport / re-sync from excel (merges: keeps existing not in excel, updates seed by kode inventaris)
app.post('/api/import', (req, res) => {
  if (!EXCEL_PATH) return res.status(400).json({ error: 'File Excel tidak ditemukan di folder proyek.' });
  try {
    const fresh = parseExcel(EXCEL_PATH);
    if (!fresh.length) return res.status(400).json({ error: 'File Excel kosong / tidak terbaca.' });
    const merged = [];
    const freshByKode = new Map();
    for (const d of fresh) freshByKode.set(String(d.kodeInventaris).toUpperCase(), d);
    // keep existing that are NOT from the same kode, then apply fresh
    const freshKodes = new Set(freshByKode.keys());
    for (const d of inventory) {
      const k = String(d.kodeInventaris).toUpperCase();
      if (!freshKodes.has(k)) merged.push(d); // user-added / not in excel
    }
    inventory = [...merged, ...fresh];
    save();
    res.json({ count: inventory.length, imported: fresh.length });
  } catch (e) {
    res.status(500).json({ error: 'Gagal import: ' + e.message });
  }
});

// Serve app shell (Flutter) untuk setiap rute tak dikenal (SPA).
app.get('*', (req, res) => {
  res.sendFile(path.join(STATIC_DIR, 'index.html'));
});

app.listen(PORT, () => {
  console.log('==============================================');
  console.log('  INVENTARIS SPEK KOMPUTER - PWA (Flutter)');
  console.log('==============================================');
  console.log(`  Server : http://localhost:${PORT}`);
  console.log(`  Web    : ${STATIC_DIR}`);
  console.log(`  Excel  : ${EXCEL_PATH || '(TIDAK DITEMUKAN)'}`);
  console.log(`  Data   : ${inventory.length} perangkat dimuat`);
  console.log('----------------------------------------------');
  console.log('  Untuk di HP (satu jaringan WiFi):');
  console.log(`  http://<IP-ANDROID>:${PORT}`);
  console.log('==============================================');
});
