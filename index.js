const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const exceljs = require('exceljs');
const { extractResiOffline } = require('./ocrEngine');

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer);

app.use(express.json());
app.use(express.static('public')); // Folder untuk file HTML UI
app.use('/gagal', express.static('POD_GAGAL')); // Akses gambar gagal untuk UI

// Konfigurasi Folder
const UPLOAD_DIR = './temp_uploads';
const GAGAL_DIR = './POD_GAGAL';
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
if (!fs.existsSync(GAGAL_DIR)) fs.mkdirSync(GAGAL_DIR, { recursive: true });

// Multer (Penerima Upload File)
const storage = multer.diskStorage({
    destination: UPLOAD_DIR,
    filename: (req, file, cb) => cb(null, Date.now() + '_' + file.originalname)
});
const upload = multer({ storage });

// Database Sementara (Per Sesi)
let sessionFiles = new Set(); // Lapis 1: Cek nama file asli
let successData = []; // Data untuk Excel
let queue = [];
let activeTask = 0;
const MAX_CONCURRENT = 2; // Proses 2 foto sekaligus

// Helper Waktu & Folder Harian
const getDailyFolder = () => {
    const d = new Date();
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    const folder = `POD_${String(d.getDate()).padStart(2, '0')}_${bulan[d.getMonth()]}_${d.getFullYear()}`;
    if (!fs.existsSync(folder)) fs.mkdirSync(folder, { recursive: true });
    return folder;
};

// Emit status ke Frontend
const updateDashboard = () => {
    io.emit('stats', {
        queue: queue.length,
        active: activeTask,
        success: successData.length,
        failed: fs.readdirSync(GAGAL_DIR).length
    });
};

// Mesin Antrean (Queue System)
const processQueue = async () => {
    if (activeTask >= MAX_CONCURRENT || queue.length === 0) {
        updateDashboard();
        return;
    }
    
    activeTask++;
    const task = queue.shift();
    updateDashboard();

    try {
        io.emit('log', { type: 'info', msg: `⚙️ Sedang proses: ${task.originalName}...` });
        
        const result = await extractResiOffline(task.path);
        const dailyFolder = getDailyFolder();

        if (result.success) {
            result.resis.forEach(resi => {
                const targetPath = path.join(dailyFolder, `${resi}.jpg`);
                // Copy file ke nama resi (Lapis 2: Otomatis Overwrite jika sudah ada)
                fs.copyFileSync(task.path, targetPath);
                
                // Cek apakah resi sudah ada di data Excel, jika belum tambahkan
                if (!successData.some(d => d.resi === resi)) {
                    successData.push({ original: task.originalName, resi, info: `Skenario ${result.scenario}` });
                }
            });
            io.emit('log', { type: 'success', msg: `✅ Sukses: ${task.originalName} -> ${result.resis.join(', ')}` });
            fs.unlinkSync(task.path); // Hapus file temp
        } else {
            // Pindah ke folder GAGAL
            const targetPath = path.join(GAGAL_DIR, task.originalName);
            fs.renameSync(task.path, targetPath);
            io.emit('log', { type: 'error', msg: `❌ Gagal baca: ${task.originalName}` });
            io.emit('new_failed', { filename: task.originalName });
        }
    } catch (err) {
        io.emit('log', { type: 'error', msg: `🚨 Error sistem pada file ${task.originalName}` });
    } finally {
        activeTask--;
        processQueue();
    }
};

// API: Upload Files
app.post('/api/upload', upload.array('photos'), (req, res) => {
    let duplicateCount = 0;
    
    req.files.forEach(file => {
        // Lapis 1 Anti-Duplikat: Cek nama asli file
        if (sessionFiles.has(file.originalname)) {
            duplicateCount++;
            io.emit('log', { type: 'warn', msg: `⚠️ File ${file.originalname} diabaikan (Duplikasi)` });
            fs.unlinkSync(file.path); // Hapus dari temp
        } else {
            sessionFiles.add(file.originalname);
            queue.push({ path: file.path, originalName: file.originalname });
        }
    });

    processQueue();
    res.json({ ok: true, queued: req.files.length - duplicateCount, duplicate: duplicateCount });
});

// API: Manual Override
app.post('/api/override', (req, res) => {
    const { filename, resiString } = req.body;
    const resiArray = resiString.split(',').map(r => r.trim().toUpperCase()).filter(Boolean);
    
    const sourcePath = path.join(GAGAL_DIR, filename);
    if (!fs.existsSync(sourcePath)) return res.status(404).json({ error: 'File tidak ditemukan' });

    const dailyFolder = getDailyFolder();
    
    // Gandakan file untuk setiap resi (Pemisah Koma)
    resiArray.forEach(resi => {
        const targetPath = path.join(dailyFolder, `${resi}.jpg`);
        fs.copyFileSync(sourcePath, targetPath);
        
        if (!successData.some(d => d.resi === resi)) {
            successData.push({ original: filename, resi, info: 'Manual Override' });
        }
    });

    io.emit('log', { type: 'success', msg: `🛠️ Manual Selesai: ${filename} -> ${resiArray.join(', ')}` });
    updateDashboard();
    res.json({ ok: true });
    // Note: File asli dibiarkan di POD_GAGAL sesuai permintaan
});

// API: Export Excel per 900 AWB
app.get('/api/export', async (req, res) => {
    if (successData.length === 0) return res.status(400).send('Data kosong');

    const EXPORT_DIR = './manifests';
    if (!fs.existsSync(EXPORT_DIR)) fs.mkdirSync(EXPORT_DIR);

    const chunkSize = 900;
    const dateStr = new Date().toLocaleString('id-ID', { hour12: false }).replace(/[\/\s:]/g, '-');
    let generatedFiles = [];

    for (let i = 0; i < successData.length; i += chunkSize) {
        const chunk = successData.slice(i, i + chunkSize);
        const part = Math.floor(i / chunkSize) + 1;
        const filename = `ManifesBotSavePod_${dateStr}_Part${part}.xlsx`;
        const filePath = path.join(EXPORT_DIR, filename);

        const workbook = new exceljs.Workbook();
        const sheet = workbook.addWorksheet('Manifest');
        
        sheet.columns = [
            { header: 'No Resi', key: 'resi', width: 20 },
            { header: 'File Asal', key: 'original', width: 30 },
            { header: 'Keterangan', key: 'info', width: 20 }
        ];
        
        chunk.forEach(data => sheet.addRow(data));
        await workbook.xlsx.writeFile(filePath);
        generatedFiles.push(filename);
    }

    res.json({ ok: true, files: generatedFiles });
});

httpServer.listen(31912, () => {
    console.log('🚀 Server Offline aktif di http://localhost:31912');
});