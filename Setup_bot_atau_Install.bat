@echo off
setlocal EnableDelayedExpansion
title Setup Bot J&T Resi Offline
cd /d "%~dp0"
color 0A

echo.
echo  =====================================================
echo   INSTALLER BOT RESI J^&T OFFLINE - AUTO SETUP v3.0
echo  =====================================================
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 0 — CEK HAK ADMIN
:: ═══════════════════════════════════════════════════════
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 0E
    echo  [!] Script ini butuh hak Administrator.
    echo  [>] Meminta ulang izin Admin secara otomatis...
    echo.
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
echo  [V] Berjalan sebagai Administrator. Lanjut...
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 1 — CEK DAN INSTALL NODE.JS LTS
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 1/5] Memeriksa Node.js...

node -v >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Node.js tidak ditemukan. Mengunduh Node.js v22 LTS...
    goto :install_node
)

for /f "tokens=*" %%v in ('node -e "process.stdout.write(String(process.version.split(\".\")[0].replace(\"v\",\"\")))"') do set NODE_VER=%%v

echo  [i] Node.js versi terdeteksi: v!NODE_VER!

if !NODE_VER! GEQ 23 (
    echo  [!] Node.js v!NODE_VER! terlalu baru ^(butuh v22 LTS^).
    echo  [>] Mengunduh dan menginstal Node.js v22 LTS...
    goto :install_node
)
if !NODE_VER! LSS 18 (
    echo  [!] Node.js v!NODE_VER! terlalu lama ^(butuh v18 ke atas^).
    echo  [>] Mengunduh dan menginstal Node.js v22 LTS...
    goto :install_node
)

echo  [V] Node.js v!NODE_VER! - Versi aman, lewati instalasi.
goto :node_done

:install_node
echo  [>] Mengunduh Node.js v22.14.0 LTS ^(mungkin beberapa menit^)...
curl -L -o node_setup.msi "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
if %errorlevel% neq 0 (
    color 0C
    echo  [X] Gagal mengunduh Node.js. Periksa koneksi internet.
    pause & exit /b
)
echo  [>] Menginstal Node.js v22 LTS secara silent...
msiexec /i node_setup.msi /qn /norestart ADDLOCAL=ALL
del node_setup.msi
:: Refresh PATH agar node langsung bisa dipakai
set "PATH=%PATH%;C:\Program Files\nodejs"
echo  [V] Node.js v22 LTS berhasil diinstal!

:node_done
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 2 — CEK DAN INSTALL GIT
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 2/5] Memeriksa Git...

git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Git tidak ditemukan. Mengunduh Git...
    curl -L -o git_setup.exe "https://github.com/git-for-windows/git/releases/download/v2.45.1.windows.1/Git-2.45.1-64-bit.exe"
    echo  [>] Menginstal Git...
    start /wait git_setup.exe /SILENT /NORESTART
    del git_setup.exe
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
    echo  [V] Git berhasil diinstal!
) else (
    echo  [V] Git sudah terinstal.
)
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 3 — PULL REPO DARI GITHUB
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 3/5] Mengambil data terbaru dari GitHub...

git init >nul 2>&1
git remote remove origin >nul 2>&1
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1
git fetch --all >nul 2>&1
git reset --hard origin/main >nul 2>&1

if %errorlevel% neq 0 (
    echo  [!] Gagal pull dari GitHub. Lanjut dengan file lokal yang ada.
) else (
    echo  [V] Data terbaru berhasil diambil dari GitHub.
)
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 4 — INSTALL MODUL NPM
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 4/5] Menginstal modul Node.js...

:: Bersihkan node_modules lama jika ada agar tidak konflik
if exist "node_modules\" (
    echo  [>] Menghapus node_modules lama...
    rmdir /s /q node_modules
)

:: Install semua modul
call npm install
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo  =====================================================
    echo  [X] npm install GAGAL!
    echo.
    echo  Coba jalankan perintah ini di CMD folder bot:
    echo    npm install --ignore-scripts
    echo.
    echo  Lalu jalankan Start_bot.bat untuk mencoba jalan.
    echo  =====================================================
    pause
    exit /b
)
echo  [V] Semua modul berhasil diinstal!
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 5 — BUAT FILE KONFIGURASI
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 5/5] Menyiapkan file konfigurasi...

:: Buat .env dari template jika belum ada
if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env" >nul
        echo  [V] File .env berhasil dibuat dari template.
    ) else (
        :: Buat .env langsung jika .env.example tidak ada
        echo # API Key OCR.space untuk Engine 2 > .env
        echo # Daftar gratis di https://ocr.space/ocrapi >> .env
        echo OCR_API_KEY_1=ISI_API_KEY_ANDA_DISINI >> .env
        echo OCR_API_KEY_2= >> .env
        echo  [V] File .env berhasil dibuat.
    )
) else (
    echo  [V] File .env sudah ada.
)

:: Buat folder-folder yang dibutuhkan bot
if not exist "DROP_ZONE\"    mkdir DROP_ZONE
if not exist "POD_GAGAL\"    mkdir POD_GAGAL
if not exist "temp_uploads\" mkdir temp_uploads
if not exist "pod_storage\"  mkdir pod_storage
if not exist "logs\"         mkdir logs
if not exist "manifests\"    mkdir manifests
if not exist "public\"       mkdir public

:: Pindahkan index.html ke public jika masih di root
if exist "index.html" (
    if not exist "public\index.html" (
        copy "index.html" "public\index.html" >nul
        echo  [i] index.html dipindahkan ke folder public^/.
    )
)

echo.
echo  =====================================================
echo  [SELESAI] SETUP BERHASIL SEMPURNA!
echo.
echo  Langkah selanjutnya:
echo   1. ^(Opsional^) Buka file ".env" dengan Notepad
echo      dan isi API Key jika ingin pakai Engine 2
echo      ^(OCR.space^). Engine 1 tidak butuh API Key.
echo.
echo   2. Jalankan "Start_bot.bat" untuk memulai bot.
echo  =====================================================
echo.
pause
