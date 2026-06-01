# 📦 Bot OCR Resi J&T Offline V2

Sistem pembaca teks resi (AWB) J&T Express **100% Offline** menggunakan Node.js dan Tesseract.js. Dirancang untuk memproses ribuan foto resi secara massal, efisien, dan cepat melalui Dashboard GUI lokal tanpa batasan *rate limit* API.

---

## ✨ Fitur Utama

- 🔌 **100% Pemrosesan Offline:** Bebas dari biaya API, *rate limit*, dan tidak memerlukan koneksi internet aktif saat mengeksekusi OCR.
- 🧠 **5 Lapis Skenario Ekstraksi (Auto-Enhancement):** Menggunakan `sharp` untuk memanipulasi foto secara berjenjang jika resi gagal terbaca (Original -> Grayscale -> High Contrast -> Binarization -> Sharpening).
- 🛡️ **Proteksi Anti-Duplikat:**
  - **Lapis 1:** Otomatis memblokir file foto yang di-upload berulang (berdasarkan nama file) di sesi yang sama.
  - **Lapis 2:** Menimpa (*overwrite*) foto lama jika hasil bacaan resi terdeteksi sama dengan data sebelumnya.
- 🛠️ **Manual Override & Multi-Resi:** Jika OCR menyerah, foto dipindah ke tab khusus. Kamu bisa ketik nomor resi secara manual. Jika satu foto memuat banyak resi, cukup pisahkan dengan koma (contoh: `JX123,JX456`) dan bot otomatis menggandakan file tersebut.
- 📊 **Ekspor Manifest Otomatis:** Rekap data berformat vertikal ke Excel (`.xlsx`), dipotong dan dibagi otomatis **per 900 AWB** per file.
- 🔄 **Smart Auto-Update:** Mengecek pembaruan langsung dari GitHub setiap kali bot dinyalakan via `.bat`.

---

## 📂 Struktur Direktori

```text
bot_ocr_resiJnT_v1/
├── public/                 # Folder antarmuka Dashboard
│   └── index.html          # File UI / GUI utama
├── index.js                # Core server, queue system, & routing
├── ocrEngine.js            # Mesin filter gambar & OCR Tesseract
├── package.json            # Daftar dependensi library
├── Install-bot.bat         # Setup otomatis & sinkronisasi Git
├── start-bot.bat           # Auto-updater & Runner Bot
└── [Dibuat Otomatis oleh Sistem]
    ├── manifests/          # Tempat file Excel (.xlsx) disimpan
    ├── temp_uploads/       # Antrean sementara sebelum diproses
    ├── POD_GAGAL/          # Karantina foto yang gagal terbaca
    └── POD_DD_Bln_YYYY/    # Folder hasil sukses (nama diganti ke No. Resi)