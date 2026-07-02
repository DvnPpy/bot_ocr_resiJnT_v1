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
    echo Pastikan file .env sudah diekstrak dari brankas zip.
    echo.
)

:: 3. Fitur Auto-Update Tangguh (Anti-Crash)
echo [^>] Memeriksa pembaruan sistem di GitHub...

:: Sambungkan ke repositori
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1
git fetch origin main >nul 2>&1

if %errorlevel% neq 0 (
    echo [!] Gagal terhubung ke GitHub (Mungkin sedang offline atau kuota habis).
    echo [^>] Melanjutkan dengan versi mesin lokal...
    goto :start_bot
)

:: Langsung tarik dan ratakan data dengan GitHub (Lebih aman daripada menghitung versi)
echo [^>] Menyinkronkan data terbaru...
git reset --hard origin/main >nul 2>&1

:: Pastikan modul NPM baru ikut terinstal secara diam-diam
call npm install >nul 2>&1
echo [V] Mesin bot dipastikan menggunakan versi paling mutakhir!

:start_bot
color 0A
echo.
echo [^>] Membuka Dashboard Web secara otomatis...
start http://localhost:31912

echo [^>] Memulai sistem Node.js di http://localhost:31912 ...
echo [i] Biarkan jendela hitam ini tetap terbuka selama bot bekerja.
echo.

:: Menjalankan core bot utama (Log akan tampil di layar)
node index.js

color 0C
echo.
echo [!] Bot telah berhenti berjalan secara tiba-tiba (Crash).
echo [i] Cek log pesan error berwarna merah di atas untuk mengetahui penyebabnya.
pause
