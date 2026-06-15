const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const exceljs = require('exceljs');
const sharp = require('sharp');
const Database = require('better-sqlite3'); // Import SQLite
const chokidar = require('chokidar');       // Import Folder Watcher
const { extractResiOffline } = require('./ocrEngine');

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer);

app.use(express.json());
app.use(express.static('public'));
app.use('/gagal', express.static('POD_GAGAL'));

const UPLOAD_DIR = './temp_uploads';
const GAGAL_DIR = './POD_GAGAL';
const DROP_ZONE = './DROP_ZONE'; // Folder baru untuk drag & drop

if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
if (!fs.existsSync(GAGAL_DIR)) fs.mkdirSync(GAGAL_DIR, { recursive: true });
if (!fs.existsSync(DROP_ZONE)) fs.mkdirSync(DROP_ZONE, { recursive: true });

// --- MIGRASI DARI JSON KE SQLITE ---
const db = new Database('database.db');

// Buat tabel jika belum ada
db.exec(`
    CREATE TABLE IF NOT EXISTS sessions (filename TEXT PRIMARY KEY);
    CREATE TABLE IF NOT EXISTS success_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_file TEXT,
        resi TEXT UNIQUE,
        info TEXT
    );
`);

// Prepared statements untuk performa maksimal
const insertSession = db.prepare('INSERT OR IGNORE INTO sessions (filename) VALUES (?)');
const checkSession = db.prepare('SELECT filename FROM sessions WHERE filename = ?');
const insertResi = db.prepare('INSERT OR IGNORE INTO success_data (original_file, resi, info) VALUES (?, ?, ?)');
const countSuccess = db.prepare('SELECT COUNT(*) as total FROM success_data');
const getAllSuccess = db.prepare('SELECT original_file, resi, info FROM success_data');
const deleteAllSuccess = db.prepare('DELETE FROM success_data');
const deleteAllSessions = db.prepare('DELETE FROM sessions');

let queue = [];
let activeTask = 0;
let MAX_CONCURRENT = 10; 

// --- SISTEM FOLDER WATCHER (DROP ZONE) ---
// Membaca otomatis semua file dan subfolder yang masuk ke DROP_ZONE
chokidar.watch(DROP_ZONE, {
    ignored: /(^|[\/\\])\../, // Abaikan file tersembunyi
    persistent: true,
    awaitWriteFinish: {
        stabilityThreshold: 2000,
        pollInterval: 100
    } // Memastikan file sudah tercopy sepenuhnya sebelum diproses
}).on('add', (filePath) => {
    const filename = path.basename(filePath);
    
    // Pastikan hanya memproses file gambar
    if (!/\.(jpg|jpeg|png)$/i.test(filename)) return;

    // Cek apakah file sudah pernah diproses di memory SQLite
    if (checkSession.get(filename)) {
        io.emit('log', { type: 'warn', msg: `⚠️ Abaikan duplikat dari folder: ${filename}` });
        try { fs.unlinkSync(filePath); } catch(e) {} // Langsung hapus sampah duplikat
        return;
    }

    queue.push({ path: filePath, originalName: filename });
    for (let i = activeTask; i < MAX_CONCURRENT; i++) processQueue();
    updateDashboard();
});

const getDailyFolder = () => {
    const STORAGE_DIR = './pod_storage';
    if (!fs.existsSync(STORAGE_DIR)) fs.mkdirSync(STORAGE_DIR, { recursive: true });
    const d = new Date();
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    const folderPath = path.join(STORAGE_DIR, `POD_${String(d.getDate()).padStart(2, '0')}_${bulan[d.getMonth()]}_${d.getFullYear()}`);
    if (!fs.existsSync(folderPath)) fs.mkdirSync(folderPath, { recursive: true });
    return folderPath;
};

const updateDashboard = () => {
    const lifetimeCount = countSuccess.get().total;
    io.emit('stats', {
        queue: queue.length,
        active: activeTask,
        success: lifetimeCount,
        failed: fs.readdirSync(GAGAL_DIR).filter(f => f !== '.gitkeep').length,
        lifetime: lifetimeCount
    });
};

