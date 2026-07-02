@echo off
:: ===================================================
:: SISTEM ANTI-CLOSE (Mencegah CMD Tertutup Otomatis)
:: ===================================================
if "%~1"=="-anti-close" goto :main_script
cmd /k "%~f0" -anti-close
exit /b

:main_script
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
    echo [X] ERROR: Folder "node_modules" tidak ditemukan!
    echo Silakan jalankan installer/setup terlebih dahulu.
    echo.
    pause
    exit /b
)

:: 2. Proteksi Kedua: Cek Kunci API OCR
if not exist ".env" (
    color 0E
    echo [!] PERINGATAN: File .env tidak ditemukan!
    echo Mesin Engine 2 tidak akan bisa digunakan tanpa API Key.
    echo Pastikan file .env sudah disiapkan.
    echo.
)

:: 3. Fitur Auto-Update
echo [^>] Memeriksa pembaruan sistem di GitHub...
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1
git fetch origin main >nul 2>&1

if %errorlevel% neq 0 (
    echo [!] Gagal terhubung ke GitHub (Mungkin sedang offline).
    echo [^>] Melanjutkan dengan versi mesin lokal...
    goto :start_bot
)

echo [^>] Menyinkronkan data terbaru...
git reset --hard origin/main >nul 2>&1

echo [^>] Memeriksa modul NPM (Silakan tunggu sebentar)...
call npm install >nul 2>&1
echo [V] Mesin bot menggunakan versi paling mutakhir!

:start_bot
color 0A
echo.
echo [^>] Membuka Dashboard Web secara otomatis...
start http://localhost:31912

echo [^>] Memulai sistem Node.js di http://localhost:31912 ...
echo [i] Menyimpan log error otomatis ke "error_log.txt"...
echo [i] Biarkan jendela hitam ini tetap terbuka selama bot bekerja.
echo.

:: Menjalankan core bot utama dan MENCATAT error ke file teks
node index.js 2> error_log.txt

color 0C
echo.
echo ===================================================
echo [!] CRASH DETECTED: Bot telah berhenti berjalan!
echo ===================================================
echo Silakan buka file "error_log.txt" di folder ini untuk melihat 
echo pesan kerusakannya secara detail.
echo.
pause
