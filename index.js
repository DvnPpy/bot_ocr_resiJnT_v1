const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const exceljs = require('exceljs');
const sharp = require('sharp');
const Database = require('better-sqlite3');
const chokidar = require('chokidar');

const { extractResiOffline } = require('./ocrEngine');
const { extractResiOcrSpace } = require('./ocrEngine2');

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer);

app.use(express.json());
app.use(express.static('public'));
app.use('/gagal', express.static('POD_GAGAL'));

const UPLOAD_DIR = './temp_uploads';
const GAGAL_DIR = './POD_GAGAL';
const DROP_ZONE = './DROP_ZONE';
const LOG_DIR = './logs'; // Folder Log Baru

if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
if (!fs.existsSync(GAGAL_DIR)) fs.mkdirSync(GAGAL_DIR, { recursive: true });
if (!fs.existsSync(DROP_ZONE)) fs.mkdirSync(DROP_ZONE, { recursive: true });
if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });

// --- SISTEM PENULISAN LOG REAL-TIME ---
const writeLog = (type, msg) => {
    const now = new Date();
    const dateStr = now.toISOString().split('T')[0]; 
    const timeStr = now.toTimeString().split(' ')[0]; 
    const logFile = path.join(LOG_DIR, `bot_log_${dateStr}.txt`);
    const logMessage = `[${timeStr}] [${type.toUpperCase()}] ${msg}\n`;

    // Tulis ke file secara real-time
    fs.appendFileSync(logFile, logMessage);

    // Kirim ke UI Dashboard
    io.emit('log', { type, msg });
    
    // Cetak ke terminal (opsional, bisa dihapus jika terminal mau sepi)
    console.log(logMessage.trim());
};

// --- SETUP DATABASE SQLITE ---
const db = new Database('database.db');

db.exec(`
    CREATE TABLE IF NOT EXISTS sessions (filename TEXT PRIMARY KEY);
    CREATE TABLE IF NOT EXISTS success_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_file TEXT,
        resi TEXT UNIQUE,
        info TEXT
    );
`);

const insertSession = db.prepare('INSERT OR IGNORE INTO sessions (filename) VALUES (?)');
const checkSession = db.prepare('SELECT filename FROM sessions WHERE filename = ?');
const insertResi = db.prepare('INSERT OR IGNORE INTO success_data (original_file, resi, info) VALUES (?, ?, ?)');
const countSuccess = db.prepare('SELECT COUNT(*) as total FROM success_data');
const getAllSuccess = db.prepare('SELECT original_file, resi, info FROM success_data');
const deleteAllSuccess = db.prepare('DELETE FROM success_data');
const deleteAllSessions = db.prepare('DELETE FROM sessions');

// --- VARIABEL GLOBAL ---
let queue = [];
let activeTask = 0;
let MAX_CONCURRENT = 10;
let SELECTED_ENGINE = 1;

// --- SISTEM FOLDER WATCHER (DROP ZONE) ---
chokidar.watch(DROP_ZONE, {
    ignored: /(^|[\/\\])\../,
    persistent: true,
    awaitWriteFinish: {
        stabilityThreshold: 2000,
        pollInterval: 100
    }
}).on('add', (filePath) => {
    const filename = path.basename(filePath);
    
    if (!/\.(jpg|jpeg|png)$/i.test(filename)) return;

    if (checkSession.get(filename)) {
        writeLog('warn', `⚠️ Abaikan duplikat dari folder: ${filename}`);
        try { fs.unlinkSync(filePath); } catch(e) {}
        return;
    }

    queue.push({ path: filePath, originalName: filename });
    for (let i = activeTask; i < MAX_CONCURRENT; i++) processQueue();
    updateDashboard();
});

// --- HELPER FUNCTIONS ---
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
        writeLog('info', `⚙️ Proses [Engine ${SELECTED_ENGINE}]: ${task.originalName}...`);
        
        let result;
        if (SELECTED_ENGINE === 1) {
            result = await extractResiOffline(task.path);
        } else {
            result = await extractResiOcrSpace(task.path);
        }

        const dailyFolder = getDailyFolder();

        if (result.success) {
            await Promise.all(result.resis.map(async (resi) => {
                const targetPath = path.join(dailyFolder, `${resi}.jpg`);
                if (fs.existsSync(task.path)) {
                    const fileSizeMB = fs.statSync(task.path).size / (1024 * 1024);
                    if (fileSizeMB > 2) await sharp(task.path).jpeg({ quality: 85 }).toFile(targetPath);
                    else fs.copyFileSync(task.path, targetPath);
                }
                insertResi.run(task.originalName, resi, result.scenario);
            }));
            
            insertSession.run(task.originalName);
            writeLog('success', `✅ Sukses: ${task.originalName} -> ${result.resis.join(', ')}`);
            if (fs.existsSync(task.path)) fs.unlinkSync(task.path); 
        } else {
            if (fs.existsSync(task.path)) {
                const targetPath = path.join(GAGAL_DIR, task.originalName);
                fs.renameSync(task.path, targetPath);
            }
            writeLog('error', `❌ Gagal: ${task.originalName}`);
            io.emit('new_failed', { filename: task.originalName });
        }
    } catch (err) {
        writeLog('error', `🚨 Error Sistem: ${task.originalName} - ${err.message}`);
    } finally {
        activeTask--;
        processQueue();
    }
};