const processQueue = async () => {
    if (activeTask >= MAX_CONCURRENT || queue.length === 0) {
        updateDashboard();
        return;
    }
    
    activeTask++;
    const task = queue.shift();
    updateDashboard();

    try {
        io.emit('log', { type: 'info', msg: `⚙️ Proses: ${task.originalName}...` });
        const result = await extractResiOffline(task.path);
        const dailyFolder = getDailyFolder();

        if (result.success) {
            await Promise.all(result.resis.map(async (resi) => {
                const targetPath = path.join(dailyFolder, `${resi}.jpg`);
                if (fs.existsSync(task.path)) {
                    const fileSizeMB = fs.statSync(task.path).size / (1024 * 1024);
                    if (fileSizeMB > 2) await sharp(task.path).jpeg({ quality: 85 }).toFile(targetPath);
                    else fs.copyFileSync(task.path, targetPath);
                }
                
                // Simpan ke SQLite
                insertResi.run(task.originalName, resi, `Skenario ${result.scenario}`);
            }));
            
            insertSession.run(task.originalName);
            io.emit('log', { type: 'success', msg: `✅ Sukses: ${task.originalName} -> ${result.resis.join(', ')}` });
            if (fs.existsSync(task.path)) fs.unlinkSync(task.path); 
        } else {
            if (fs.existsSync(task.path)) {
                const targetPath = path.join(GAGAL_DIR, task.originalName);
                fs.renameSync(task.path, targetPath);
            }
            io.emit('log', { type: 'error', msg: `❌ Gagal: ${task.originalName}` });
            io.emit('new_failed', { filename: task.originalName });
        }
    } catch (err) {
        io.emit('log', { type: 'error', msg: `🚨 Error: ${task.originalName}` });
    } finally {
        activeTask--;
        processQueue();
    }
};

// ... (Simpan route API lainnya /set-concurrent, /cancel-queue seperti biasa) ...

app.post('/api/clear-memory', (req, res) => {
    deleteAllSessions.run();
    res.json({ ok: true, msg: 'Ingatan duplikasi file berhasil dihapus dari SQLite!' });
});

app.post('/api/reset-stats', (req, res) => {
    deleteAllSuccess.run();
    
    const files = fs.readdirSync(GAGAL_DIR);
    files.forEach(file => {
        const filePath = path.join(GAGAL_DIR, file);
        if (fs.lstatSync(filePath).isFile()) {
            try { fs.unlinkSync(filePath); } catch (e) {}
        }
    });

    updateDashboard();
    res.json({ ok: true, msg: 'Statistik Sukses & Gagal beserta foto berhasil disapu bersih!' });
});

// ... (Route override dan retry tetap sama, sesuaikan logika insert DB nya menggunakan prepared statement SQLite) ...

app.get('/api/export', async (req, res) => {
    const allData = getAllSuccess.all(); // Ambil semua data dari SQLite
    if (allData.length === 0) return res.status(400).send('Data kosong');
    
    const EXPORT_DIR = './manifests';
    if (!fs.existsSync(EXPORT_DIR)) fs.mkdirSync(EXPORT_DIR);

    const dateStr = new Date().toLocaleString('id-ID', { hour12: false }).replace(/[\/\s:]/g, '-');
    let generatedFiles = [];

    for (let i = 0; i < allData.length; i += 900) {
        const chunk = allData.slice(i, i + 900);
        const filename = `ManifesBotSavePod_${dateStr}_Part${Math.floor(i/900)+1}.xlsx`;
        const workbook = new exceljs.Workbook();
        const sheet = workbook.addWorksheet('Manifest');
        sheet.columns = [
            { header: 'No Resi', key: 'resi', width: 20 },
            { header: 'File Asal', key: 'original_file', width: 30 },
            { header: 'Keterangan', key: 'info', width: 20 }
        ];
        
        chunk.forEach(data => sheet.addRow(data));
        await workbook.xlsx.writeFile(path.join(EXPORT_DIR, filename));
        generatedFiles.push(filename);
    }
    res.json({ ok: true, files: generatedFiles });
});

const storage = multer.diskStorage({
    destination: UPLOAD_DIR,
    filename: (req, file, cb) => cb(null, Date.now() + '_' + file.originalname)
});
const upload = multer({ storage });

app.post('/api/upload', upload.array('photos'), (req, res) => {
    req.files.forEach(file => {
        if (checkSession.get(file.originalname)) {
            io.emit('log', { type: 'warn', msg: `⚠️ Abaikan duplikat: ${file.originalname}` });
            if (fs.existsSync(file.path)) fs.unlinkSync(file.path); 
        } else {
            queue.push({ path: file.path, originalName: file.originalname });
        }
    });
    for (let i = activeTask; i < MAX_CONCURRENT; i++) processQueue();
    res.json({ ok: true });
});

httpServer.listen(31912, () => console.log('🚀 Server Aktif di http://localhost:31912'));
