const sharp = require('sharp');
const Tesseract = require('tesseract.js');

const applyScenario = async (buffer, scenario) => {
    let img = sharp(buffer).resize({ width: 1600, withoutEnlargement: true });
    switch (scenario) {
        case 1: break;
        case 2: img = img.grayscale(); break;
        case 3: img = img.grayscale().linear(1.5, -(128 * 0.5)); break;
        case 4: img = img.grayscale().threshold(128); break;
        case 5: img = img.sharpen({ sigma: 2 }); break;
    }
    return await img.toBuffer();
};

const extractResiOffline = async (imagePath) => {
    const originalBuffer = await sharp(imagePath).toBuffer();
    
    for (let i = 1; i <= 5; i++) {
        try {
            const processedBuffer = await applyScenario(originalBuffer, i);
            const { data: { text } } = await Tesseract.recognize(processedBuffer, 'eng');
            
            // KUNCI OPSI 5: Hapus semua spasi, enter (\n), dan strip sebelum dicek Regex
            const cleanText = text.replace(/[\r\n\s\-]+/g, ''); 
            
            // Regex khusus JX, JO, JD, JZ, dan awalan 13
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