// --- API ROUTES ---
app.post('/api/set-setup', (req, res) => {
    SELECTED_ENGINE = req.body.engine || 1;
    MAX_CONCURRENT = SELECTED_ENGINE === 2 ? 1 : (req.body.max || 10);
    writeLog('info', `[SISTEM] Bot diaktifkan dengan Engine ${SELECTED_ENGINE} | Max Proses: ${MAX_CONCURRENT}`);
    res.json({ ok: true });
});

app.post('/api/clear-memory', (req, res) => {
    deleteAllSessions.run();
    writeLog('warn', '[SISTEM] Ingatan duplikasi file berhasil dihapus dari SQLite.');
    res.json({ ok: true, msg: 'Ingatan duplikasi file berhasil dihapus dari SQLite!' });
});

app.post('/api/cancel-queue', (req, res) => {
    queue.forEach(q => { if(fs.existsSync(q.path)) fs.unlinkSync(q.path); });
    queue = []; 
    updateDashboard();
    writeLog('warn', '[SISTEM] Semua antrean dibatalkan oleh pengguna.');
    res.json({ ok: true, msg: 'Semua antrean yang belum jalan dibatalkan.' });
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
    writeLog('warn', '[SISTEM] Statistik Sukses & Gagal beserta foto berhasil disapu bersih.');
    res.json({ ok: true, msg: 'Statistik Sukses & Gagal beserta foto berhasil disapu bersih!' });
});

app.post('/api/retry', (req, res) => {
    const { filename } = req.body;
    const sourcePath = path.join(GAGAL_DIR, filename);
    const tempPath = path.join(UPLOAD_DIR, 'RETRY_' + filename);
    
    if (fs.existsSync(sourcePath)) {
        fs.renameSync(sourcePath, tempPath);
        queue.push({ path: tempPath, originalName: filename });
        writeLog('warn', `🔄 Mencoba ulang manual: ${filename}`);
        processQueue();
    }
    res.json({ ok: true });
});

app.post('/api/override', async (req, res) => {
    const { filename, resiString } = req.body;
    const resiArray = resiString.split(',').map(r => r.trim().toUpperCase()).filter(Boolean);
    const sourcePath = path.join(GAGAL_DIR, filename);
    if (!fs.existsSync(sourcePath)) return res.status(404).json({ error: 'File tidak ditemukan' });

    const dailyFolder = getDailyFolder();
    await Promise.all(resiArray.map(async (resi) => {
        const targetPath = path.join(dailyFolder, `${resi}.jpg`);
        const fileSizeMB = fs.statSync(sourcePath).size / (1024 * 1024);
        if (fileSizeMB > 2) await sharp(sourcePath).jpeg({ quality: 85 }).toFile(targetPath);
        else fs.copyFileSync(sourcePath, targetPath);
        
        insertResi.run(filename, resi, 'Manual Override');
    }));
    
    insertSession.run(filename);
    if(fs.existsSync(sourcePath)) fs.unlinkSync(sourcePath); 

    writeLog('success', `🛠️ Override Manual: ${filename} -> ${resiArray.join(', ')}`);
    updateDashboard();
    res.json({ ok: true });
});

app.get('/api/export', async (req, res) => {
    const allData = getAllSuccess.all();
    if (allData.length === 0) return res.status(400).send('Data kosong');
    
    const EXPORT_DIR = './manifests';
    if (!fs.existsSync(EXPORT_DIR)) fs.mkdirSync(EXPORT_DIR);

    const dateStr = new Date().toLocaleString('id-ID', { hour12: false }).replace(/[\/\s:]/g, '-');
    const filename = `Manifes_Bot_Save_Pod_${dateStr}_Lengkap.xlsx`;
    
    const workbook = new exceljs.Workbook();
    const sheet = workbook.addWorksheet('Manifest');
    
    sheet.columns = [
        { header: 'No Resi', key: 'resi', width: 25 },
        { header: 'File Asal', key: 'original_file', width: 35 },
        { header: 'Keterangan', key: 'info', width: 25 }
    ];
    
    let count = 0;
    allData.forEach(data => {
        sheet.addRow(data);
        count++;
        if (count % 900 === 0) sheet.addRow({}); 
    });
    
    await workbook.xlsx.writeFile(path.join(EXPORT_DIR, filename));
    writeLog('success', `[SISTEM] Export Excel berhasil: ${filename}`);
    res.json({ ok: true, files: [filename] });
});

// --- MANUAL UPLOAD (FALLBACK VIA WEB) ---
const storage = multer.diskStorage({
    destination: UPLOAD_DIR,
    filename: (req, file, cb) => cb(null, Date.now() + '_' + file.originalname)
});
const upload = multer({ storage });

app.post('/api/upload', upload.array('photos'), (req, res) => {
    req.files.forEach(file => {
        if (checkSession.get(file.originalname)) {
            writeLog('warn', `⚠️ Abaikan duplikat via Web: ${file.originalname}`);
            if (fs.existsSync(file.path)) fs.unlinkSync(file.path); 
        } else {
            queue.push({ path: file.path, originalName: file.originalname });
        }
    });
    for (let i = activeTask; i < MAX_CONCURRENT; i++) processQueue();
    res.json({ ok: true });
});

// --- JALANKAN SERVER ---
httpServer.listen(31912, () => {
    console.log('🚀 Server Aktif di http://localhost:31912');
    writeLog('info', '[SISTEM] Server Bot Dinyalakan.');
});
