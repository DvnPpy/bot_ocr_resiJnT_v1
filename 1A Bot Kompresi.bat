@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: CONFIGURATION
:: ==========================================
set "MAX_SIZE=409600"
set "MAX_PROCESSES=10"
set "CHECK_INTERVAL=5"

echo ==================================================
echo    Bot Kompresi Paralel ^& Real-Time (Max 10)
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
for %%F in (*.jpg *.jpeg *.png *.heic *.webp *.bmp) do (
    set "is_exact_jpg=0"
    if /I "%%~xF"==".jpg" set "is_exact_jpg=1"
    
    if "!is_exact_jpg!"=="1" (
        if %%~zF GTR %MAX_SIZE% (
            call :WaitQueue
            call :LaunchProcess "%%F" "jpg"
        )
    ) else (
        call :WaitQueue
        call :LaunchProcess "%%F" "convert"
    )
)

:: Jeda sebelum scan folder lagi
timeout /t %CHECK_INTERVAL% >nul
goto MainLoop

:: ==========================================
:: FUNGSI MENJALANKAN PROSES (PARALEL AMAN)
:: ==========================================
:LaunchProcess
set "file=%~1"
set "mode=%~2"

if "%mode%"=="jpg" (
    echo [MULAI] Paralel -> Mengompresi: "%file%"
    :: Menjalankan proses latar belakang secara aman menggunakan call
    start /b "" cmd /c "magick -limit thread 1 "%file%" -strip -define jpeg:extent=400kb "%file%" >nul 2>&1 && echo [SELESAI] Sukses Kompres: "%file%""
) else (
    echo [MULAI] Paralel -> Konversi ^& Kompresi: "%file%"
    :: Menggunakan sintaks if exist pasca-proses untuk menghindari error rantai ampersand (&)
    start /b "" cmd /c "magick -limit thread 1 "%file%" -strip -define jpeg:extent=400kb "%~n1.jpg" >nul 2>&1 && echo [SELESAI] Sukses Ubah: "%~n1.jpg" && del "%file%" >nul 2>&1"
)
exit /b

:: ==========================================
:: FUNGSI PEMBATAS ANTREAN (MAX 10 PROSES)
:: ==========================================
:WaitQueue
for /f %%C in ('tasklist ^| find /c /i "magick.exe" 2^>nul') do set RUNNING=%%C
if !RUNNING! GEQ %MAX_PROCESSES% (
    echo [BATAS] Slot penuh (%RUNNING%/%MAX_PROCESSES%). Menunggu salah satu selesai...
    :WaitLoop
    timeout /t 1 >nul 2>&1
    for /f %%C in ('tasklist ^| find /c /i "magick.exe" 2^>nul') do set RUNNING=%%C
    if !RUNNING! GEQ %MAX_PROCESSES% goto :WaitLoop
    echo [SLOT TERSEDIA] Melanjutkan antrean berikutnya...
)
exit /b
