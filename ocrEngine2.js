const sharp = require('sharp');

const API_KEYS = ['K86974445588957', 'K83673440788957'];
let currentKeyIndex = 0;

const extractResiOcrSpace = async (imagePath) => {
    let allFoundResis = new Set();
    let retries = 0;

    try {
        // Kompres gambar lebih kuat agar base64 tidak terlalu panjang dan ditolak API
        const buffer = await sharp(imagePath)
            .resize({ width: 1200, withoutEnlargement: true }) 
            .jpeg({ quality: 70 }) 
            .toBuffer();
        
        const base64Image = `data:image/jpeg;base64,${buffer.toString('base64')}`;

        while (retries < 2) {
            // Menggunakan URLSearchParams (Lebih stabil di Node.js dibanding FormData)
            const params = new URLSearchParams();
            params.append('apikey', API_KEYS[currentKeyIndex]);
            params.append('language', 'eng');
            params.append('isOverlayRequired', 'false');
            params.append('scale', 'true'); // Membantu OCR membaca teks beresolusi rendah
            params.append('base64Image', base64Image);

            const response = await fetch('https://api.ocr.space/parse/image', {
                method: 'POST',
                body: params
            });

            const json = await response.json();

            // Deteksi Error atau Limit API
            if (json.IsErroredOnProcessing || json.ErrorMessage) {
                const errorStr = String(json.ErrorMessage).toLowerCase();
                
                // Jika terkena limit, ganti ke Index Key berikutnya lalu ulangi
                if (errorStr.includes('limit') || errorStr.includes('maximum') || json.OCRExitCode === 3 || json.OCRExitCode === 4) {
                    console.log(`[!] Limit tercapai pada Key ${API_KEYS[currentKeyIndex]}. Mengacak Key...`);
                    currentKeyIndex = (currentKeyIndex + 1) % API_KEYS.length;
                    retries++;
                    continue; 
                } else {
                    console.error(`[!] Error OCR.space Detail:`, json.ErrorMessage);
                    break; 
                }
            }

            if (!json.ParsedResults || !json.ParsedResults[0]) break;

            const parsedText = json.ParsedResults[0].ParsedText || '';
            const cleanText = parsedText.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
            
            // Regex murni tanpa replace huruf
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
            break; // Selesai jika berhasil hit API tapi tidak menemukan pola resi yang valid

        }
    } catch (error) {
        console.error(`[!] Error Koneksi OCR.space:`, error.message);
    }
    
    return { success: false, resis: [], scenario: 'Gagal OCR.space' };
};

module.exports = { extractResiOcrSpace };
