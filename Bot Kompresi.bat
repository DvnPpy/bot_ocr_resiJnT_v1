@echo off
setlocal enabledelayedexpansion

:: Set batas ukuran 400KB dalam bytes (400 x 1024 = 409600 bytes)
set MAX_SIZE=409600

echo ==================================================
echo    Program Kompresi ^& Konversi Seragam ke .JPG
echo ==================================================
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
    echo Setelah tertutup, silakan KLIK GANDA LAGI file .bat ini untuk mulai.
    pause
    exit
) else (
    echo [INFO] ImageMagick sudah terinstal. Sistem siap!
)

echo.

:: 2. PROSES KONVERSI DAN KOMPRESI FOTO
:: Memproses berbagai format gambar umum (termasuk .jpeg)
for %%F in (*.jpg *.jpeg *.png *.heic *.webp *.bmp) do (
    :: Mengecek apakah file sudah memiliki ekstensi .jpg yang presisi
    set "is_exact_jpg=0"
    if /I "%%~xF"==".jpg" set "is_exact_jpg=1"
    
    if "!is_exact_jpg!"=="1" (
        :: JIKA SUDAH .JPG: Cukup cek ukuran dan kompresi jika perlu
        if %%~zF GTR %MAX_SIZE% (
            echo [PROSES] Mengompresi JPG: "%%F" ^(Ukuran asli: %%~zF bytes^)
            magick "%%F" -strip -define jpeg:extent=400kb "%%F"
            echo [SUKSES] "%%F" berhasil dikompresi.
        ) else (
            echo [LEWATI] "%%F" ^(JPG sudah di bawah 400KB^)
        )
    ) else (
        :: JIKA BUKAN .JPG (TERMASUK .JPEG): Konversi ke .jpg dan kompresi
        echo [KONVERSI] Mengubah format "%%F" menjadi .jpg...
        
        :: Output dipaksa menjadi .jpg dengan ukuran maksimal 400kb
        magick "%%F" -strip -define jpeg:extent=400kb "%%~nF.jpg"
        
        :: Menghapus file format lama (termasuk .jpeg) jika file .jpg berhasil dibuat
        if exist "%%~nF.jpg" (
            del "%%F"
            echo [SUKSES] Berhasil dikonversi menjadi "%%~nF.jpg" dan file asli dihapus.
        ) else (
            echo [GAGAL] Terjadi kesalahan saat mengonversi "%%F".
        )
    )
)

echo.
echo ==================================================
echo Semua proses kompresi dan konversi selesai!
pause
