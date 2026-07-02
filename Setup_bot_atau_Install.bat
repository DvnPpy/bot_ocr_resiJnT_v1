@echo off
title Super Installer Bot J^&T Offline - Auto Fix C++
cd /d "%~dp0"
color 0A

echo ===================================================
echo   SISTEM SUPER INSTALLER ^& AUTO-FIX MODUL NPM
echo ===================================================
echo.

:: 1. Memeriksa Hak Akses Administrator secara Otomatis
echo [PROSES] Memeriksa Hak Akses Administrator...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Akses Administrator belum diberikan.
    echo [^>] Meminta izin secara otomatis...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)
echo [V] Hak akses Administrator disahkan.
echo.

:: 2. TAHAP 1: Pasang Git (Untuk menarik file dari GitHub)
echo [TAHAP 1] Memeriksa mesin Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Git tidak ditemukan.
    echo [^>] Mengunduh dan menginstal Git secara senyap...
    curl -L -o git_setup.exe https://github.com/git-for-windows/git/releases/download/v2.45.1.windows.1/Git-2.45.1-64-bit.exe
    start /wait git_setup.exe /SILENT /NORESTART
    del git_setup.exe
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
    echo [V] Git berhasil disiapkan!
) else (
    echo [V] Mesin Git sudah tersedia.
)
echo.

:: 3. TAHAP 2: Pasang Node.js
echo [TAHAP 2] Memeriksa mesin Node.js...
node -v >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Node.js tidak ditemukan.
    echo [^>] Mengunduh dan menginstal Node.js LTS v20...
    curl -L -o node_setup.msi https://nodejs.org/dist/v20.15.1/node-v20.15.1-x64.msi
    start /wait msiexec /i node_setup.msi /qn /norestart
    del node_setup.msi
    set "PATH=%PATH%;C:\Program Files\nodejs\"
    echo [V] Node.js berhasil disiapkan!
) else (
    echo [V] Node.js sudah tersedia.
)
echo.

:: Refresh jalur terminal
set "PATH=%PATH%;C:\Program Files\Git\cmd;C:\Program Files\nodejs\"

:: 4. TAHAP 3: Tarik File dari GitHub
echo [TAHAP 3] Menarik pembaruan data bot dari GitHub...
git init >nul 2>&1
git remote remove origin >nul 2>&1
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1
git fetch --all >nul 2>&1
git reset --hard origin/main >nul 2>&1
echo [V] Data bot berhasil disinkronisasi!
echo.

:: 5. TAHAP 4: Instalasi Modul NPM & Deteksi Kerusakan
echo [TAHAP 4] Menginstal Modul NPM (Sharp, SQLite, dll)...
call npm install
call npm install better-sqlite3 chokidar

:: Jika instalasi lancar (error level 0), langsung lompat ke bagian SUKSES
if %errorlevel% equ 0 (
    echo [V] Semua modul berhasil diinstal dengan lancar!
    goto :sukses
)

:: =========================================================
:: MODE PEMULIHAN (Jika instalasi gagal karena kurang mesin C++)
:: =========================================================
color 0E
echo.
echo [!] PERINGATAN: Instalasi modul Native (Sharp/SQLite3) gagal!
echo [^>] Memasuki Mode Pemulihan... Komputer ini sepertinya kekurangan C++ Compiler ^& Python.
echo [^>] Sistem akan mengunduh dan menginstal alat tersebut secara otomatis.
echo [!] MOHON BERSABAR. PROSES INI BUTUH WAKTU LAMA DAN INTERNET BESAR (1-2 GB)...
echo.

echo [1/3] Mengunduh dan menginstal Python (Menyusun mesin Node-Gyp)...
curl -L -o python_setup.exe https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
start /wait python_setup.exe /quiet InstallAllUsers=1 PrependPath=1
del python_setup.exe
echo [V] Python berhasil ditambahkan ke sistem.
echo.

echo [2/3] Mengunduh dan menginstal Visual Studio C++ Build Tools (Ini paling lama)...
curl -L -o vs_buildtools.exe https://aka.ms/vs/17/release/vs_buildtools.exe
start /wait vs_buildtools.exe --quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended
del vs_buildtools.exe
echo [V] C++ Build Tools berhasil disuntikkan ke sistem.
echo.

echo [3/3] Mencoba ulang instalasi modul NPM...
call npm config set msvs_version 2022
call npm install
call npm install better-sqlite3 chokidar

if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [X] FATAL ERROR: Instalasi tetap gagal.
    echo Kemungkinan PC membutuhkan restart, atau ruang hard disk penuh.
    pause
    exit /b
)

:sukses
color 0A
echo.
echo ===================================================
echo [SUKSES] Seluruh sistem dan mesin bot J^&T siap!
echo Silakan tutup jendela ini dan jalankan "Start bot.bat"
echo ===================================================
pause
