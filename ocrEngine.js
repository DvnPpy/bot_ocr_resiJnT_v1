const sharp = require('sharp');
const Tesseract = require('tesseract.js');

const applyHeavyScenario = async (buffer, scenario) => {
    // Skala masif 3000px untuk meratakan pixel font melengkung
    let img = sharp(buffer).resize({ width: 3000, withoutEnlargement: true });
    let psm = Tesseract.PSM.SPARSE_TEXT; 

    switch (scenario) {
        case 1:
            // Standar Kontras Tinggi
            img = img.normalize().linear(1.5, -20);
            break;
        case 2:
            // Hitam Putih Murni (Thresholding Kuat)
            img = img.grayscale().normalize().threshold(150);
            break;
        case 3:
            // TRIK RAHASIA FONT MELENGKUNG: Blur sedikit lalu ditebalkan
            // Ini membuat lekukan font menyatu dan menghilangkan jarak antar huruf
            img = img.grayscale().blur(0.8).threshold(130);
            break;
        case 4:
            // Sharpen Maksimal untuk mempertegas garis
            img = img.grayscale().sharpen({ sigma: 3, m1: 1000, m2: 50 });
            break;
        case 5:
            // Negatif: Teks putih, background hitam
            img = img.grayscale().normalize().negate();
            break;
        case 6:
            // Teks Blok (Menganggap gambar sebagai satu kesatuan paragraf)
            img = img.grayscale().normalize();
            psm = Tesseract.PSM.SINGLE_BLOCK;
            break;
    }
    return { buffer: await img.toBuffer(), psm };
};

const extractResiOffline = async (imagePath) => {
    const originalBuffer = await sharp(imagePath).toBuffer();
    let allFoundResis = new Set(); // Wadah untuk mengumpulkan SEMUA temuan

    // KUNCI UTAMA: Jangan berhenti! 
    // Jalankan SEMUA 6 skenario dan sapu bersih semua resi yang tertangkap
    for (let i = 1; i <= 6; i++) {
        try {
            const { buffer, psm } = await applyHeavyScenario(originalBuffer, i);
            
            // Whitelist: Paksa Tesseract HANYA melihat huruf kapital dan angka
            const { data: { text } } = await Tesseract.recognize(buffer, 'eng', {
                tessedit_pageseg_mode: psm,
                tessedit_char_whitelist: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            });
            
            // Bersihkan teks, hilangkan spasi/simbol
            const cleanText = text.replace(/[^A-Z0-9]/g, '');
            
            // Regex Pattern (Ambil Prefix JX/JO/JD/JZ/13 dan tangkap 8-15 digit body-nya)
            const RESI_REGEX = /(J[XODZ]|13)([A-Z0-9]{8,15})/g;
            
            let match;
            while ((match = RESI_REGEX.exec(cleanText)) !== null) {
                let prefix = match[1];
                let rawBody = match[2];
                
                // Koreksi Typo HANYA pada bagian body/angka, biarkan prefixnya utuh
                let body = rawBody
                    .replace(/[OQDU]/g, '0')
                    .replace(/[IL|]/g, '1')
                    .replace(/[Z]/g, '2')
                    .replace(/[A]/g, '4')
                    .replace(/[S]/g, '5')
                    .replace(/[G]/g, '6')
                    .replace(/[T]/g, '7')
                    .replace(/[B]/g, '8');
                
                // Validasi akhir: Pastikan body yang sudah dikoreksi murni angka
                if (/^[0-9]{8,15}$/.test(body)) {
                    allFoundResis.add(prefix + body);
                }
            }
        } catch (err) {
            console.error(`[!] Error OCR Skenario ${i}:`, err.message);
        }
    }
    
    // Jika dari 6 lapis pemrosesan ada resi yang berhasil disaring, return semuanya!
    if (allFoundResis.size > 0) {
        return {
            success: true,
            resis: Array.from(allFoundResis),
            scenario: 'Heavy Mode (6 Lapis)'
        };
    }
    
    return { success: false, resis: [], scenario: 'Gagal di Semua Lapis' };
};

module.exports = { extractResiOffline };
