Berikut adalah rancangan detail untuk file `README.md` yang bisa langsung kamu gunakan untuk repositori GitHub barumu. Isinya sudah disesuaikan secara khusus dengan arsitektur *offline*, skenario 5 lapis, fitur *override* resi ganda, dan pembagian manifest per 900 AWB.

```markdown
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

```

---

## 🚀 Cara Instalasi

### Prasyarat:

Pastikan kamu sudah menginstal **Node.js** di komputermu. Jika belum, unduh dan instal dari [nodejs.org](https://nodejs.org/).

### Langkah-langkah:

1. Unduh atau *Clone* repositori ini.
2. Klik ganda pada file `Install-bot.bat`. Skrip ini akan secara otomatis:
* Mengunduh dan memasang Git (jika belum ada).
* Menghubungkan direktori ke repositori GitHub.
* Memasang semua mesin OCR dan dependensi lokal (`npm install`).


3. Tunggu hingga terminal menunjukkan pesan "Setup Selesai!".

---

## 💻 Cara Menjalankan Bot

1. Klik ganda pada file `start-bot.bat`.
2. Skrip akan mengecek pembaruan (update) di GitHub terlebih dahulu:
* **Jika ada update:** Akan terunduh otomatis dan sistem akan memintamu menjalankan ulang `start-bot.bat`.
* **Jika tidak ada update (atau sedang offline):** Bot akan langsung menyalakan server lokal.


3. Buka browser (Chrome/Edge/Firefox) dan akses:
👉 **`http://localhost:31912`**

---

## 📖 Panduan Penggunaan Dashboard

1. **Upload Massal:** Klik **"Pilih File"** pada Dashboard, blok/pilih ratusan foto resi J&T sekaligus dari komputermu, lalu klik **"Unggah Foto (Massal)"**.
2. **Pantau Proses:** Perhatikan indikator antrean (Queue) dan Activity Log di sisi kanan untuk melihat status *real-time* foto yang sedang dianalisis.
3. **Tinjauan Manual (Gagal):** Gulir ke bawah pada panel *Kontrol*. Jika ada foto yang gagal diekstrak, foto akan muncul di sana. Ketik nomor resinya dan klik **Simpan**.
4. **Ekspor Data:** Jika semua antrean sudah selesai, klik tombol hijau **"Download Excel Manifest"**. File `.xlsx` akan langsung masuk ke folder `manifests/` di dalam direktori bot.

---

## 🛠️ Stack Teknologi

* **Node.js** & **Express** (Local Web Server)
* **Tesseract.js** (Offline Optical Character Recognition)
* **Sharp** (Image Processing & Kompresi)
* **Multer** (Penanganan Upload Massal)
* **ExcelJS** (Manipulasi Spreadsheet otomatis)
* **Socket.io** (WebSockets untuk log *real-time*)

---

**Developed by delfin** · Offline Logistics Automation System

```

```
