@echo off
title Setup Sederhana Bot J^&T (GitHub Pull)
cd /d "%~dp0"
color 0A

echo ===================================================
echo     INSTALLER SEDERHANA - TARIK DATA GITHUB
echo ===================================================
echo.

:: 1. HANYA MENDOWNLOAD APLIKASI PENARIK DATA GITHUB (GIT)
echo [TAHAP 1] Memeriksa mesin Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Git belum terinstal.
    echo [^>] Mendownload Git (aplikasi untuk menarik data GitHub)...
    curl -L -o git_setup.exe https://github.com/git-for-windows/git/releases/download/v2.45.1.windows.1/Git-2.45.1-64-bit.exe
    
    echo [^>] Menginstal Git secara senyap... 
    start /wait git_setup.exe /SILENT /NORESTART
    del git_setup.exe
    
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
    echo [V] Git siap digunakan!
) else (
    echo [V] Aplikasi Git sudah tersedia di komputermu.
)
echo.

:: 2. TARIK DATA DARI FOLDER GITHUB YANG SUDAH DISIAPKAN
echo [TAHAP 2] Menarik data bot dari folder GitHub-mu...
git init >nul 2>&1
git remote remove origin >nul 2>&1

:: Pastikan link ini adalah link repo yang sudah kamu siapkan
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1

echo [^>] Proses men-download data dari GitHub...
git fetch --all >nul 2>&1
git reset --hard origin/main >nul 2>&1
echo [V] Semua file berhasil ditarik!
echo.

:: 3. PASANG MODUL NPM
echo [TAHAP 3] Menginstal modul NPM...
call npm install
call npm install better-sqlite3 chokidar

echo.
echo ===================================================
echo [SUKSES] Folder berhasil ditarik dan disiapkan!
echo Silakan jalankan "Start bot.bat"
echo ===================================================
pause
