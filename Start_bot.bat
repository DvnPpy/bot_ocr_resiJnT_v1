@echo off
:: ===================================================
:: SISTEM ANTI-CLOSE & AUTO-INSTALLER (ALL-IN-ONE)
:: ===================================================
if "%~1"=="-anti-close" goto :main_script
cmd /k "%~f0" -anti-close
exit /b

:main_script
title Bot Resi J^&T Offline - Port 31912
cd /d "%~dp0"
color 0A

echo ===================================================
echo  SISTEM RUNNER, AUTO-INSTALL, ^& AUTO-UPDATE
echo ===================================================
echo.

:: 1. AUTO-INSTALLER (Sistem Perbaikan Mandiri)
echo [^>] Memeriksa kelengkapan mesin Node.js...
if not exist "node_modules\" (
    color 0E
    echo [!] Folder node_modules belum ada atau terhapus.
    echo [^>] Menjalankan INSTALASI OTOMATIS sekarang... -Mohon tunggu-
    
    call npm install
    call npm install dotenv better-sqlite3 chokidar sharp exceljs
    
    color 0A
    echo [V] Instalasi modul selesai! Sistem telah diperbaiki.
    echo.
) else (
    echo [V] Modul NPM sudah lengkap dan terpasang.
)

:: 2. Proteksi Kunci API OCR.space
if not exist ".env" (
    color 0E
    echo [!] PERINGATAN: File .env tidak ditemukan!
    echo Mesin Engine 2 tidak akan bisa digunakan tanpa API Key.
    echo.
)

:: 3. Fitur Auto-Update dari GitHub
echo [^>] Memeriksa pembaruan sistem di GitHub...
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1
git fetch origin main >nul 2>&1

:: Menghapus tanda kurung jebakan agar tidak crash
if %errorlevel% neq 0 (
    echo [!] Gagal terhubung ke GitHub - Mungkin jaringan sedang offline.
    echo [^>] Melanjutkan dengan versi mesin lokal...
    goto :start_bot
)

echo [^>] Menyinkronkan data terbaru...
git reset --hard origin/main >nul 2>&1

echo [^>] Memeriksa modul NPM tambahan - Silakan tunggu...
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
echo Berikut adalah rincian error dari sistem Node.js:
echo ---------------------------------------------------
type error_log.txt
echo ---------------------------------------------------
echo.
echo Silakan copy-paste tulisan error di atas dan kirimkan kepadaku 
echo agar kita bisa memperbaikinya bersama!
pause
