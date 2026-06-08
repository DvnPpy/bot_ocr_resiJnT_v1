const sharp = require('sharp');
const Tesseract = require('tesseract.js');

// Fungsi 5 Lapis Manipulasi Gambar & Konfigurasi Tesseract
const applyScenario = async (buffer, scenario) => {
    // UPGRADE: Resolusi ditingkatkan ke 2000px agar font unik lebih jelas terbaca
    let img = sharp(buffer).resize({ width: 2000, withoutEnlargement: true });
    
    // Default PSM (Page Segmentation Mode)
    let psm = Tesseract.PSM.AUTO; // Mode 3: Paragraf standar

    switch (scenario) {
        case 1: 
            // Skenario 1: Original Resized (Auto PSM)
            psm = Tesseract.PSM.AUTO;
            break;
        case 2: 
            // Skenario 2: Grayscale + Normalize
            // Normalize meratakan warna, sangat bagus untuk screenshot miring
            img = img.grayscale().normalize();
            // SPARSE_TEXT (Mode 11): AI mencari teks berantakan/miring di seluruh gambar
            psm = Tesseract.PSM.SPARSE_TEXT; 
            break;
        case 3: 
            // Skenario 3: Median Filter + Sharpen
            // Median(3) membersihkan noise/bercak di sekitar font melengkung
            img = img.grayscale().median(3).sharpen({ sigma: 2 });
            psm = Tesseract.PSM.SPARSE_TEXT;
            break;
        case 4: 
            // Skenario 4: Binarization / Hitam Putih Murni
            img = img.grayscale().normalize().threshold(140);
            psm = Tesseract.PSM.AUTO;
            break;
        case 5: 
            // Skenario 5: High Contrast Agresif
            // Anggap gambar sebagai satu blok teks besar (Mode 6)
            img = img.grayscale().linear(1.5, -(128 * 0.5));
            psm = Tesseract.PSM.SINGLE_BLOCK; 
            break;
    }
    return { buffer: await img.toBuffer(), psm };
};

// Fungsi Ekstraksi Resi
const extractResiOffline = async (imagePath) => {
    const originalBuffer = await sharp(imagePath).toBuffer();
    
    for (let i = 1; i <= 5; i++) {
        try {
            // Ambil buffer gambar dan mode PSM yang direkomendasikan skenario
            const { buffer, psm } = await applyScenario(originalBuffer, i);
            
            // Masukkan mode PSM ke Tesseract
            const { data: { text } } = await Tesseract.recognize(buffer, 'eng', {
                tessedit_pageseg_mode: psm
            });
            
            // Hapus semua spasi, enter (\n), titik, koma, dan strip
            // Ini mencegah resi terputus/patah karena enter atau spasi tak sengaja
            const cleanText = text.replace(/[\r\n\s\-\,\.]+/g, '');
            
            // Regex tetap dipertahankan sesuai permintaan: JX, JO, JD, JZ, atau 13
            const RESI_REGEX = /(J[XODZ][0-9]{8,15}|13[0-9]{10,15})/gi;
            const matches = cleanText.match(RESI_REGEX);
            
            if (matches && matches.length > 0) {
                return {
                    success: true,
                    resis: [...new Set(matches.map(m => m.toUpperCase()))],
                    scenario: i
                };
            }
        } catch (err) {
            console.error(`[!] Error OCR Skenario ${i}:`, err.message);
        }
    }
    
    return { success: false, resis: [], scenario: 5 };
};

module.exports = { extractResiOffline };
