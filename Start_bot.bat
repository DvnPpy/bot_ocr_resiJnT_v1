@echo off
setlocal EnableDelayedExpansion
title Bot Resi J&T Offline - Port 31912
cd /d "%~dp0"
color 0A

echo.
echo  =====================================================
echo   BOT RESI J^&T OFFLINE - RUNNER v3.0
echo  =====================================================
echo.

:: ── CEK node_modules ──────────────────────────────────
if not exist "node_modules\" (
    color 0C
    echo  [X] Folder node_modules tidak ditemukan!
    echo  [>] Jalankan "Setup_bot_atau_Install.bat" dulu.
    pause & exit /b
)

:: ── CEK dotenv tersedia (modul kritis) ────────────────
if not exist "node_modules\dotenv\" (
    color 0E
    echo  [!] Modul "dotenv" tidak ditemukan.
    echo  [>] Menginstal modul yang kurang...
    call npm install dotenv
    echo.
)

:: ── AUTO-UPDATE DARI GITHUB ────────────────────────────
echo  [>] Memeriksa pembaruan di GitHub...
git fetch origin main >nul 2>&1

if %errorlevel% neq 0 (
    echo  [!] Tidak bisa terhubung ke GitHub. Pakai versi lokal.
    goto :start_bot
)

for /f "tokens=*" %%g in ('git rev-list HEAD...origin/main --count 2^>nul') do set UPDATE_COUNT=%%g

if "!UPDATE_COUNT!"=="" set UPDATE_COUNT=0

if !UPDATE_COUNT! gtr 0 (
    color 0E
    echo.
    echo  [UPDATE] Ditemukan !UPDATE_COUNT! pembaruan baru!
    echo  [>] Mengunduh pembaruan...
    git reset --hard origin/main >nul 2>&1
    color 0A
    echo  [V] Bot diperbarui ke versi terbaru!
) else (
    echo  [V] Bot sudah versi terbaru.
)

:start_bot
echo.
echo  [>] Membuka dashboard di browser...
timeout /t 2 /nobreak >nul
start http://localhost:31912

echo  [>] Menjalankan bot di http://localhost:31912
echo  [i] Tekan CTRL+C untuk menghentikan bot.
echo  [i] Log error tersimpan di "error_log.txt"
echo.
echo  ─────────────────────────────────────────────────────

node index.js 2>> error_log.txt

echo.
echo  ─────────────────────────────────────────────────────
echo  [!] Bot berhenti. Cek "error_log.txt" jika ada crash.
pause
