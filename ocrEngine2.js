const sharp = require('sharp');

const API_KEYS = ['K86974445588957', 'K83673440788957'];
let currentKeyIndex = 0;

const extractResiOcrSpace = async (imagePath) => {
    let allFoundResis = new Set();
    let retries = 0;

    // Kompres gambar sebelum dikirim ke API agar ringan (< 1MB)
    const buffer = await sharp(imagePath)
        .resize({ width: 1500, withoutEnlargement: true })
        .jpeg({ quality: 80 })
        .toBuffer();
    
    const base64Image = `data:image/jpeg;base64,${buffer.toString('base64')}`;

    while (retries < 2) {
        try {
            const formData = new FormData();
            formData.append('apikey', API_KEYS[currentKeyIndex]);
            formData.append('language', 'eng');
            formData.append('isOverlayRequired', 'false');
            formData.append('base64Image', base64Image);

            const response = await fetch('https://api.ocr.space/parse/image', {
                method: 'POST',
                body: formData
            });

            const json = await response.json();

            // Deteksi Error atau Limit API
            if (json.IsErroredOnProcessing || json.ErrorMessage) {
                const errorStr = String(json.ErrorMessage).toLowerCase();
                // Jika terkena limit, ganti ke Index Key berikutnya lalu ulangi (continue)
                if (errorStr.includes('limit') || errorStr.includes('maximum') || json.OCRExitCode === 3 || json.OCRExitCode === 4) {
                    console.log(`[!] Limit tercapai pada Key ${API_KEYS[currentKeyIndex]}. Mengacak Key...`);
                    currentKeyIndex = (currentKeyIndex + 1) % API_KEYS.length;
                    retries++;
                    continue; 
                } else {
                    throw new Error(json.ErrorMessage ? json.ErrorMessage : 'Unknown Error');
                }
            }

            if (!json.ParsedResults || !json.ParsedResults[0]) break;

            const parsedText = json.ParsedResults[0].ParsedText || '';
            const cleanText = parsedText.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
            
            // Regex ketat sesuai aturan sebelumnya, tanpa me-replace huruf mirip angka
            const RESI_REGEX = /(J[XODZ]|13)([0-9]+)/g;
            let match;
            
            while ((match = RESI_REGEX.exec(cleanText)) !== null) {
                let prefix = match[1];
                let body = match[2]; 
                
                let isValid = false;
                if (prefix.startsWith('J') && (body.length === 10 || body.length === 11)) {
                    isValid = true;
                } else if (prefix === '13' && (body.length === 8 || body.length === 9)) {
                    isValid = true;
                }

                if (isValid) {
                    allFoundResis.add(prefix + body);
                }
            }
            
            if (allFoundResis.size > 0) {
                return { success: true, resis: Array.from(allFoundResis), scenario: 'OCR.space API' };
            }
            break; // Selesai loop jika API sukses tapi tidak ada teks terbaca

        } catch (error) {
            console.error(`[!] Error OCR.space:`, error.message);
            break;
        }
    }
    
    return { success: false, resis: [], scenario: 'Gagal OCR.space' };
};

module.exports = { extractResiOcrSpace };
