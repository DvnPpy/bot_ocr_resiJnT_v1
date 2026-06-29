@echo off
title Setup Bot J^&T Offline 
cd /d "%~dp0"
color 0A

echo ===================================================
echo    SISTEM AUTO-SETUP BOT RESI J^&T OFFLINE 
echo ===================================================
echo.
echo [DETAIL] Memulai setup untuk repositori baru...
echo.

:: 1. TAHAP GIT
echo [TAHAP 1] Memeriksa ketersediaan mesin Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Git tidak ditemukan.
    echo [>] Mengunduh Git installer dari server resmi, Mohon tunggu...
    curl -L -o git_setup.exe https://github.com/git-for-windows/git/releases/download/v2.45.1.windows.1/Git-2.45.1-64-bit.exe
    
    echo [>] Menginstal Git ke sistem... 
    echo [!] PERHATIAN: Jika muncul pop-up Windows YES/NO, klik YES
    start /wait git_setup.exe /SILENT /NORESTART
    del git_setup.exe
    
    echo [V] Git berhasil diinstal!
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
) else (
    echo [V] Mesin Git sudah terdeteksi dan aman.
)

:: Konfigurasi Git Remote & Tarik Paksa dari Github
echo [>] Mengonfigurasi Git Remote ke repositori baru...
git init >nul 2>&1
git remote remove origin >nul 2>&1
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1

echo [>] Menarik paksa (Force Pull) data terbaru dari GitHub...
git fetch --all >nul 2>&1
git reset --hard origin/main >nul 2>&1
echo [V] Berhasil menarik data repository terbaru!

echo.
:: 2. TAHAP NPM
echo [TAHAP 2] Menginstal Modul Aplikasi Offline...
echo [>] Menarik mesin OCR lokal (Tesseract), Sharp, ExcelJS, dll...
call npm install

if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [X] FATAL ERROR: Instalasi modul gagal! Pastikan koneksi internet tersedia saat setup awal.
    pause
    exit /b
)
echo [V] Semua mesin dan modul terpasang sempurna!

echo.
:: 3. TAHAP KONFIGURASI API KEY (Engine 2)
echo [TAHAP 3] Konfigurasi API Key untuk Engine 2 (OCR.space)...
if not exist ".env" (
    copy ".env.example" ".env" >nul
    echo.
    echo ===================================================
    echo [!] FILE .env BERHASIL DIBUAT dari template.
    echo.
    echo [WAJIB] Buka file ".env" dengan Notepad, lalu isi
    echo         OCR_API_KEY_1 dan OCR_API_KEY_2 dengan
    echo         API Key dari https://ocr.space/ocrapi
    echo.
    echo         (Jika hanya pakai Engine 1/Tesseract,
    echo          langkah ini bisa dilewati)
    echo ===================================================
    echo.
    pause
) else (
    echo [V] File .env sudah ada, konfigurasi dilewati.
)

echo.
echo ===================================================
echo Setup Selesai! Silakan gunakan "Start_bot.bat"
echo ===================================================
pause
