require('dotenv').config();
const sharp = require('sharp');
const fs = require('fs');

// FIX: Import fungsi koreksi karakter dari Engine 1
// agar kedua engine punya perilaku validasi yang konsisten
const { correctOcrChars, validateResi } = require('./ocrEngine');

// FIX: API Key tidak lagi hardcoded — baca dari file .env
// Salin ".env.example" menjadi ".env" dan isi dengan key Anda
const API_KEYS = [
    process.env.OCR_API_KEY_1,
    process.env.OCR_API_KEY_2,
].filter(Boolean); // Abaikan key yang kosong/tidak diset

if (API_KEYS.length === 0) {
    console.error('[FATAL] Tidak ada OCR API Key yang ditemukan di file .env!');
    console.error('[INFO]  Salin .env.example menjadi .env lalu isi API Key Anda.');
}

let currentKeyIndex = 0;

const delay = ms => new Promise(res => setTimeout(res, ms));

const extractResiOcrSpace = async (imagePath) => {
    if (API_KEYS.length === 0) {
        return { success: false, resis: [], scenario: 'Gagal: Tidak ada API Key' };
    }

    let allFoundResis = new Set();
    let retries = 0;

    try {
        let imageBuffer = fs.readFileSync(imagePath);

        if (imageBuffer.length > 4 * 1024 * 1024) {
            imageBuffer = await sharp(imageBuffer)
                .jpeg({ quality: 80 })
                .toBuffer();
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

            // FIX: Gunakan regex yang sama dengan Engine 1, termasuk karakter OCR yang sering salah baca
            const RESI_REGEX = /(J[XODZ]|13)([0-9OQDCUILZASGTB]+)/g;
            let match;

            while ((match = RESI_REGEX.exec(cleanText)) !== null) {
                const prefix = match[1];
                // FIX: Terapkan koreksi karakter yang sama dengan Engine 1
                const body = correctOcrChars(match[2]);

                if (validateResi(prefix, body) && /^[0-9]+$/.test(body)) {
                    allFoundResis.add(prefix + body);
                }
            }

            if (allFoundResis.size > 0) {
                return { success: true, resis: Array.from(allFoundResis), scenario: 'OCR.space API' };
            } else {
                console.log(`[!] Engine 2 membaca teks, tapi tidak menemukan resi J&T yang valid.`);
                break;
            }
        }
    } catch (error) {
        console.error(`[!] Error Sistem/Koneksi Internet di Engine 2:`, error.message);
    }

    return { success: false, resis: [], scenario: 'Gagal OCR.space' };
};

module.exports = { extractResiOcrSpace };
