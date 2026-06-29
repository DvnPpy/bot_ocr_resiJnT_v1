const sharp = require('sharp');
const Tesseract = require('tesseract.js');

// Tabel koreksi karakter OCR yang sering salah baca
const CHAR_CORRECTION = {
    'O': '0', 'Q': '0', 'D': '0', 'C': '0', 'U': '0',
    'I': '1', 'L': '1', '|': '1',
    'Z': '2',
    'A': '4',
    'S': '5',
    'G': '6',
    'T': '7',
    'B': '8'
};

const correctOcrChars = (str) => {
    return str.split('').map(c => CHAR_CORRECTION[c] ?? c).join('');
};

const validateResi = (prefix, body) => {
    if (prefix.startsWith('J') && (body.length === 10 || body.length === 11)) return true;
    if (prefix === '13' && (body.length === 8 || body.length === 9)) return true;
    return false;
};

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
    try {
        const originalBuffer = await sharp(imagePath).toBuffer();
        let allFoundResis = new Set();
        let isSuccess = false;
        let successfulScenario = '';

        for (let i = 1; i <= 5; i++) {
            if (isSuccess) break;

            try {
                const { buffer, psm } = await applyHeavyScenario(originalBuffer, i);
                const { data: { text } } = await Tesseract.recognize(buffer, 'eng', {
                    tessedit_pageseg_mode: psm,
                    logger: () => {}
                });

                const cleanText = text.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
                const RESI_REGEX = /(J[XODZ]|13)([0-9OQDCUILZASGTB]+)/g;

                let match;
                while ((match = RESI_REGEX.exec(cleanText)) !== null) {
                    const prefix = match[1];
                    const body = correctOcrChars(match[2]);

                    if (validateResi(prefix, body) && /^[0-9]+$/.test(body)) {
                        allFoundResis.add(prefix + body);
                        isSuccess = true;
                        successfulScenario = `Skenario ${i}`;
                    }
                }
            } catch (err) {
                // Abaikan jika 1 skenario error, biarkan skenario lain jalan
            }
        }

        if (allFoundResis.size > 0) {
            return {
                success: true,
                resis: Array.from(allFoundResis),
                scenario: successfulScenario
            };
        }
    } catch (error) {
        // Abaikan jika file korup
    }

    return { success: false, resis: [], scenario: 'Gagal' };
};

module.exports = { extractResiOffline, correctOcrChars, validateResi };
