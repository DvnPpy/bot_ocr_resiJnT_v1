@echo off
title Bot Resi J^&T Offline - Port 31912
cd /d "%~dp0"
color 0A

echo ===================================================
echo SISTEM RUNNER ^& AUTO-UPDATE BOT RESI J^&T
echo Repositori: https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git
echo ===================================================
echo.

:: 1. Proteksi Awal: Cek node_modules
if not exist "node_modules\" (
    echo [ERROR] Folder node_modules tidak ditemukan!
    echo Anda harus menjalankan "Install-bot.bat" terlebih dahulu.
    echo.
    pause
    exit /b
)

:: 2. Fitur Auto-Update Otomatis Sebelum Memulai Bot
echo [>] Memeriksa pembaruan di GitHub...
git fetch origin main >nul 2>&1

if %errorlevel% neq 0 (
    echo [!] Gagal terhubung ke GitHub (Offline / Internet terputus).
    echo [>] Melanjutkan menjalankan bot dengan versi lokal yang tersedia...
    goto :start_bot
)

:: Hitung jumlah commit yang tertinggal
set count=0
FOR /F "tokens=*" %%g IN ('git rev-list HEAD...origin/main --count 2^>nul') DO SET count=%%g

if %count% gtr 0 (
    color 0E
    echo.
    echo ===================================================
    echo [🚀 UPDATE] Ditemukan %count% pembaruan baru di GitHub!
    echo [>] Mengunduh dan memperbarui data bot...
    echo ===================================================
    git reset --hard origin/main
    echo.
    echo [V] Berhasil memperbarui data ke versi terbaru!
    echo [!] PERHATIAN: Bot perlu dijalankan ulang untuk menerapkan perubahan.
    echo [>] Silakan tutup jendela ini dan buka kembali "start-bot.bat".
    echo ===================================================
    pause
    exit /b
) else (
    echo [V] Bot sudah menggunakan versi terbaru (Up-to-date).
)

:start_bot
echo.
echo [>] Memulai aplikasi pada http://localhost:31912 ...
echo.

:: Jalankan core bot utama
node index.js

echo.
echo [!] Bot telah berhenti berjalan secara aman.
pause
