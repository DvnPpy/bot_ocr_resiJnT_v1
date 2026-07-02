const sharp = require('sharp');
const Tesseract = require('tesseract.js');

const applyHighResScenario = async (buffer, scenario) => {
    // FITUR HIGH-RES (LENSA MIKRO): 
    // Memperbesar gambar secara ekstrim hingga lebar 3500px.
    // Kernel 'lanczos3' memastikan teks kecil tidak pecah/kotak-kotak saat ditarik membesar.
    let img = sharp(buffer).resize({ width: 3500, kernel: sharp.kernel.lanczos3 });
    
    let psm = Tesseract.PSM.AUTO;

    switch (scenario) {
        case 1: 
            // Skenario 1: Hanya perbesar dan pertajam sedikit
            img = img.sharpen();
            break; 
        case 2:
            // Skenario 2: Perbesar, ubah hitam putih (Grayscale), dan maksimalkan kontras
            img = img.grayscale().normalize();
            psm = Tesseract.PSM.SPARSE_TEXT; // Mode mencari teks acak yang menyebar
            break;
        case 3:
            // Skenario 3: Kurangi noise (bintik) pada foto buram, lalu pertajam secara ekstrim
            img = img.grayscale().median(3).sharpen({ sigma: 3 });
            psm = Tesseract.PSM.SPARSE_TEXT;
            break;
        case 4:
            // Skenario 4: Binarization (Paksa ubah seluruh gambar menjadi murni hitam dan putih pekat)
            img = img.grayscale().normalize().threshold(150);
            break;
    }
    return { buffer: await img.toBuffer(), psm };
};

const extractResiEngine3 = async (imagePath) => {
    try {
        const originalBuffer = await sharp(imagePath).toBuffer();
        let allFoundResis = new Set();
        let successfulScenarios = [];

        // PROSES TANPA SKIP: Menghajar foto dengan 4 skenario resolusi tinggi berturut-turut
        for (let i = 1; i <= 4; i++) {
            try {
                const { buffer, psm } = await applyHighResScenario(originalBuffer, i);
                const { data: { text } } = await Tesseract.recognize(buffer, 'eng', {
                    tessedit_pageseg_mode: psm,
                    logger: () => {} // Sembunyikan log agar terminal tetap bersih
                });
                
                const cleanText = text.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
                const RESI_REGEX = /(J[XODZ]|13)([0-9OQDCUILZASGTB]+)/g;
                
                let match;
                while ((match = RESI_REGEX.exec(cleanText)) !== null) {
                    let prefix = match[1];
                    let rawBody = match[2];
                    
                    // Koreksi otomatis jika AI salah menebak angka menjadi huruf
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
                    if (prefix.startsWith('J') && (body.length === 10 || body.length === 11)) isValid = true;
                    else if (prefix === '13' && (body.length === 8 || body.length === 9)) isValid = true;

                    if (isValid && /^[0-9]+$/.test(body)) {
                        allFoundResis.add(prefix + body);
                        successfulScenarios.push(`High-Res Sk-${i}`);
                    }
                }
            } catch (err) {
                // Konsep Tanpa Skip: Abaikan error pada satu skenario dan langsung sikat skenario berikutnya
            }
        }
        
        if (allFoundResis.size > 0) {
            // Gabungkan catatan skenario apa saja yang berhasil membaca resi kecil ini
            const uniqueScenarios = [...new Set(successfulScenarios)].join(', ');
            return {
                success: true,
                resis: Array.from(allFoundResis),
                scenario: `Lensa Mikro: ${uniqueScenarios}`
            };
        }
    } catch (error) {
        // Abaikan jika file korup
    }
    
    return { success: false, resis: [], scenario: 'Gagal Engine 3 (Teks Terlalu Hancur)' };
};

module.exports = { extractResiEngine3 };
