const sharp = require('sharp');
const fs = require('fs');

const API_KEYS = ['K86974445588957', 'K83673440788957'];
let currentKeyIndex = 0;

// Fungsi penahan waktu agar tidak dicap "Spammer" oleh API
const delay = ms => new Promise(res => setTimeout(res, ms));

const extractResiOcrSpace = async (imagePath) => {
    let allFoundResis = new Set();
    let retries = 0;

    try {
        let imageBuffer = fs.readFileSync(imagePath);

        // Cek ukuran asli gambar. OCR.space gratis punya batas 5MB per file.
        // Jika lebih dari 4MB, kita kompres perlahan TANPA mengubah dimensi/merusak piksel.
        if (imageBuffer.length > 4 * 1024 * 1024) {
            imageBuffer = await sharp(imageBuffer)
                .jpeg({ quality: 80 }) 
                .toBuffer();
        }

        // Ubah Buffer menjadi Blob agar bisa disisipkan sebagai File ke dalam FormData
        const blob = new Blob([imageBuffer], { type: 'image/jpeg' });

        while (retries < 2) {
            // Tahan antrean 1.5 detik untuk menghindari Rate Limit (maks 1 request/detik)
            await delay(1500);

            const formData = new FormData();
            formData.append('apikey', API_KEYS[currentKeyIndex]);
            formData.append('language', 'eng');
            formData.append('scale', 'true'); // Optimasi membaca teks kecil
            formData.append('isTable', 'true'); // Parsing khusus struk/manifest data
            formData.append('file', blob, 'image.jpg');

            const response = await fetch('https://api.ocr.space/parse/image', {
                method: 'POST',
                body: formData
            });

            const json = await response.json();

            // Laporan Error Langsung dari Server OCR
            if (json.IsErroredOnProcessing || json.ErrorMessage) {
                const errorStr = String(json.ErrorMessage).toLowerCase();
                
                // Jika limit bulanan / limit kecepatan tercapai
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

            // Jika API sukses tapi gambar terlalu buram/tidak terbaca
            if (!json.ParsedResults || !json.ParsedResults[0]) {
                console.log(`[!] Engine 2 memproses, tapi gambar ini tidak mengandung teks yang bisa dikenali.`);
                break;
            }

            const parsedText = json.ParsedResults[0].ParsedText || '';
            const cleanText = parsedText.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
            
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
            } else {
                console.log(`[!] Engine 2 membaca teks, tapi tidak menemukan kombinasi huruf/angka resi J&T yang valid.`);
                break; 
            }
        }
    } catch (error) {
        console.error(`[!] Error Sistem/Koneksi Internet di Engine 2:`, error.message);
    }
    
    return { success: false, resis: [], scenario: 'Gagal OCR.space' };
};

module.exports = { extractResiOcrSpace };
