const sharp = require('sharp'); // 👈 PASTIKAN BARIS INI ADA
const Tesseract = require('tesseract.js');

const extractResiOffline = async (imagePath) => {
    const originalBuffer = await sharp(imagePath).toBuffer();
    let allFoundResis = new Set(); 
    let isSuccess = false; // Flag untuk menghentikan loop jika sudah ketemu
    let successfulScenario = '';

    for (let i = 1; i <= 5; i++) {
        if (isSuccess) break; // ⚡ OPTIMASI: Hentikan skenario berat jika resi sudah ditemukan

        try {
            const { buffer, psm } = await applyHeavyScenario(originalBuffer, i);
            const { data: { text } } = await Tesseract.recognize(buffer, 'eng', {
                tessedit_pageseg_mode: psm
            });
            
            const cleanText = text.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
            
            // Regex diubah untuk menangkap semua rentetan angka/huruf mirip angka
            // Panjangnya akan divalidasi di bawah secara ketat
            const RESI_REGEX = /(J[XODZ]|13)([0-9OQDCUILZASGTB]+)/g;
            
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
                
                let isValid = false;

                // 🛑 ATURAN KETAT
                if (prefix.startsWith('J')) {
                    // JX, JO, JD, JZ harus tepat +10 atau +11 angka di belakangnya
                    if (body.length === 10 || body.length === 11) {
                        isValid = true;
                    }
                } else if (prefix === '13') {
                    // 13 harus memiliki total panjang 10 atau 11 digit dari depan hingga belakang
                    // Artinya digit di belakang angka 13 harus tepat 8 atau 9 angka
                    if (body.length === 8 || body.length === 9) {
                        isValid = true;
                    }
                }

                // Cek tambahan agar memastikan body murni angka setelah diconvert
                if (isValid && /^[0-9]+$/.test(body)) {
                    allFoundResis.add(prefix + body);
                    isSuccess = true;
                    successfulScenario = `Skenario ${i}`;
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
            scenario: successfulScenario
        };
    }
    
    return { success: false, resis: [], scenario: 'Gagal' };
};

module.exports = { extractResiOffline };
