@echo off
title Setup Bot J^&T Offline 
cd /d "%~dp0"
color 0A

echo ===================================================
echo    SISTEM AUTO-SETUP BOT RESI J^&T OFFLINE 
echo ===================================================
echo.

:: ── CEK VERSI NODE.JS ──────────────────────────────────────────────────────────
echo [CEK] Memeriksa versi Node.js...
for /f "tokens=1 delims=v." %%a in ('node -v 2^>nul') do set NODE_MAJOR=%%a
for /f "tokens=2 delims=v." %%a in ('node -v 2^>nul') do set NODE_MAJOR=%%a

node -v >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo [X] Node.js tidak ditemukan! Silakan install dari https://nodejs.org ^(pilih LTS^)
    pause
    exit /b
)

:: Ambil major version Node.js
for /f "tokens=*" %%v in ('node -e "process.stdout.write(String(process.version.split('.')[0].replace('v','')))"') do set NODE_VER=%%v

echo [i] Versi Node.js terdeteksi: v%NODE_VER%

if %NODE_VER% GEQ 23 (
    color 0E
    echo.
    echo ===================================================
    echo [!] PERINGATAN: Node.js v%NODE_VER% terlalu baru!
    echo.
    echo     better-sqlite3 belum punya prebuilt binary
    echo     untuk Node.js v23 ke atas, sehingga akan
    echo     gagal saat build jika Python tidak terinstal.
    echo.
    echo [>] REKOMENDASI: Downgrade ke Node.js LTS (v22)
    echo     Download di: https://nodejs.org
    echo     Pilih tombol "LTS", bukan "Current".
    echo.
    echo [?] Lanjut install dengan versi Node saat ini?
    echo     (Mungkin gagal jika tidak ada Python/Build Tools)
    echo ===================================================
    echo.
    choice /C YN /M "Lanjut install (Y) atau Keluar untuk downgrade Node dulu (N)?"
    if errorlevel 2 (
        echo [i] Silakan install Node.js LTS dari https://nodejs.org lalu jalankan ulang setup ini.
        pause
        exit /b
    )
    echo.
    echo [>] Mencoba install dengan --ignore-scripts sebagai fallback...
    set INSTALL_FLAGS=--ignore-scripts
) else (
    echo [V] Versi Node.js aman untuk build native module.
    set INSTALL_FLAGS=
)

:: ── TAHAP GIT ──────────────────────────────────────────────────────────────────
echo.
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

echo [>] Mengonfigurasi Git Remote ke repositori baru...
git init >nul 2>&1
git remote remove origin >nul 2>&1
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1

echo [>] Menarik paksa (Force Pull) data terbaru dari GitHub...
git fetch --all >nul 2>&1
git reset --hard origin/main >nul 2>&1
echo [V] Berhasil menarik data repository terbaru!

:: ── TAHAP NPM ──────────────────────────────────────────────────────────────────
echo.
echo [TAHAP 2] Menginstal Modul Aplikasi Offline...
call npm install %INSTALL_FLAGS%

if %errorlevel% neq 0 (
    color 0C
    echo.
    echo ===================================================
    echo [X] INSTALASI GAGAL!
    echo.
    echo Kemungkinan penyebab:
    echo  1. Node.js terlalu baru (v%NODE_VER%) - Downgrade ke v22 LTS
    echo     https://nodejs.org
    echo.
    echo  2. Belum ada Build Tools Windows
    echo     Jalankan CMD sebagai Administrator lalu ketik:
    echo     npm install --global ^@windows/build-tools
    echo     Setelah selesai, jalankan setup ini lagi.
    echo.
    echo  3. Tidak ada koneksi internet
    echo ===================================================
    pause
    exit /b
)
echo [V] Semua mesin dan modul terpasang sempurna!

:: ── TAHAP .ENV ─────────────────────────────────────────────────────────────────
echo.
echo [TAHAP 3] Konfigurasi API Key untuk Engine 2 (OCR.space)...
if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env" >nul
        echo.
        echo ===================================================
        echo [!] FILE .env BERHASIL DIBUAT dari template.
        echo.
        echo [OPSIONAL] Buka file ".env" dengan Notepad, isi
        echo            OCR_API_KEY_1 dan OCR_API_KEY_2 dengan
        echo            API Key dari https://ocr.space/ocrapi
        echo.
        echo            (Jika hanya pakai Engine 1/Tesseract,
        echo             langkah ini bisa dilewati)
        echo ===================================================
    ) else (
        echo [!] File .env.example tidak ditemukan, lewati.
    )
) else (
    echo [V] File .env sudah ada, konfigurasi dilewati.
)

echo.
echo ===================================================
echo Setup Selesai! Silakan gunakan "Start_bot.bat"
echo ===================================================
pause
