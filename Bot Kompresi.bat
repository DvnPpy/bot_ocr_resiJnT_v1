@echo off
setlocal enabledelayedexpansion

:: Set batas ukuran 400KB dalam bytes (400 x 1024 = 409600 bytes)
set MAX_SIZE=409600

echo ==========================================
echo    Program Kompresi Foto (Max 400KB)
echo ==========================================
echo.

:: 1. CEK DAN INSTALASI IMAGEMAGICK OTOMATIS
where magick >nul 2>nul
if %errorlevel% neq 0 (
    echo [INFO] ImageMagick belum terinstal di komputer ini.
    echo [PROSES] Mengunduh dan menginstal ImageMagick secara otomatis...
    echo [INFO] Harap tunggu, proses ini mungkin memakan waktu beberapa menit.
    
    :: Menggunakan winget untuk instalasi otomatis secara diam-diam (silent)
    winget install ImageMagick.ImageMagick --silent --accept-package-agreements --accept-source-agreements
    
    if %errorlevel% neq 0 (
        echo [GAGAL] Tidak dapat menginstal secara otomatis. Pastikan internet aktif atau Windows kamu mendukung Winget.
        pause
        exit /b
    )
    
    echo [SUKSES] ImageMagick berhasil diinstal!
    echo ==========================================
    echo [PENTING] Karena aplikasi baru saja diinstal, CMD perlu di-refresh.
    echo Tekan tombol apa saja untuk menutup jendela ini.
    echo Setelah tertutup, silakan KLIK GANDA LAGI file .bat ini untuk mulai mengompresi foto.
    pause
    exit
) else (
    echo [INFO] ImageMagick sudah terinstal. Sistem siap!
)

echo.

:: 2. PROSES KOMPRESI FOTO
for %%F in (*.jpg *.jpeg *.png) do (
    :: Cek apakah ukuran file lebih besar dari batas MAX_SIZE
    if %%~zF GTR %MAX_SIZE% (
        echo [PROSES] Mengompresi: "%%F" ^(Ukuran asli: %%~zF bytes^)
        
        :: Perintah ImageMagick untuk menghapus metadata (lossless) & mencari kualitas terbaik maksimal 400kb
        magick "%%F" -strip -define jpeg:extent=400kb "%%F"
        
        echo [SUKSES] "%%F" berhasil dikompresi.
    ) else (
        echo [LEWATI] "%%F" ^(Ukuran sudah di bawah 400KB^)
    )
)

echo.
echo ==========================================
echo Proses selesai!
pause