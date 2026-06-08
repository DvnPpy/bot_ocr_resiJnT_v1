const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const exceljs = require('exceljs');
const sharp = require('sharp');
const { extractResiOffline } = require('./ocrEngine');

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer);

app.use(express.json());
app.use(express.static('public'));
app.use('/gagal', express.static('POD_GAGAL'));

const UPLOAD_DIR = './temp_uploads';
const GAGAL_DIR = './POD_GAGAL';
const DB_FILE = './database.json'; // Database Lokal Ringan

if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
if (!fs.existsSync(GAGAL_DIR)) fs.mkdirSync(GAGAL_DIR, { recursive: true });

// --- SISTEM DATABASE SEDERHANA ---
let db = { sessionFiles: [], successData: [] };
if (fs.existsSync(DB_FILE)) {
    db = JSON.parse(fs.readFileSync(DB_FILE, 'utf-8'));
}
const saveDB = () => fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));

const storage = multer.diskStorage({
    destination: UPLOAD_DIR,
    filename: (req, file, cb) => cb(null, Date.now() + '_' + file.originalname)
});
const upload = multer({ storage });

let queue = [];
let activeTask = 0;
let MAX_CONCURRENT = 10; // Default diatur ke 10 sesuai permintaan, tapi dilock UI

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
    io.emit('stats', {
        queue: queue.length,
        active: activeTask,
        success: db.successData.length,
        failed: fs.readdirSync(GAGAL_DIR).filter(f => f !== '.gitkeep').length
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
                if (!db.successData.some(d => d.resi === resi)) {
                    db.successData.push({ original: task.originalName, resi, info: `Skenario ${result.scenario}` });
                }
            }));
            db.sessionFiles.push(task.originalName);
            saveDB();
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

// --- API BARU SESUAI OPSI ---

app.post('/api/set-concurrent', (req, res) => {
    MAX_CONCURRENT = req.body.max || 10;
    res.json({ ok: true });
});

app.post('/api/clear-memory', (req, res) => {
    db.sessionFiles = []; // Kosongkan ingatan file
    saveDB();
    res.json({ ok: true, msg: 'Ingatan duplikasi file berhasil dihapus!' });
});

app.post('/api/cancel-queue', (req, res) => {
    queue.forEach(q => { if(fs.existsSync(q.path)) fs.unlinkSync(q.path); });
    queue = []; // Kosongkan antrean
    updateDashboard();
    res.json({ ok: true, msg: 'Semua antrean yang belum jalan dibatalkan.' });
});

app.post('/api/reset-stats', (req, res) => {
    db.successData = [];
    saveDB();
    updateDashboard();
    res.json({ ok: true, msg: 'Statistik sukses di-reset ke 0.' });
});

app.post('/api/retry', (req, res) => {
    const { filename } = req.body;
    const sourcePath = path.join(GAGAL_DIR, filename);
    const tempPath = path.join(UPLOAD_DIR, 'RETRY_' + filename);
    
    if (fs.existsSync(sourcePath)) {
        fs.renameSync(sourcePath, tempPath);
        queue.push({ path: tempPath, originalName: filename });
        io.emit('log', { type: 'warn', msg: `🔄 Mencoba ulang: ${filename}` });
        processQueue();
    }
    res.json({ ok: true });
});

// --- API LAMA ---
app.post('/api/upload', upload.array('photos'), (req, res) => {
    req.files.forEach(file => {
        if (db.sessionFiles.includes(file.originalname)) {
            io.emit('log', { type: 'warn', msg: `⚠️ Abaikan duplikat: ${file.originalname}` });
            if (fs.existsSync(file.path)) fs.unlinkSync(file.path); 
        } else {
            queue.push({ path: file.path, originalName: file.originalname });
        }
    });
    for (let i = activeTask; i < MAX_CONCURRENT; i++) processQueue();
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
        
        if (!db.successData.some(d => d.resi === resi)) {
            db.successData.push({ original: filename, resi, info: 'Manual Override' });
        }
    }));
    db.sessionFiles.push(filename);
    saveDB();
    if(fs.existsSync(sourcePath)) fs.unlinkSync(sourcePath); // Hapus dari folder gagal setelah sukses manual

    io.emit('log', { type: 'success', msg: `🛠️ Manual: ${filename} -> ${resiArray.join(', ')}` });
    updateDashboard();
    res.json({ ok: true });
});

app.get('/api/export', async (req, res) => {
    if (db.successData.length === 0) return res.status(400).send('Data kosong');
    const EXPORT_DIR = './manifests';
    if (!fs.existsSync(EXPORT_DIR)) fs.mkdirSync(EXPORT_DIR);

    const dateStr = new Date().toLocaleString('id-ID', { hour12: false }).replace(/[\/\s:]/g, '-');
    let generatedFiles = [];

    for (let i = 0; i < db.successData.length; i += 900) {
        const chunk = db.successData.slice(i, i + 900);
        const filename = `ManifesBotSavePod_${dateStr}_Part${Math.floor(i/900)+1}.xlsx`;
        const workbook = new exceljs.Workbook();
        const sheet = workbook.addWorksheet('Manifest');
        sheet.columns = [
            { header: 'No Resi', key: 'resi', width: 20 },
            { header: 'File Asal', key: 'original', width: 30 },
            { header: 'Keterangan', key: 'info', width: 20 }
        ];
        chunk.forEach(data => sheet.addRow(data));
        await workbook.xlsx.writeFile(path.join(EXPORT_DIR, filename));
        generatedFiles.push(filename);
    }
    res.json({ ok: true, files: generatedFiles });
});

httpServer.listen(31912, () => console.log('🚀 Server Aktif di http://localhost:31912'));
