@echo off
setlocal enabledelayedexpansion

:: Konfigurasi
set MAX_SIZE=409600
set MAX_PROCESSES=25

echo ==================================================
echo    Program Kompresi ^& Konversi Paralel (10x)
echo ==================================================
echo.

:: 1. CEK DAN INSTALASI IMAGEMAGICK OTOMATIS
where magick >nul 2>nul
if %errorlevel% neq 0 (
    echo [INFO] ImageMagick belum terinstal di komputer ini.
    echo [PROSES] Mengunduh dan menginstal ImageMagick secara otomatis...
    echo [INFO] Harap tunggu, proses ini mungkin memakan waktu beberapa menit.
    
    winget install ImageMagick.ImageMagick --silent --accept-package-agreements --accept-source-agreements
    
    if %errorlevel% neq 0 (
        echo [GAGAL] Tidak dapat menginstal secara otomatis. Pastikan internet aktif.
        pause
        exit /b
    )
    
    echo [SUKSES] ImageMagick berhasil diinstal!
    echo ==========================================
    echo [PENTING] Karena aplikasi baru saja diinstal, CMD perlu di-refresh.
    echo Tekan tombol apa saja untuk menutup jendela ini.
    echo Setelah tertutup, silakan KLIK GANDA LAGI file .bat ini untuk mulai.
    pause
    exit
) else (
    echo [INFO] ImageMagick sudah terinstal. Sistem siap!
)

echo.
echo [INFO] Memasukkan file ke dalam sistem antrean...
echo ==================================================

:: 2. MEMASUKKAN PROSES KE ANTREAN LATAR BELAKANG
for %%F in (*.jpg *.jpeg *.png *.heic *.webp *.bmp) do (
    set "is_exact_jpg=0"
    if /I "%%~xF"==".jpg" set "is_exact_jpg=1"
    
    if "!is_exact_jpg!"=="1" (
        :: Proses untuk file .jpg asli
        if %%~zF GTR %MAX_SIZE% (
            echo [ANTREAN] Mengompresi: "%%F"
            call :WaitQueue
            start /b "" magick -limit thread 1 "%%F" -strip -define jpeg:extent=400kb "%%F" >nul 2>&1
        ) else (
            echo [LEWATI] "%%F" ^(Sudah di bawah 400KB^)
        )
    ) else (
        :: Proses untuk format lain (termasuk .jpeg)
        echo [ANTREAN] Konversi ^& Kompresi: "%%F"
        call :WaitQueue
        start /b "" magick -limit thread 1 "%%F" -strip -define jpeg:extent=400kb "%%~nF.jpg" >nul 2>&1
    )
)

echo.
echo [INFO] Semua file sedang diproses di latar belakang secara bersamaan (Max 10).
echo [INFO] Harap tunggu, jangan tutup jendela ini...

:: 3. MENUNGGU SEMUA PROSES SELESAI
:WaitAll
for /f %%C in ('tasklist ^| find /c /i "magick.exe" 2^>nul') do set RUNNING_TOTAL=%%C
if !RUNNING_TOTAL! GTR 0 (
    timeout /t 2 >nul
    goto WaitAll
)

:: 4. PEMBERSIHAN FILE LAMA
echo.
echo [INFO] Proses kompresi selesai. Membersihkan format lama...
for %%F in (*.jpeg *.png *.heic *.webp *.bmp) do (
    if exist "%%~nF.jpg" (
        del "%%F"
        echo [HAPUS] "%%F" telah dihapus dan diganti menjadi JPG.
    )
)

echo.
echo ==================================================
echo Semua tugas kompresi dan konversi selesai!
pause
exit /b

:: ==================================================
:: FUNGSI PEMBATAS ANTREAN (MAX_PROCESSES)
:: ==================================================
:WaitQueue
for /f %%C in ('tasklist ^| find /c /i "magick.exe" 2^>nul') do set RUNNING=%%C
if !RUNNING! GEQ %MAX_PROCESSES% (
    :: Jika ada 10 proses yang berjalan, jeda 1 detik lalu cek lagi
    timeout /t 1 >nul
    goto WaitQueue
)
exit /b