const sharp = require('sharp');
const Tesseract = require('tesseract.js');

// Fungsi 5 Lapis Manipulasi Gambar & Konfigurasi Tesseract
const applyScenario = async (buffer, scenario) => {
    let img = sharp(buffer).resize({ width: 2000, withoutEnlargement: true });
    let psm = Tesseract.PSM.AUTO;

    switch (scenario) {
        case 1: psm = Tesseract.PSM.AUTO; break;
        case 2: 
            img = img.grayscale().normalize();
            psm = Tesseract.PSM.SPARSE_TEXT; 
            break;
        case 3: 
            img = img.grayscale().median(3).sharpen({ sigma: 2 });
            psm = Tesseract.PSM.SPARSE_TEXT;
            break;
        case 4: 
            img = img.grayscale().normalize().threshold(140);
            psm = Tesseract.PSM.AUTO;
            break;
        case 5: 
            img = img.grayscale().linear(1.5, -(128 * 0.5));
            psm = Tesseract.PSM.SINGLE_BLOCK; 
            break;
    }
    return { buffer: await img.toBuffer(), psm };
};

// Fungsi Ekstraksi Resi dengan Auto-Correct Typo
const extractResiOffline = async (imagePath) => {
    const originalBuffer = await sharp(imagePath).toBuffer();
    
    for (let i = 1; i <= 5; i++) {
        try {
            const { buffer, psm } = await applyScenario(originalBuffer, i);
            const { data: { text } } = await Tesseract.recognize(buffer, 'eng', {
                tessedit_pageseg_mode: psm
            });
            
            // 1. HAPUS SEMUA SIMBOL: Buang kurung 【 】, koma, spasi. Tinggalkan hanya A-Z dan 0-9
            const cleanText = text.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
            
            // 2. REGEX FLEKSIBEL: Awalan (JX/JO/JD/JZ/13) diikuti oleh Angka & Huruf Typo OCR (S, O, I, L, dll)
            const RESI_REGEX = /(J[XODZ]|13)([0-9OSILZBGTQAC]{8,15})/g;
            
            let matches = [];
            let match;
            
            // Looping untuk mencari semua kemungkinan resi di dalam teks
            while ((match = RESI_REGEX.exec(cleanText)) !== null) {
                let prefix = match[1];
                let body = match[2];
                
                // 3. AUTO-KOREKSI FONT MELENGKUNG
                body = body.replace(/[OQDC]/g, '0')
                           .replace(/[IL]/g, '1')
                           .replace(/[Z]/g, '2')
                           .replace(/[A]/g, '4')
                           .replace(/[S]/g, '5')
                           .replace(/[G]/g, '6')
                           .replace(/[T]/g, '7')
                           .replace(/[B]/g, '8');
                
                // 4. VALIDASI FINAL: Pastikan setelah dikoreksi, body benar-benar murni angka
                if (/^[0-9]{8,15}$/.test(body)) {
                    matches.push(prefix + body);
                }
            }
            
            // Jika resi berhasil ditemukan, kembalikan datanya (hapus duplikat dengan Set)
            if (matches.length > 0) {
                return {
                    success: true,
                    resis: [...new Set(matches)],
                    scenario: i
                };
            }
        } catch (err) {
            console.error(`[!] Error OCR Skenario ${i}:`, err.message);
        }
    }
    
    // Jika semua 5 skenario gagal
    return { success: false, resis: [], scenario: 5 };
};

module.exports = { extractResiOffline };
