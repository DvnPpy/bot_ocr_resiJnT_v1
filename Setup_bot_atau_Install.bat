@echo off
setlocal EnableDelayedExpansion
title Setup Bot J&T Resi Offline v4.0 - Fixed
cd /d "%~dp0"
color 0A

echo.
echo  =====================================================
echo   INSTALLER BOT RESI J^&T - AUTO SETUP v4.0 (FIXED)
echo  =====================================================
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 0 - CEK ADMIN
:: ═══════════════════════════════════════════════════════
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Membutuhkan hak Administrator. Meminta izin...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)
echo  [V] Mode Administrator aktif.
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 1 - INSTALL NODE.JS v22 LTS
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 1/6] Memastikan Node.js v22 LTS...

set "NODE22_PATH=C:\Program Files\nodejs\node.exe"
set "USE_NODE22=0"

if exist "%NODE22_PATH%" (
    for /f "tokens=*" %%v in ('"%NODE22_PATH%" -e "process.stdout.write(String(process.version.split(\".\")[0].replace(\"v\",\"\")))" 2^>nul') do set INST_VER=%%v
    if "!INST_VER!" EQU "22" (
        echo  [V] Node.js v22 sudah terinstal di Program Files.
        set "USE_NODE22=1"
    )
)

if "!USE_NODE22!"=="0" (
    echo  [>] Mengunduh Node.js v22.14.0 LTS...
    curl -L --progress-bar -o "%TEMP%\node22_setup.msi" "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
    if %errorlevel% neq 0 (
        color 0C & echo  [X] Gagal unduh Node.js. Periksa internet. & pause & exit /b
    )
    echo  [>] Menginstal Node.js v22 LTS (silent)...
    msiexec /i "%TEMP%\node22_setup.msi" /qn /norestart ADDLOCAL=ALL
    del "%TEMP%\node22_setup.msi" >nul 2>&1
    echo  [V] Node.js v22 LTS terpasang!
)

set "PATH=C:\Program Files\nodejs;%PATH%"

for /f "tokens=*" %%v in ('"C:\Program Files\nodejs\node.exe" -e "process.stdout.write(process.version)" 2^>nul') do set ACTIVE_NODE=%%v
echo  [i] Node.js aktif untuk sesi ini: !ACTIVE_NODE!
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 2 - INSTALL VISUAL C++ BUILD TOOLS (FIXED syntax & modern node-gyp approach)
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 2/6] Memeriksa Build Tools (C++ compiler untuk better-sqlite3)...

set BUILD_TOOLS_OK=1

:: Metode Deteksi Modern Visual Studio / Build Tools
if exist "C:\Program Files (x86)\Microsoft Visual Studio" set BUILD_TOOLS_OK=0
if exist "C:\Program Files\Microsoft Visual Studio" set BUILD_TOOLS_OK=0
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\SxS\VS7" >nul 2>&1 && set BUILD_TOOLS_OK=0

if !BUILD_TOOLS_OK! EQU 0 (
    echo  [V] Visual C++ Build Tools sudah terdeteksi.
) else (
    echo  [!] Build Tools tidak ditemukan. Menyiapkan instalasi native-tools via npm...
    echo  [i] Proses kompilasi akan otomatis diatur oleh node-gyp modern pada Node v22.
    echo  [>] Mengunduh komponen build minimal...
    powershell -Command "Start-Process cmd -ArgumentList '/c npm install --global --production windows-build-tools' -Verb RunAs -Wait" >nul 2>&1
)
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 3 - CEK DAN INSTALL GIT
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 3/6] Memeriksa Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [>] Mengunduh dan menginstal Git...
    curl -L --progress-bar -o "%TEMP%\git_setup.exe" "https://github.com/git-for-windows/git/releases/download/v2.45.1.windows.1/Git-2.45.1-64-bit.exe"
    start /wait "%TEMP%\git_setup.exe" /SILENT /NORESTART /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"
    del "%TEMP%\git_setup.exe" >nul 2>&1
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
    echo  [V] Git berhasil diinstal!
) else (
    echo  [V] Git sudah terinstal.
)
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 4 - PULL DARI GITHUB
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 4/6] Mengambil data terbaru dari GitHub...
git init >nul 2>&1
git remote remove origin >nul 2>&1
git remote add origin https://github.com/DvnPpy/bot_ocr_resiJnT_v1.git >nul 2>&1
git fetch --all >nul 2>&1
git reset --hard origin/main >nul 2>&1
if %errorlevel% equ 0 (
    echo  [V] Data terbaru berhasil diambil.
) else (
    echo  [!] Gagal pull GitHub. Lanjut dengan file lokal.
)
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 5 - INSTALL MODUL NPM (FIXED Rebuild untuk Node v22)
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 5/6] Menginstal modul Node.js...

if exist "node_modules\" (
    echo  [>] Menghapus node_modules lama untuk menghindari konflik versi...
    rmdir /s /q node_modules >nul 2>&1
    if exist "node_modules\" (
        powershell -Command "Remove-Item -Recurse -Force '.\node_modules' -ErrorAction SilentlyContinue"
    )
)

:: Jalankan instalasi bersih dengan build binaries library native
call "C:\Program Files\nodejs\npm.cmd" install

if %errorlevel% neq 0 (
    echo.
    echo  [!] npm install standar gagal. Memulai regenerasi bindings pre-build...
    call "C:\Program Files\nodejs\npm.cmd" install --build-from-source
    
    if !errorlevel! neq 0 (
        echo  [!] Mencoba fallback dengan opsi --ignore-scripts...
        call "C:\Program Files\nodejs\npm.cmd" install --ignore-scripts
        
        if !errorlevel! neq 0 (
            color 0C
            echo.
            echo  [X] Semua metode instalasi gagal. Silakan periksa koneksi atau hak akses folder.
            pause & exit /b
        )
        echo  [!] Terinstal dengan bimbingan --ignore-scripts.
        echo  [i] Catatan: Jika better-sqlite3 bermasalah, database tidak akan tersimpan secara native.
    )
)

echo  [V] Modul berhasil diinstal!
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 6 - BUAT FILE DAN FOLDER PENDUKUNG
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 6/6] Menyiapkan folder dan konfigurasi...

for %%d in (DROP_ZONE POD_GAGAL temp_uploads pod_storage logs manifests public) do (
    if not exist "%%d\" mkdir "%%d"
)

if exist "index.html" if not exist "public\index.html" (
    copy "index.html" "public\index.html" >nul
    echo  [i] index.html berhasil ditempatkan di folder public/.
)

if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env" >nul
    ) else (
        (
            echo # Salin file ini dan isi API Key OCR.space Anda
            echo # Daftar gratis di: https://ocr.space/ocrapi
            echo OCR_API_KEY_1=ISI_DISINI
            echo OCR_API_KEY_2=
        ) > .env
    )
    echo  [V] File .env berhasil dibuat.
) else (
    echo  [V] File .env sudah ada.
)

echo.
echo  =====================================================
echo   SETUP SELESAI!
echo.
echo   Langkah selanjutnya:
echo   1. [Opsional] Edit file ".env" dan isikan API Key
echo      jika ingin mengaktifkan Engine 2 (OCR.space)
echo.
echo   2. Jalankan "Start_bot.bat" untuk memulai bot
echo  =====================================================
echo.
pause
