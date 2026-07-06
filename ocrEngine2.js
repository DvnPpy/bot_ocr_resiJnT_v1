const sharp = require('sharp');
const fs = require('fs');

// Menarik kunci rahasia dari environment variables (disediakan oleh .env)
const rawKeys = process.env.OCR_KEYS || '';
const API_KEYS = rawKeys.split(',').map(k => k.trim()).filter(Boolean);
let currentKeyIndex = 0;

// Fungsi penahan waktu agar tidak dicap "Spammer" oleh API
const delay = ms => new Promise(res => setTimeout(res, ms));

const extractResiOcrSpace = async (imagePath) => {
    let allFoundResis = new Set();
    let retries = 0;

    // Proteksi jika lupa mengatur kunci di .env
    if (API_KEYS.length === 0) {
        console.error(`[!] ERROR: API Key OCR.space tidak ditemukan di file .env!`);
        return { success: false, resis: [], scenario: 'Kunci API Hilang' };
    }

    try {
        let imageBuffer = fs.readFileSync(imagePath);

        // Kompresi jika lebih dari 4MB
        if (imageBuffer.length > 4 * 1024 * 1024) {
            imageBuffer = await sharp(imageBuffer).jpeg({ quality: 80 }).toBuffer();
        }

        const blob = new Blob([imageBuffer], { type: 'image/jpeg' });

        while (retries < 2) {
            await delay(1500);

            const formData = new FormData();
            formData.append('apikey', API_KEYS[currentKeyIndex]);
            formData.append('language', 'eng');
            formData.append('scale', 'true');
            formData.append('isTable', 'true');
            formData.append('file', blob, 'image.jpg');

            const response = await fetch('https://api.ocr.space/parse/image', {
                method: 'POST',
                body: formData
            });

            const json = await response.json();

            if (json.IsErroredOnProcessing || json.ErrorMessage) {
                const errorStr = String(json.ErrorMessage).toLowerCase();
                
                if (errorStr.includes('limit') || errorStr.includes('maximum') || json.OCRExitCode === 3 || json.OCRExitCode === 4) {
                    console.log(`[!] OCR Limit/Spam-Block di Key ${API_KEYS[currentKeyIndex]}. Mengganti kunci...`);
                    currentKeyIndex = (currentKeyIndex + 1) % API_KEYS.length;
                    retries++;
                    continue; 
                } else {
                    console.error(`[!] Error dari Server OCR.space:`, json.ErrorMessage);
                    break; 
                }
            }

            if (!json.ParsedResults || !json.ParsedResults[0]) {
                console.log(`[!] Engine 2 memproses, tapi gambar ini tidak mengandung teks yang bisa dikenali.`);
                break;
            }

            const parsedText = json.ParsedResults[0].ParsedText || '';
            const cleanText = parsedText.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
            
            const RESI_REGEX = /(J[A-Z]|13)([0-9]+)/g;
            let match;
            
            while ((match = RESI_REGEX.exec(cleanText)) !== null) {
                let prefix = match[1];
                let body = match[2]; 
                
                let isValid = false;
                if (prefix.startsWith('J') && (body.length === 10 || body.length === 11)) isValid = true;
                else if (prefix === '13' && (body.length === 8 || body.length === 9)) isValid = true;

                if (isValid) allFoundResis.add(prefix + body);
            }
            
            if (allFoundResis.size > 0) {
                return { success: true, resis: Array.from(allFoundResis), scenario: 'OCR.space API' };
            } else {
                console.log(`[!] Engine 2 tidak menemukan kombinasi resi J&T yang valid.`);
                break; 
            }
        }
    } catch (error) {
        console.error(`[!] Error Sistem/Koneksi Internet di Engine 2:`, error.message);
    }
    
    return { success: false, resis: [], scenario: 'Gagal OCR.space' };
};

module.exports = { extractResiOcrSpace };
