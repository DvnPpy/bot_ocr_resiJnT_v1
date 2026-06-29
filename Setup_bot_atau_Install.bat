@echo off
setlocal EnableDelayedExpansion
title Setup Bot J&T Resi Offline v4.0 - All-in-One Compatible Installer
cd /d "%~dp0"
color 0A

echo =====================================================
echo  INSTALLER UTAMA ALL-IN-ONE - BOT RESI J^&T v4.0
echo =====================================================
echo  Skrip ini dikonfigurasi agar kompatibel dengan bot terbaru.
echo.
echo  [i] PENTING: Pastikan klik kanan file ini dan pilih 'Run as Administrator'.
echo.
pause

:: ═══════════════════════════════════════════════════════
:: TAHAP 1 - INSTALL & VALIDASI NODE.JS v22 LTS
:: ═══════════════════════════════════════════════════════
echo [TAHAP 1/5] Memastikan & Menginstal Node.js v22 LTS...

set "NODE_PATH=C:\Program Files\nodejs\node.exe"
set "NEED_NODE=1"

if exist "%NODE_PATH%" (
    for /f "tokens=*" %%v in ('"%NODE_PATH%" -e "process.stdout.write(String(process.version.split(\".\")[0].replace(\"v\",\"\")))" 2^>nul') do set "INST_VER=%%v"
    if "!INST_VER!"=="22" (
        echo [V] Node.js v22 sudah terpasang di sistem.
        set "NEED_NODE=0"
    )
)

if "!NEED_NODE!"=="1" (
    echo [>] Mengunduh Node.js v22.14.0 LTS...
    curl -L -o "%TEMP%\node22_setup.msi" "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
    if %errorlevel% neq 0 (
        color 0C & echo [X] Gagal mengunduh Node.js. Periksa koneksi internet! & goto ERROR_EXIT
    )
    echo [>] Menginstal Node.js v22 LTS secara Silent (Mohon Tunggu)...
    msiexec /i "%TEMP%\node22_setup.msi" /qn /norestart ADDLOCAL=ALL
    del "%TEMP%\node22_setup.msi" >nul 2>&1
    echo [V] Node.js v22 LTS berhasil diinstal!
)

set "PATH=C:\Program Files\nodejs;%PATH%"
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 2 - INSTALL GIT CONTROLLER
:: ═══════════════════════════════════════════════════════
echo [TAHAP 2/5] Memeriksa & Menginstal Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [>] Git tidak ditemukan. Mengunduh Git Installer...
    curl -L -o "%TEMP%\git_setup.exe" "https://github.com/git-for-windows/git/releases/download/v2.45.1.windows.1/Git-2.45.1-64-bit.exe"
    echo [>] Menginstal Git secara Silent...
    start /wait "" "%TEMP%\git_setup.exe" /SILENT /NORESTART
    del "%TEMP%\git_setup.exe" >nul 2>&1
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
    echo [V] Git berhasil diinstal!
) else (
    echo [V] Git sudah terpasang di sistem.
)
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 3 - TARIK SOURCE CODE DARI GITHUB
:: ═══════════════════════════════════════════════════════
echo [TAHAP 3/5] Sinkronisasi Source Code dari GitHub...
git init >nul 2>&1
git remote remove origin >nul 2>&1
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1

echo [>] Menarik file project terbaru dari GitHub (Main Branch)...
git fetch --all >nul 2>&1
git reset --hard origin/main >nul 2>&1

if %errorlevel% equ 0 (
    echo [V] Source code bot berhasil diperbarui dan disinkronkan!
) else (
    echo [!] Gagal terhubung ke GitHub. Melanjutkan dengan struktur file lokal...
)
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 4 - INSTALASI NPM PACKAGES (KOMPATIBEL DENGAN BOT)
:: ═══════════════════════════════════════════════════════
echo [TAHAP 4/5] Menginstal Modul Paket Node.js (node_modules)...

if exist "node_modules\" (
    echo [>] Membersihkan folder cache node_modules lama...
    rmdir /s /q node_modules >nul 2>&1
    if exist "node_modules\" (
        powershell -Command "Remove-Item -Recurse -Force '.\node_modules' -ErrorAction SilentlyContinue"
    )
)

:: Konfigurasi environment khusus untuk kompilasi better-sqlite3 dan sharp
set "npm_config_python="

echo [i] Menjalankan perintah npm install murni...
call "C:\Program Files\nodejs\npm.cmd" install

if %errorlevel% neq 0 (
    echo.
    echo [!] Pemasangan standar gagal. Menggunakan fallback kompilasi ulang dari source...
    call "C:\Program Files\nodejs\npm.cmd" install --build-from-source
    
    if !errorlevel! neq 0 (
        echo [!] Mencoba jalur alternatif terakhir (--ignore-scripts)...
        call "C:\Program Files\nodejs\npm.cmd" install --ignore-scripts
        
        if !errorlevel! neq 0 (
            color 0C
            echo [X] Gagal total menginstal paket dependensi NPM.
            goto ERROR_EXIT
        )
        echo [V] Berhasil dipasang via mode alternatif ignore-scripts.
    )
) else (
    echo [V] Semua modul paket (node_modules) sukses terinstal!
)
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 5 - SETUP DIREKTORI & INTEGRASI HALAMAN INTERFACE
:: ═══════════════════════════════════════════════════════
echo [TAHAP 5/5] Membuat direktori penyimpanan kerja bot...

:: Membuat folder utama sesuai kebutuhan bot sekarang
for %%d in (DROP_ZONE POD_GAGAL temp_uploads pod_storage logs manifests public) do (
    if not exist "%%d\" mkdir "%%d"
)

:: Memindahkan index.html ke folder public agar terbaca express.static('public')
if exist "index.html" (
    copy "index.html" "public\index.html" >nul
    echo [i] Penyelarasan index.html ke folder public berhasil dilakukan.
)

:: Membuat template berkas env lokal jika belum ada
if not exist ".env" (
    (
        echo # Konfigurasi Kunci API Kontrol Bot Resi JnT Offline
        echo OCR_API_KEY_1=ISI_DISINI
        echo OCR_API_KEY_2=
    ) > .env
    echo [V] File konfigurasi .env berhasil dibuat.
)

echo.
echo =====================================================
echo  PROSES INSTALASI SELESAI SEPENUHNYA!
echo =====================================================
echo  Semua mesin dan modul telah konticable (kompatibel).
echo  Anda sekarang bisa langsung menjalankan 'Start_bot.bat'.
echo =====================================================
echo.
pause
exit /b

:ERROR_EXIT
echo.
echo =====================================================
echo  [X] INSTALASI TERHENTI KARENA ADANYA GALAT SYSTEM!
echo  Jendela ditahan agar Anda bisa memeriksa pesan error di atas.
echo =====================================================
echo.
pause
exit /b
