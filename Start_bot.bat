@echo off
setlocal EnableDelayedExpansion
title Bot Resi J&T Offline - Port 31912
cd /d "%~dp0"
color 0A

echo.
echo  =====================================================
echo   BOT RESI J^&T OFFLINE - RUNNER v4.0
echo  =====================================================
echo.

:: Paksa pakai Node v22 jika ada
if exist "C:\Program Files\nodejs\node.exe" (
    set "PATH=C:\Program Files\nodejs;%PATH%"
)

:: Verifikasi node tersedia
node -v >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo  [X] Node.js tidak ditemukan!
    echo  [>] Jalankan Setup_bot_atau_Install.bat terlebih dahulu.
    pause & exit /b
)

for /f "tokens=*" %%v in ('node -e "process.stdout.write(process.version)"') do set NODEVER=%%v
echo  [i] Menggunakan Node.js !NODEVER!

:: ── CEK node_modules ──────────────────────────────────
if not exist "node_modules\" (
    color 0C
    echo  [X] Folder node_modules tidak ditemukan!
    echo  [>] Jalankan Setup_bot_atau_Install.bat terlebih dahulu.
    pause & exit /b
)

:: ── CEK MODUL KRITIS, INSTALL JIKA KURANG ─────────────
set MISSING=0
for %%m in (dotenv express socket.io multer sharp exceljs) do (
    if not exist "node_modules\%%m\" (
        echo  [!] Modul "%%m" tidak ditemukan.
        set MISSING=1
    )
)
if !MISSING! equ 1 (
    echo  [>] Menginstal modul yang kurang...
    npm install
    echo.
)

:: ── AUTO-UPDATE DARI GITHUB ────────────────────────────
echo  [>] Memeriksa pembaruan di GitHub...
git fetch origin main >nul 2>&1

if %errorlevel% equ 0 (
    for /f "tokens=*" %%g in ('git rev-list HEAD...origin/main --count 2^>nul') do set UPD=%%g
    if "!UPD!"=="" set UPD=0
    if !UPD! gtr 0 (
        color 0E
        echo  [UPDATE] !UPD! pembaruan baru ditemukan! Mengunduh...
        git reset --hard origin/main >nul 2>&1
        color 0A
        echo  [V] Bot diperbarui ke versi terbaru!
    ) else (
        echo  [V] Bot sudah versi terbaru.
    )
) else (
    echo  [!] Tidak bisa cek GitHub. Pakai versi lokal.
)

:: ── JALANKAN BOT ──────────────────────────────────────
echo.
echo  [>] Membuka dashboard di browser...
timeout /t 2 /nobreak >nul
start http://localhost:31912

echo  [>] Bot berjalan di http://localhost:31912
echo  [i] Tekan CTRL+C untuk menghentikan.
echo  [i] Log error disimpan di error_log.txt
echo.
echo  ─────────────────────────────────────────────────
node index.js 2>> error_log.txt

echo.
echo  ─────────────────────────────────────────────────
echo  [!] Bot berhenti. Cek error_log.txt jika ada crash.
pause
