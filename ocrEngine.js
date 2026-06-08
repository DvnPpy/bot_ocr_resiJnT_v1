const sharp = require('sharp');
const Tesseract = require('tesseract.js');

const applyHeavyScenario = async (buffer, scenario) => {
    let img = sharp(buffer).resize({ width: 2000, withoutEnlargement: true });
    let psm = Tesseract.PSM.AUTO;

    switch (scenario) {
        case 1: break; 
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
            break;
        case 5:
            img = img.grayscale().linear(1.5, -(128 * 0.5));
            psm = Tesseract.PSM.SINGLE_BLOCK; 
            break;
    }
    return { buffer: await img.toBuffer(), psm };
};

const extractResiOffline = async (imagePath) => {
    const originalBuffer = await sharp(imagePath).toBuffer();
    let allFoundResis = new Set(); 

    for (let i = 1; i <= 5; i++) {
        try {
            const { buffer, psm } = await applyHeavyScenario(originalBuffer, i);
            const { data: { text } } = await Tesseract.recognize(buffer, 'eng', {
                tessedit_pageseg_mode: psm
            });
            
            const cleanText = text.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
            const RESI_REGEX = /(J[XODZ]|13)([0-9OQDCUILZASGTB]{8,15})/g;
            
            let match;
            while ((match = RESI_REGEX.exec(cleanText)) !== null) {
                let prefix = match[1];
                let rawBody = match[2];
                
                let body = rawBody
                    .replace(/[OQDCU]/g, '0')
                    .replace(/[IL|]/g, '1')
                    .replace(/[Z]/g, '2')
                    .replace(/[A]/g, '4')
                    .replace(/[S]/g, '5')
                    .replace(/[G]/g, '6')
                    .replace(/[T]/g, '7')
                    .replace(/[B]/g, '8');
                
                if (/^[0-9]{8,15}$/.test(body)) {
                    allFoundResis.add(prefix + body);
                }
            }
        } catch (err) {
            console.error(`[!] Error OCR Skenario ${i}:`, err.message);
        }
    }
    
    if (allFoundResis.size > 0) {
        return {
            success: true,
            resis: Array.from(allFoundResis),
            scenario: 'Multi-Lapis (Akurat)'
        };
    }
    
    return { success: false, resis: [], scenario: 'Gagal' };
};

module.exports = { extractResiOffline };
