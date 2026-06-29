@echo off
setlocal EnableDelayedExpansion
title Setup Bot J&T Resi Offline v4.0
cd /d "%~dp0"
color 0A

echo.
echo  =====================================================
echo   INSTALLER BOT RESI J^&T - AUTO SETUP v4.0
echo  =====================================================
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 0 - CEK ADMIN, MINTA JIKA BELUM
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
:: TAHAP 1 - INSTALL NODE.JS v22 LTS (PAKSA PAKAI WINGET/MSI)
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 1/6] Memastikan Node.js v22 LTS...

:: Cek apakah node v22 sudah ada di lokasi default
set "NODE22_PATH=C:\Program Files\nodejs\node.exe"
set "USE_NODE22=0"

if exist "%NODE22_PATH%" (
    for /f "tokens=*" %%v in ('"%NODE22_PATH%" -e "process.stdout.write(String(process.version.split(\".\")[0].replace(\"v\",\"\")))" 2^>nul') do set INST_VER=%%v
    if !INST_VER! EQU 22 (
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
    echo  [>] Menginstal Node.js v22 LTS ^(silent^)...
    msiexec /i "%TEMP%\node22_setup.msi" /qn /norestart ADDLOCAL=ALL
    del "%TEMP%\node22_setup.msi" >nul 2>&1
    echo  [V] Node.js v22 LTS terpasang!
)

:: PAKSA gunakan Node v22 dari Program Files untuk sesi ini
set "PATH=C:\Program Files\nodejs;%PATH%"

:: Verifikasi
for /f "tokens=*" %%v in ('"C:\Program Files\nodejs\node.exe" -e "process.stdout.write(process.version)" 2^>nul') do set ACTIVE_NODE=%%v
echo  [i] Node.js aktif untuk sesi ini: !ACTIVE_NODE!
echo.

:: ═══════════════════════════════════════════════════════
:: TAHAP 2 - INSTALL VISUAL C++ BUILD TOOLS (untuk better-sqlite3)
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 2/6] Memeriksa Build Tools (C++ compiler)...

:: Cek apakah cl.exe sudah ada (tanda Build Tools sudah terinstal)
where cl.exe >nul 2>&1
set BUILD_TOOLS_OK=%errorlevel%

:: Cek via registry juga
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0" >nul 2>&1
if %errorlevel% equ 0 set BUILD_TOOLS_OK=0
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0" >nul 2>&1
if %errorlevel% equ 0 set BUILD_TOOLS_OK=0

:: Cek folder MSVC
if exist "C:\Program Files (x86)\Microsoft Visual Studio" set BUILD_TOOLS_OK=0
if exist "C:\Program Files\Microsoft Visual Studio" set BUILD_TOOLS_OK=0

if !BUILD_TOOLS_OK! equ 0 (
    echo  [V] Visual C++ Build Tools sudah terdeteksi.
) else (
    echo  [!] Build Tools tidak ditemukan. Menginstal via npm...
    echo  [i] Proses ini bisa memakan waktu 5-15 menit, mohon tunggu...
    "C:\Program Files\nodejs\npm.cmd" install --global windows-build-tools --vs2019 2>nul
    if !errorlevel! neq 0 (
        "C:\Program Files\nodejs\npm.cmd" install --global @windows/build-tools 2>nul
    )
    echo  [V] Build Tools selesai diproses.
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
:: TAHAP 5 - INSTALL MODUL NPM
:: ═══════════════════════════════════════════════════════
echo  [TAHAP 5/6] Menginstal modul Node.js...

:: Hapus node_modules lama agar bersih
if exist "node_modules\" (
    echo  [>] Menghapus node_modules lama...
    rmdir /s /q node_modules >nul 2>&1
    :: Jika rmdir gagal (EPERM), coba via PowerShell
    if exist "node_modules\" (
        powershell -Command "Remove-Item -Recurse -Force '.\node_modules' -ErrorAction SilentlyContinue"
    )
)

:: Set npm untuk pakai node v22
set "npm_config_python="
"C:\Program Files\nodejs\npm.cmd" install

if %errorlevel% neq 0 (
    echo.
    echo  [!] npm install biasa gagal. Mencoba fallback dengan --ignore-scripts...
    "C:\Program Files\nodejs\npm.cmd" install --ignore-scripts
    
    if !errorlevel! neq 0 (
        color 0C
        echo.
        echo  [X] Semua metode instalasi gagal.
        echo  [>] Hubungi developer dengan menyertakan log di atas.
        pause & exit /b
    )
    
    echo.
    echo  [!] Terinstal dengan --ignore-scripts.
    echo  [i] better-sqlite3 mungkin tidak berfungsi.
    echo  [>] Bot akan berjalan TANPA fitur database native.
    echo  [>] Lanjutkan dengan mode terbatas...
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
    echo  [i] index.html dipindahkan ke public/.
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
echo   1. [Opsional] Edit file ".env" isi API Key
echo      jika ingin pakai Engine 2 ^(OCR.space^)
echo.
echo   2. Jalankan "Start_bot.bat" untuk mulai bot
echo  =====================================================
echo.
pause
