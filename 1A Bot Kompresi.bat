@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: CONFIGURATION
:: ==========================================
set "MAX_SIZE=409600"
set "MAX_PROCESSES=10"
set "CHECK_INTERVAL=5"

echo ==================================================
echo    Bot Kompresi Otomatis ^& Real-Time (Max 10)
echo ==================================================
echo [INFO] Bot aktif. Memantau folder setiap %CHECK_INTERVAL% detik...
echo [INFO] Tekan Ctrl+C untuk menghentikan bot.
echo ==================================================
echo.

:: 1. CEK INSTALASI IMAGEMAGICK
where magick >nul 2>nul
if %errorlevel% neq 0 (
    echo [PROSES] Mengunduh dan menginstal ImageMagick...
    winget install ImageMagick.ImageMagick --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% neq 0 (
        echo [GAGAL] Gagal menginstal otomatis. Cek koneksi internet.
        pause & exit /b
    )
    echo [SUKSES] ImageMagick berhasil diinstal. Silakan jalankan ulang script ini.
    pause & exit
)

:: 2. LOOPING UTAMA (REAL-TIME SCAN)
:MainLoop
set "found_files=0"

for %%F in (*.jpg *.jpeg *.png *.heic *.webp *.bmp) do (
    set "is_exact_jpg=0"
    if /I "%%~xF"==".jpg" set "is_exact_jpg=1"
    
    if "!is_exact_jpg!"=="1" (
        :: Kasus 1: File JPG asli yang ukurannya di atas 400KB
        if %%~zF GTR %MAX_SIZE% (
            set /a found_files+=1
            call :WaitQueue
            call :ProcessFile "%%F" "jpg"
        )
    ) else (
        :: Kasus 2: Format lain yang perlu dikonversi ke JPG
        set /a found_files+=1
        call :WaitQueue
        call :ProcessFile "%%F" "convert"
    )
)

:: Jika tidak ada file yang diproses, tampilkan indikator standby statis/senyap
timeout /t %CHECK_INTERVAL% >nul
goto MainLoop

:: ==========================================
:: FUNGSI PROSES DENGAN ANIMASI PROGRES VISUAL
:: ==========================================
:ProcessFile
set "file=%~1"
set "mode=%~2"

if "%mode%"=="jpg" (
    echo [ANTREAN] Mengompresi: "%file%"
    :: Menjalankan proses latar belakang
    start /b "" magick -limit thread 1 "%file%" -strip -define jpeg:extent=400kb "%file%" >nul 2>&1
) else (
    echo [ANTREAN] Konversi ^& Kompresi: "%file%"
    start /b "" magick -limit thread 1 "%file%" -strip -define jpeg:extent=400kb "%~n1.jpg" >nul 2>&1
    :: Loop pembersihan lokal untuk file non-jpg segera setelah konversi selesai
    start /b "" cmd /c "timeout /t 2 >nul && if exist "%~n1.jpg" del "%file%""
)

:: Animasi Loading / Progres Visual per foto (Berjalan ~1.5 detik untuk estetika transisi)
set /p ="[PROGRES] Processing " <nul
for /L %%i in (1,1,15) do (
    set /p ="." <nul
    timeout /t 1 >nul 2>&1
)
echo  [SELESAI OPERASI]
echo --------------------------------------------------
exit /b

:: ==========================================
:: FUNGSI PEMBATAS ANTREAN (MAX 10 PROSES)
:: ==========================================
:WaitQueue
for /f %%C in ('tasklist ^| find /c /i "magick.exe" 2^>nul') do set RUNNING=%%C
if !RUNNING! GEQ %MAX_PROCESSES% (
    set /p ="[FULL] Antrean penuh (%RUNNING%/10), menunggu slot kosong..." <nul
    :WaitLoop
    timeout /t 1 >nul
    for /f %%C in ('tasklist ^| find /c /i "magick.exe" 2^>nul') do set RUNNING=%%C
    if !RUNNING! GEQ %MAX_PROCESSES% goto :WaitLoop
    echo  [SLOT TERSEDIA]
)
exit /b
