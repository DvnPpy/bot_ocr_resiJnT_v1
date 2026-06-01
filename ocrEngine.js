const sharp = require('sharp');
const Tesseract = require('tesseract.js');

// Fungsi 5 Lapis Manipulasi Gambar
const applyScenario = async (buffer, scenario) => {
    let img = sharp(buffer).resize({ width: 1600, withoutEnlargement: true });
    
    switch (scenario) {
        case 1: // 1. Optimal (Original Resized)
            break;
        case 2: // 2. Grayscale (Buang noise warna)
            img = img.grayscale();
            break;
        case 3: // 3. High Contrast (Pekatkan tinta)
            img = img.grayscale().linear(1.5, -(128 * 0.5));
            break;
        case 4: // 4. Binarization (Hitam Putih Murni)
            img = img.grayscale().threshold(128);
            break;
        case 5: // 5. Sharpen (Pertajam foto blur)
            img = img.sharpen({ sigma: 2 });
            break;
    }
    return await img.toBuffer();
};

// Fungsi Ekstraksi Resi
const extractResiOffline = async (imagePath) => {
    const originalBuffer = await sharp(imagePath).toBuffer();
    
    for (let i = 1; i <= 5; i++) {
        try {
            const processedBuffer = await applyScenario(originalBuffer, i);
            const { data: { text } } = await Tesseract.recognize(processedBuffer, 'eng');
            
            // Deteksi Format J&T (JP/JX/JD/JO/JZ atau 13xxxx)
            const RESI_REGEX = /\b(J[P|X|D|O|Z][0-9]{8,15}|13[0-9]{10,15})\b/gi;
            const matches = text.match(RESI_REGEX);
            
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
    
    // Jika lewat 5 lapis tetap gagal
    return { success: false, resis: [], scenario: 5 };
};

module.exports = { extractResiOffline };