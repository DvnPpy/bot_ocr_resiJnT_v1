@echo off
title Setup Bot J^&T Offline V2
cd /d "%~dp0"
color 0A

echo ===================================================
echo    SISTEM AUTO-SETUP BOT RESI J^&T OFFLINE V2
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

:: Konfigurasi Git Remote Repositori Baru
echo [>] Mengonfigurasi Git Remote ke repositori baru...
git init >nul 2>&1
git remote remove origin >nul 2>&1
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1

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
echo ===================================================
echo Setup Selesai! Silakan gunakan "start-bot.bat"
echo ===================================================
pause
