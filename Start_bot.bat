@echo off
title Bot Resi J^&T Offline - Port 31912
cd /d "%~dp0"
color 0A

echo ===================================================
echo  SISTEM RUNNER ^& AUTO-UPDATE BOT RESI J^&T
echo ===================================================
echo.

:: 1. Proteksi Awal: Cek Mesin NPM
if not exist "node_modules\" (
    color 0C
    echo [X] ERROR: Folder modul sistem tidak ditemukan!
    echo Silakan jalankan "Install_Semua_Mesin.bat" terlebih dahulu.
    echo.
    pause
    exit /b
)

:: 2. Proteksi Kedua: Cek Kunci API OCR
if not exist ".env" (
    color 0E
    echo [!] PERINGATAN: File .env tidak ditemukan!
    echo Mesin Engine 2 tidak akan bisa digunakan tanpa API Key.
    echo Pastikan file .env sudah diekstrak dari env_secure.zip.
    echo.
)

:: 3. Fitur Auto-Update Otomatis dari GitHub
echo [^>] Memeriksa pembaruan sistem di GitHub...

:: Memastikan link repositori sudah terpasang
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1
git fetch origin main >nul 2>&1

if %errorlevel% neq 0 (
    echo [!] Gagal terhubung ke GitHub (Mungkin komputer sedang Offline).
    echo [^>] Melanjutkan menjalankan bot dengan versi lokal yang tersedia...
    goto :start_bot
)

:: Hitung jumlah pembaruan (commit) yang tertinggal
set count=0
FOR /F "tokens=*" %%g IN ('git rev-list HEAD...origin/main --count 2^>nul') DO SET count=%%g

if %count% gtr 0 (
    color 0E
    echo.
    echo ===================================================
    echo [UPDATE] Ditemukan %count% pembaruan baru di GitHub!
    echo [^>] Mengunduh dan menyinkronkan data bot...
    echo ===================================================
    
    :: Tarik data terbaru (Aman, tidak akan menghapus .env karena sudah di-gitignore)
    git reset --hard origin/main >nul 2>&1
    
    :: Pastikan jika ada penambahan modul baru di pembaruan, ikut diinstal
    echo [^>] Memeriksa pembaruan modul NPM...
    call npm install >nul 2>&1
    
    color 0A
    echo.
    echo [V] Berhasil memperbarui data ke versi terbaru!
    echo ===================================================
) else (
    echo [V] Sistem bot sudah menggunakan versi paling mutakhir.
)

:start_bot
color 0A
echo.
echo [^>] Membuka Dashboard Web secara otomatis...
start http://localhost:31912

echo [^>] Memulai sistem Node.js di http://localhost:31912 ...
echo [i] Biarkan jendela hitam ini tetap terbuka selama bot bekerja.
echo.

:: Menjalankan core bot utama dan menangkap pesan error (crash) ke file teks
node index.js 2>> error_log.txt

color 0C
echo.
echo [!] Bot telah berhenti berjalan secara tiba-tiba (Crash).
echo [i] Silakan buka file "error_log.txt" di dalam folder ini untuk melihat detail kerusakannya.
pause
