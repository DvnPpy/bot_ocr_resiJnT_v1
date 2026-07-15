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
            echo [MULAI] Paralel -> Mengompresi: "%%F"
            start /b "" cmd /c "magick -limit thread 1 "%%F" -strip -define jpeg:extent=400kb "%%F" >nul 2>&1 && echo [SELESAI] Sukses Kompres: "%%F""
        )
    ) else (
        call :WaitQueue
        echo [MULAI] Paralel -> Konversi ^& Kompresi: "%%F"
        start /b "" cmd /c "magick -limit thread 1 "%%F" -strip -define jpeg:extent=400kb "%%~nF.jpg" >nul 2>&1 && echo [SELESAI] Sukses Ubah: "%%~nF.jpg" && del "%%F" >nul 2>&1"
    )
)

:: Jeda sebelum scan folder lagi menggunakan cara ping yang 100% aman dari error "unexpected"
ping 127.0.0.1 -n %CHECK_INTERVAL% -w 1000 >nul 2>&1
goto MainLoop

:: ==========================================
:: FUNGSI PEMBATAS ANTREAN (MAX 10 PROSES)
:: ==========================================
:WaitQueue
for /f %%C in ('tasklist ^| find /c /i "magick.exe" 2^>nul') do set RUNNING=%%C
if !RUNNING! GEQ %MAX_PROCESSES% (
    echo [BATAS] Slot penuh (%RUNNING%/%MAX_PROCESSES%). Menunggu salah satu selesai...
    :WaitLoop
    ping 127.0.0.1 -n 2 -w 1000 >nul 2>&1
    for /f %%C in ('tasklist ^| find /c /i "magick.exe" 2^>nul') do set RUNNING=%%C
    if !RUNNING! GEQ %MAX_PROCESSES% goto :WaitLoop
    echo [SLOT TERSEDIA] Melanjutkan antrean berikutnya...
)
exit /b
