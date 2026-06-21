-- ============================================================
-- TAHAP 2: Implementasi Fisik Database (DDL + DML)
-- Login aplikasi (Form_InputTelur.java): sa / admin1234
-- ============================================================
-- Raditya Rafa Pratama (255150207111020)
-- Ahmad Rayhan Ardhani Putra (255150207111027)
-- Muhammad Taufiqul Hafizh (255150207111017)
-- Rifqi Fadhil Abrar (255150200111015)
-- Tubagus Arya Yusuf Shauma (255150200111012)
-- ==========================================
-- 1. SETUP DATABASE (DROP IF EXISTS -> CREATE)
--    Idempotent: bisa dijalankan ulang tanpa error
USE master;
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SIM_FARM_BTN')
BEGIN
    ALTER DATABASE SIM_FARM_BTN SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SIM_FARM_BTN;
END
GO

CREATE DATABASE SIM_FARM_BTN;
GO
USE SIM_FARM_BTN;
GO

-- 2. CREATE TABLE (DDL)

-- Tabel: Farm
-- Master data 5 lokasi farm milik Berkah Telur Nusantara.
-- UNIQUE pada nama_farm supaya tidak ada nama farm duplikat.
CREATE TABLE Farm (
    farm_id INT IDENTITY(1,1) PRIMARY KEY,   -- PK auto-increment
    nama_farm VARCHAR(100) NOT NULL UNIQUE,    -- UNIQUE: cegah nama farm ganda
    lokasi VARCHAR(100) NOT NULL
);
GO

-- Tabel: Kandang
-- Setiap farm punya beberapa kandang. tipe_kandang default
-- 'Baterai' karena itu tipe paling umum dipakai BTN.
CREATE TABLE Kandang (
    kandang_id INT IDENTITY(1,1) PRIMARY KEY,
    farm_id INT NOT NULL, -- FK ke Farm
    nama_kandang VARCHAR(50) NOT NULL,
    kapasitas INT CHECK (kapasitas > 0), -- CHECK: kapasitas wajib positif
    tipe_kandang VARCHAR(50) DEFAULT 'Baterai' -- DEFAULT: tipe paling umum
        CHECK (tipe_kandang IN ('Baterai', 'Lantai', 'Koloni')),
    CONSTRAINT uq_kandang_per_farm UNIQUE (farm_id, nama_kandang), -- UNIQUE: nama kandang tidak boleh duplikat dalam 1 farm
    FOREIGN KEY (farm_id) REFERENCES Farm(farm_id)
);
GO

-- Tabel: Batch
-- Periode ternak per kandang. Satu kandang bisa punya beberapa
-- batch sepanjang waktu (gantian setiap ±18 bulan/afkir).
CREATE TABLE Batch (
    batch_id INT IDENTITY(1,1) PRIMARY KEY,
    kandang_id INT NOT NULL, -- FK ke Kandang
    tanggal_mulai DATE NOT NULL DEFAULT GETDATE(), -- DEFAULT: tanggal hari ini jika tidak diisi
    tanggal_selesai DATE NULL, -- NULL = batch masih aktif/berjalan
    jumlah_awal INT CHECK (jumlah_awal >= 0), -- CHECK: tidak boleh negatif
    jumlah_sekarang INT CHECK (jumlah_sekarang >= 0), -- CHECK: tidak boleh negatif (dijaga juga oleh trigger Tahap 3)
    FOREIGN KEY (kandang_id) REFERENCES Kandang(kandang_id)
);
GO

-- Tabel: Karyawan
-- Implementasi EERD: satu tabel dengan kolom peran_karyawan
-- sebagai diskriminator (Manajer/Mandor/Pekerja/Dokter Hewan).
-- UNIQUE pada no_hp supaya tidak ada nomor HP ganda.
CREATE TABLE Karyawan (
    karyawan_id INT IDENTITY(1,1) PRIMARY KEY,
    nama_karyawan VARCHAR(100) NOT NULL,
    no_hp VARCHAR(20) UNIQUE, -- UNIQUE: 1 nomor HP = 1 karyawan
    peran_karyawan VARCHAR(50) NOT NULL
        CHECK (peran_karyawan IN ('Manajer', 'Mandor', 'Pekerja', 'Dokter Hewan')), -- CHECK: batasi ke 4 peran valid
    farm_id INT NOT NULL, -- FK ke Farm (farm tempat bertugas)
    FOREIGN KEY (farm_id) REFERENCES Farm(farm_id)
);
GO

-- Tabel: Supplier
-- Vendor pemasok pakan dan obat/vaksin.
-- UNIQUE pada nama_supplier supaya tidak ada vendor tercatat dobel.
CREATE TABLE Supplier (
    supplier_id INT IDENTITY(1,1) PRIMARY KEY,
    nama_supplier VARCHAR(100) NOT NULL UNIQUE, -- UNIQUE: cegah supplier ganda
    alamat VARCHAR(200),
    telepon VARCHAR(20)
);
GO

-- Tabel: Pakan
-- Master jenis pakan + stok global (dikelola terpusat oleh BTN).
CREATE TABLE Pakan (
    pakan_id INT IDENTITY(1,1) PRIMARY KEY,
    supplier_id INT, -- FK ke Supplier
    nama_pakan VARCHAR(100) NOT NULL,
    jenis VARCHAR(50)
        CHECK (jenis IN ('Starter', 'Grower', 'Layer', 'Layer Plus')), -- CHECK: batasi kategori jenis pakan
    stok INT CHECK (stok >= 0) DEFAULT 0, -- CHECK + DEFAULT: stok tidak boleh negatif, mulai dari 0
    FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id)
);
GO

-- Tabel: Obat_Vaksin
-- Master obat, vaksin, vitamin, dan desinfektan.
CREATE TABLE Obat_Vaksin (
    obat_id INT IDENTITY(1,1) PRIMARY KEY,
    supplier_id INT, -- FK ke Supplier
    nama_obat VARCHAR(100) NOT NULL,
    jenis VARCHAR(50)
        CHECK (jenis IN ('Vaksin', 'Obat', 'Vitamin', 'Desinfektan')), -- CHECK: batasi kategori
    stok INT CHECK (stok >= 0) DEFAULT 0, -- CHECK + DEFAULT
    FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id)
);
GO

-- Tabel: Feeding
-- Transaksi konsumsi pakan harian per batch.
-- Trigger trg_KurangiStokPakan (Tahap 3) otomatis kurangi
-- Pakan.stok setiap kali ada INSERT di tabel ini.
CREATE TABLE Feeding (
    feeding_id INT IDENTITY(1,1) PRIMARY KEY,
    tanggal DATE NOT NULL DEFAULT GETDATE(), -- DEFAULT: tanggal hari ini
    batch_id INT NOT NULL, -- FK ke Batch
    pakan_id INT NOT NULL, -- FK ke Pakan
    jumlah_kg DECIMAL(10,2) CHECK (jumlah_kg > 0), -- CHECK: jumlah pakan wajib positif
    FOREIGN KEY (batch_id) REFERENCES Batch(batch_id),
    FOREIGN KEY (pakan_id) REFERENCES Pakan(pakan_id)
);
GO

-- Tabel: Panen_Telur
-- Transaksi panen telur harian, dipecah per grade (A/B/C/Afkir).
-- Kolom & relasi disamakan dengan query di Form_InputTelur.java
-- (loadPanenData, addPanen, BtnuUpdateActionPerformed).
CREATE TABLE Panen_Telur (
    panen_id INT IDENTITY(1,1) PRIMARY KEY,
    panen_tanggal DATE NOT NULL DEFAULT GETDATE(), -- DEFAULT: tanggal hari ini
    batch_id INT NOT NULL, -- FK ke Batch
    grade_telur VARCHAR(20)
        CHECK (grade_telur IN ('A','B','C','Pecah/Afkir')), -- CHECK: batasi ke 4 grade valid
    jumlah_butir INT CHECK (jumlah_butir >= 0), -- CHECK: tidak boleh negatif
    berat_kg DECIMAL(10,2) CHECK (berat_kg >= 0), -- CHECK: tidak boleh negatif
    karyawan_id INT NOT NULL, -- FK ke Karyawan (mandor pencatat)
    FOREIGN KEY (batch_id) REFERENCES Batch(batch_id),
    FOREIGN KEY (karyawan_id) REFERENCES Karyawan(karyawan_id)
);
GO

-- Tabel: Mortality
-- Pencatatan kematian ayam harian per batch.
-- Trigger trg_KurangiPopulasi (Tahap 3) otomatis kurangi
-- Batch.jumlah_sekarang setiap kali ada INSERT di tabel ini.
CREATE TABLE Mortality (
    mortality_id INT IDENTITY(1,1) PRIMARY KEY,
    tanggal DATE NOT NULL DEFAULT GETDATE(),
    batch_id INT NOT NULL, -- FK ke Batch
    jumlah_mati INT CHECK (jumlah_mati >= 0), -- CHECK: tidak boleh negatif
    penyebab VARCHAR(100)
        CHECK (penyebab IN ('Sakit', 'Kanibalisme', 'Tidak Diketahui', 'Afkir')), -- CHECK: batasi 4 penyebab valid
    FOREIGN KEY (batch_id) REFERENCES Batch(batch_id)
);
GO

-- Tabel: Vaksinasi
-- Pencatatan tindakan medis (vaksin/obat) per batch.
-- dokter_id merujuk ke Karyawan dengan peran 'Dokter Hewan'.
CREATE TABLE Vaksinasi (
    vaksinasi_id INT IDENTITY(1,1) PRIMARY KEY,
    tanggal DATE NOT NULL DEFAULT GETDATE(),
    batch_id INT NOT NULL, -- FK ke Batch
    obat_id INT NOT NULL, -- FK ke Obat_Vaksin
    dosis VARCHAR(50),
    dokter_id INT, -- FK ke Karyawan (dokter hewan)
    FOREIGN KEY (batch_id) REFERENCES Batch(batch_id),
    FOREIGN KEY (obat_id) REFERENCES Obat_Vaksin(obat_id),
    FOREIGN KEY (dokter_id) REFERENCES Karyawan(karyawan_id)
);
GO

-- Tabel: Customer
-- Pembeli telur: Supermarket, Agen/Pasar, atau Pabrik Roti.
CREATE TABLE Customer (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    nama_customer VARCHAR(100) NOT NULL,
    jenis_customer VARCHAR(50)
        CHECK (jenis_customer IN ('Supermarket', 'Agen/Pasar', 'Pabrik Roti')), -- CHECK: batasi 3 jenis
    alamat VARCHAR(200)
);
GO

-- Tabel: Penjualan
-- Transaksi penjualan telur ke customer, per farm.
CREATE TABLE Penjualan (
    penjualan_id INT IDENTITY(1,1) PRIMARY KEY,
    tanggal DATE NOT NULL DEFAULT GETDATE(),
    farm_id INT NOT NULL,                                  -- FK ke Farm (asal telur dijual)
    customer_id INT NOT NULL,                                  -- FK ke Customer
    total_harga DECIMAL(15,2) CHECK (total_harga >= 0),         -- CHECK: tidak boleh negatif
    FOREIGN KEY (farm_id) REFERENCES Farm(farm_id),
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
);
GO

-- Tabel: Detail_Penjualan
-- Rincian per grade telur dalam satu transaksi penjualan.
CREATE TABLE Detail_Penjualan (
    detail_id INT IDENTITY(1,1) PRIMARY KEY,
    penjualan_id INT NOT NULL,                                  -- FK ke Penjualan
    grade_telur VARCHAR(20)
        CHECK (grade_telur IN ('A','B','C','Pecah/Afkir')),     -- CHECK: konsisten dgn grade di Panen_Telur
    jumlah INT CHECK (jumlah >= 0),                        -- CHECK: tidak boleh negatif
    harga_satuan DECIMAL(10,2) CHECK (harga_satuan >= 0),        -- CHECK: tidak boleh negatif
    FOREIGN KEY (penjualan_id) REFERENCES Penjualan(penjualan_id)
);
GO

-- 3. ALTER TABLE
--    Ditambahkan setelah CREATE supaya sesuai rubrik Tahap 2
--    poin 1 ("CREATE DATABASE, CREATE TABLE, ALTER TABLE").
--    Perubahan dipilih agar tetap aman bagi Trigger/Function/Java.

-- Tambah kolom keterangan opsional di Mortality untuk catatan detail
-- (tidak dipakai trigger/Java manapun, jadi aman ditambahkan)
ALTER TABLE Mortality
ADD keterangan VARCHAR(255) NULL;
GO

-- Tambah DEFAULT pada Obat_Vaksin.jenis supaya konsisten dengan Pakan.jenis
-- yang juga punya constraint kategori (dilakukan lewat ALTER karena
-- constraint CHECK sudah dibuat saat CREATE TABLE)
ALTER TABLE Penjualan
ADD CONSTRAINT df_penjualan_total DEFAULT 0 FOR total_harga;
GO

-- Tambah CHECK tambahan: tanggal_selesai batch tidak boleh sebelum tanggal_mulai
-- (ditambahkan lewat ALTER untuk menunjukkan constraint bisa disisipkan
-- belakangan tanpa harus DROP TABLE)
ALTER TABLE Batch
ADD CONSTRAINT chk_batch_tanggal CHECK (tanggal_selesai IS NULL OR tanggal_selesai > tanggal_mulai);
GO

-- 4. TRIGGERS & FUNCTIONS (Tahap 3)
--    Tetap disertakan di sini supaya 1 file ini lengkap
--    dan bisa dijalankan dari awal sampai akhir tanpa error.

-- Trigger: setiap ada INSERT di Mortality, otomatis kurangi
-- populasi (jumlah_sekarang) di tabel Batch terkait.
CREATE TRIGGER trg_KurangiPopulasi
ON Mortality
AFTER INSERT
AS
BEGIN
    UPDATE b
    SET b.jumlah_sekarang = b.jumlah_sekarang - i.jumlah_mati
    FROM Batch b
    INNER JOIN inserted i ON b.batch_id = i.batch_id;
END;
GO

-- Trigger: setiap ada INSERT di Feeding, otomatis kurangi
-- stok pakan di tabel Pakan terkait.
CREATE TRIGGER trg_KurangiStokPakan
ON Feeding
AFTER INSERT
AS
BEGIN
    UPDATE p
    SET p.stok = p.stok - i.jumlah_kg
    FROM Pakan p
    INNER JOIN inserted i ON p.pakan_id = i.pakan_id;
END;
GO

-- Function: hitung persentase mortality rate dari jumlah mati
-- dibanding populasi awal batch.
CREATE FUNCTION fn_MortalityRate
(
    @jumlah_mati INT,
    @populasi_awal INT
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    RETURN (@jumlah_mati * 100.0 / NULLIF(@populasi_awal, 0));
END;
GO

-- 4b. STORED PROCEDURE (Tahap 3)
--     Laporan kinerja farm pada rentang tanggal tertentu:
--     total telur, total pakan, total kematian per farm.
CREATE PROCEDURE sp_GetLaporanKinerjaFarm
    @tanggal_awal DATE,
    @tanggal_akhir DATE
AS
BEGIN
    SELECT
        f.nama_farm,
        SUM(pt.jumlah_butir)                                   AS total_telur_butir,
        SUM(pt.berat_kg)                                       AS total_telur_kg,
        ISNULL(fd.total_pakan_kg, 0)                            AS total_pakan_kg,
        ISNULL(mt.total_mati, 0)                                AS total_mati
    FROM Farm f
    JOIN Kandang k ON k.farm_id = f.farm_id
    JOIN Batch b ON b.kandang_id = k.kandang_id
    JOIN Panen_Telur pt ON pt.batch_id = b.batch_id
    AND pt.panen_tanggal BETWEEN @tanggal_awal AND @tanggal_akhir
    LEFT JOIN (
        SELECT b2.kandang_id, SUM(fe.jumlah_kg) AS total_pakan_kg
        FROM Feeding fe
        JOIN Batch b2 ON b2.batch_id = fe.batch_id
        WHERE fe.tanggal BETWEEN @tanggal_awal AND @tanggal_akhir
        GROUP BY b2.kandang_id
    ) fd ON fd.kandang_id = k.kandang_id
    LEFT JOIN (
        SELECT b3.kandang_id, SUM(m.jumlah_mati) AS total_mati
        FROM Mortality m
        JOIN Batch b3 ON b3.batch_id = m.batch_id
        WHERE m.tanggal BETWEEN @tanggal_awal AND @tanggal_akhir
        GROUP BY b3.kandang_id
    ) mt ON mt.kandang_id = k.kandang_id
    GROUP BY f.nama_farm, fd.total_pakan_kg, mt.total_mati
    ORDER BY total_telur_kg DESC;
END;
GO
-- Contoh pemanggilan:
-- EXEC sp_GetLaporanKinerjaFarm @tanggal_awal = '2026-06-17', @tanggal_akhir = '2026-06-19';

-- ==========================================
-- 5. DML — INSERT DUMMY DATA
--    Realistis, mencakup 5 farm, dan data 3 hari berturut
--    (referential integrity sudah diverifikasi: tidak ada
--    stok pakan / populasi batch yang jadi negatif setelah trigger)
-- ==========================================

-- 1. FARM (5 farm sesuai kasus bisnis BTN)
INSERT INTO Farm (nama_farm, lokasi) VALUES
('Farm Bogor', 'Jl. Raya Bogor KM 25'),
('Farm Bandung', 'Jl. Raya Bandung-Sumedang KM 10'),
('Farm Semarang', 'Jl. Raya Semarang-Ungaran KM 8'),
('Farm Yogyakarta', 'Jl. Raya Yogyakarta-Solo KM 12'),
('Farm Malang', 'Jl. Raya Malang-Batu KM 15');
GO

-- 2. KANDANG (11 kandang tersebar di 5 farm)
INSERT INTO Kandang (farm_id, nama_kandang, kapasitas, tipe_kandang) VALUES
(1, 'Kandang A-1', 5000, 'Baterai'), (1, 'Kandang A-2', 5000, 'Baterai'),
(2, 'Kandang B-1', 6000, 'Baterai'), (2, 'Kandang B-2', 6000, 'Lantai'),
(3, 'Kandang C-1', 5500, 'Baterai'), (3, 'Kandang C-2', 5500, 'Baterai'),
(4, 'Kandang D-1', 4500, 'Lantai'),   (4, 'Kandang D-2', 4500, 'Baterai'),
(5, 'Kandang E-1', 7000, 'Baterai'),  (5, 'Kandang E-2', 7000, 'Baterai'),
(5, 'Kandang E-3', 6500, 'Lantai');
GO

-- 3. KARYAWAN (20 karyawan: 5 manajer, 10 mandor, 3 pekerja, 2 dokter hewan)
INSERT INTO Karyawan (nama_karyawan, no_hp, peran_karyawan, farm_id) VALUES
('Ahmad Santoso', '081234567890', 'Manajer', 1),
('Budi Wijaya', '081234567891', 'Manajer', 2),
('Citra Dewi', '081234567892', 'Manajer', 3),
('Dedi Kurniawan', '081234567893', 'Manajer', 4),
('Eka Putri', '081234567894', 'Manajer', 5),
('Fajar Nugroho', '081234567895', 'Mandor', 1),
('Gunawan Pratama', '081234567896', 'Mandor', 1),
('Hendra Kusuma', '081234567897', 'Mandor', 2),
('Indra Wijaya', '081234567898', 'Mandor', 2),
('Joko Susilo', '081234567899', 'Mandor', 3),
('Kartika Sari', '081234567800', 'Mandor', 3),
('Lukman Hakim', '081234567801', 'Mandor', 4),
('Mohammad Rizki', '081234567802', 'Mandor', 4),
('Nurul Hidayah', '081234567803', 'Mandor', 5),
('Oki Saputra', '081234567804', 'Mandor', 5),
('Pekerja 1', '081234567805', 'Pekerja', 1),
('Pekerja 2', '081234567806', 'Pekerja', 2),
('Pekerja 3', '081234567807', 'Pekerja', 3),
('drh. Siti Aminah', '081234567808', 'Dokter Hewan', 1),
('drh. Bambang Sutrisno', '081234567809', 'Dokter Hewan', 3);
GO

-- 4. SUPPLIER
INSERT INTO Supplier (nama_supplier, alamat, telepon) VALUES
('PT Charoen Pokphand', 'Jakarta', '021-12345678'),
('PT Japfa Comfeed', 'Surabaya', '031-87654321'),
('PT Malindo Feedmill', 'Bandung', '022-11223344'),
('Toko Pakan Makmur', 'Semarang', '024-55667788');
GO

-- 5. PAKAN (stok dikelola terpusat per jenis pakan)
INSERT INTO Pakan (supplier_id, nama_pakan, jenis, stok) VALUES
(1, 'Pakan BR-1', 'Starter', 5000), (1, 'Pakan BR-2', 'Grower', 5500),
(2, 'Pakan 511', 'Layer', 8000),    (2, 'Pakan 512', 'Layer Plus', 6800),
(3, 'Pakan Super Layer', 'Layer', 5200), (4, 'Pakan Ekonomis', 'Layer', 4800);
GO

-- 6. OBAT/VAKSIN
INSERT INTO Obat_Vaksin (supplier_id, nama_obat, jenis, stok) VALUES
(1, 'Vaksin ND', 'Vaksin', 500), (1, 'Vaksin IB', 'Vaksin', 500),
(2, 'Vaksin Gumboro', 'Vaksin', 400), (3, 'Antibiotik Enrofloxacin', 'Obat', 250),
(3, 'Vitamin B-Complex', 'Vitamin', 1000), (4, 'Desinfektan', 'Desinfektan', 600);
GO

-- 7. BATCH (11 batch aktif, satu per kandang)
INSERT INTO Batch (kandang_id, tanggal_mulai, tanggal_selesai, jumlah_awal, jumlah_sekarang) VALUES
(1, '2025-01-15', NULL, 5000, 4850), (2, '2025-02-01', NULL, 5000, 4900),
(3, '2025-01-20', NULL, 6000, 5800), (4, '2025-03-01', NULL, 6000, 5950),
(5, '2025-02-10', NULL, 5500, 5400), (6, '2025-01-25', NULL, 5500, 5350),
(7, '2025-03-15', NULL, 4500, 4450), (8, '2025-02-20', NULL, 4500, 4400),
(9, '2025-01-10', NULL, 7000, 6800), (10, '2025-02-05', NULL, 7000, 6900),
(11, '2025-03-01', NULL, 6500, 6450);
GO

-- 8. FEEDING (data 3 hari terakhir: 17, 18, 19 Juni 2026)
-- Trigger trg_KurangiStokPakan otomatis kurangi stok Pakan saat insert ini
INSERT INTO Feeding (tanggal, batch_id, pakan_id, jumlah_kg) VALUES
('2026-06-17', 1, 2, 250), ('2026-06-17', 2, 2, 250), ('2026-06-17', 3, 3, 300),
('2026-06-17', 4, 3, 300), ('2026-06-17', 5, 4, 275), ('2026-06-17', 6, 4, 270),
('2026-06-17', 7, 5, 220), ('2026-06-17', 8, 5, 215), ('2026-06-17', 9, 3, 350),
('2026-06-17', 10, 3, 345), ('2026-06-17', 11, 6, 320),
('2026-06-18', 1, 2, 250), ('2026-06-18', 2, 2, 250), ('2026-06-18', 3, 3, 300),
('2026-06-18', 4, 3, 300), ('2026-06-18', 5, 4, 275), ('2026-06-18', 6, 4, 270),
('2026-06-18', 7, 5, 220), ('2026-06-18', 8, 5, 215), ('2026-06-18', 9, 3, 350),
('2026-06-18', 10, 3, 345), ('2026-06-18', 11, 6, 320),
('2026-06-19', 1, 2, 250), ('2026-06-19', 2, 2, 250), ('2026-06-19', 3, 3, 300),
('2026-06-19', 4, 3, 300), ('2026-06-19', 5, 4, 275), ('2026-06-19', 6, 4, 270),
('2026-06-19', 7, 5, 220), ('2026-06-19', 8, 5, 215), ('2026-06-19', 9, 3, 350),
('2026-06-19', 10, 3, 345), ('2026-06-19', 11, 6, 320);
GO

-- 9. PANEN TELUR (data 3 hari terakhir, semua 11 batch, grade A/B/C/Afkir)
INSERT INTO Panen_Telur (panen_tanggal, batch_id, grade_telur, jumlah_butir, berat_kg, karyawan_id) VALUES
('2026-06-17', 1, 'A', 4100, 246.0, 6),  ('2026-06-17', 1, 'B', 480, 26.4, 6),
('2026-06-17', 2, 'A', 4150, 249.0, 6),  ('2026-06-17', 2, 'B', 470, 25.85, 6),
('2026-06-17', 3, 'A', 4750, 285.0, 8),  ('2026-06-17', 3, 'B', 550, 30.25, 8),
('2026-06-17', 4, 'A', 4800, 288.0, 9),  ('2026-06-17', 4, 'C', 200, 10.0, 9),
('2026-06-17', 5, 'A', 4300, 258.0, 10), ('2026-06-17', 5, 'B', 510, 28.05, 10),
('2026-06-17', 6, 'A', 4250, 255.0, 11), ('2026-06-17', 6, 'B', 500, 27.5, 11),
('2026-06-17', 7, 'A', 3600, 216.0, 12), ('2026-06-17', 7, 'B', 400, 22.0, 12),
('2026-06-17', 8, 'A', 3550, 213.0, 13), ('2026-06-17', 8, 'C', 150, 7.5, 13),
('2026-06-17', 9, 'A', 5600, 336.0, 14), ('2026-06-17', 9, 'B', 650, 35.75, 14),
('2026-06-17', 10, 'A', 5700, 342.0, 15),('2026-06-17', 10,'B', 660, 36.3, 15),
('2026-06-17', 11, 'A', 5200, 312.0, 11),('2026-06-17', 11,'B', 600, 33.0, 11),
('2026-06-18', 1, 'A', 4150, 249.0, 6),  ('2026-06-18', 1, 'B', 500, 27.5, 6),
('2026-06-18', 2, 'A', 4050, 243.0, 6),  ('2026-06-18', 2, 'C', 180, 9.0, 6),
('2026-06-18', 3, 'A', 4800, 288.0, 8),  ('2026-06-18', 3, 'B', 520, 28.6, 8),
('2026-06-18', 4, 'A', 4900, 294.0, 9),  ('2026-06-18', 4, 'B', 530, 29.15, 9),
('2026-06-18', 5, 'A', 4400, 264.0, 10), ('2026-06-18', 5, 'B', 490, 26.95, 10),
('2026-06-18', 6, 'A', 4350, 261.0, 11), ('2026-06-18', 6, 'C', 160, 8.0, 11),
('2026-06-18', 7, 'A', 3650, 219.0, 12), ('2026-06-18', 7, 'B', 410, 22.55, 12),
('2026-06-18', 8, 'A', 3600, 216.0, 13), ('2026-06-18', 8, 'B', 390, 21.45, 13),
('2026-06-18', 9, 'A', 5650, 339.0, 14), ('2026-06-18', 9, 'B', 670, 36.85, 14),
('2026-06-18', 10, 'A', 5750, 345.0, 15),('2026-06-18', 10,'C', 210, 10.5, 15),
('2026-06-18', 11, 'A', 5250, 315.0, 11),('2026-06-18', 11,'B', 610, 33.55, 11),
('2026-06-19', 1, 'A', 4200, 252.0, 6),  ('2026-06-19', 1, 'B', 500, 27.5, 6), ('2026-06-19', 1, 'C', 200, 10.0, 6),
('2026-06-19', 2, 'A', 4100, 246.0, 7),  ('2026-06-19', 2, 'B', 450, 24.75, 7),
('2026-06-19', 3, 'A', 4800, 288.0, 8),  ('2026-06-19', 3, 'B', 520, 28.6, 8), ('2026-06-19', 3, 'C', 180, 9.0, 8),
('2026-06-19', 4, 'A', 4950, 297.0, 9),  ('2026-06-19', 4, 'B', 540, 29.7, 9),
('2026-06-19', 5, 'A', 4450, 267.0, 10), ('2026-06-19', 5, 'B', 500, 27.5, 10),
('2026-06-19', 6, 'A', 4400, 264.0, 11), ('2026-06-19', 6, 'B', 480, 26.4, 11),
('2026-06-19', 7, 'A', 3700, 222.0, 12), ('2026-06-19', 7, 'C', 170, 8.5, 12),
('2026-06-19', 8, 'A', 3650, 219.0, 13), ('2026-06-19', 8, 'B', 400, 22.0, 13),
('2026-06-19', 9, 'A', 5700, 342.0, 14), ('2026-06-19', 9, 'B', 680, 37.4, 14),
('2026-06-19', 10, 'A', 5800, 348.0, 15),('2026-06-19', 10,'B', 650, 35.75, 15),
('2026-06-19', 11, 'A', 5300, 318.0, 11),('2026-06-19', 11,'B', 620, 34.1, 11);
GO

-- 10. MORTALITY (memicu trg_KurangiPopulasi otomatis saat insert)
INSERT INTO Mortality (tanggal, batch_id, jumlah_mati, penyebab, keterangan) VALUES
('2026-06-16', 1, 18, 'Sakit', 'Gejala awal ND, sudah dikarantina sebagian'),
('2026-06-17', 2, 10, 'Tidak Diketahui', NULL),
('2026-06-17', 5, 12, 'Kanibalisme', 'Sudah ditambah pencahayaan redup'),
('2026-06-18', 1, 15, 'Sakit', 'Lanjutan kasus ND, dokter sudah dipanggil'),
('2026-06-18', 3, 20, 'Sakit', 'Diduga keracunan pakan basi'),
('2026-06-18', 7, 8, 'Tidak Diketahui', NULL),
('2026-06-19', 9, 14, 'Sakit', 'Gejala flu burung ringan'),
('2026-06-19', 11, 6, 'Kanibalisme', NULL);
GO

-- 11. VAKSINASI (dokter_id = 19 atau 20, sesuai data Karyawan peran Dokter Hewan)
INSERT INTO Vaksinasi (tanggal, batch_id, obat_id, dosis, dokter_id) VALUES
('2026-06-01', 2, 5, '1 gram/liter air', 19),
('2026-06-10', 3, 2, '0.5 ml/ekor', 19),
('2026-06-12', 5, 3, '1 ml/ekor', 20),
('2026-06-15', 1, 1, '0.5 ml/ekor', 19),
('2026-06-16', 7, 1, '0.5 ml/ekor', 20),
('2026-06-17', 9, 4, '1 ml/10kg BB', 19);
GO

-- 12. CUSTOMER
INSERT INTO Customer (nama_customer, jenis_customer, alamat) VALUES
('Supermarket IndoMart', 'Supermarket', 'Jakarta'),
('Supermarket Giant', 'Supermarket', 'Bandung'),
('Pasar Johar', 'Agen/Pasar', 'Semarang'),
('Pasar Malioboro', 'Agen/Pasar', 'Yogyakarta'),
('PT Sari Roti', 'Pabrik Roti', 'Jakarta'),
('Toko Telur Sejahtera', 'Agen/Pasar', 'Malang');
GO

-- 13. PENJUALAN (mencakup 5 farm, 3 hari terakhir)
INSERT INTO Penjualan (tanggal, farm_id, customer_id, total_harga) VALUES
('2026-06-16', 5, 6, 8000000),
('2026-06-17', 3, 3, 10000000),
('2026-06-17', 4, 4, 9000000),
('2026-06-18', 1, 1, 15000000),
('2026-06-18', 2, 2, 12000000),
('2026-06-19', 1, 1, 11000000),
('2026-06-19', 5, 6, 9500000);
GO

-- 14. DETAIL PENJUALAN
INSERT INTO Detail_Penjualan (penjualan_id, grade_telur, jumlah, harga_satuan) VALUES
(1, 'A', 2200, 3500), (1, 'B', 300, 2500),
(2, 'A', 2000, 3500), (2, 'B', 600, 2500), (2, 'C', 300, 1500),
(3, 'A', 2000, 3500), (3, 'B', 600, 2500),
(4, 'A', 3000, 3500), (4, 'B', 500, 2500),
(5, 'A', 2500, 3500), (5, 'B', 400, 2500),
(6, 'A', 2400, 3500), (6, 'B', 450, 2500),
(7, 'A', 2300, 3500), (7, 'B', 420, 2500), (7, 'C', 250, 1500);
GO

-- 6. VERIFIKASI
PRINT '=== SUKSES! JUMLAH RECORD PER TABEL ===';
SELECT 'Farm' AS Tabel, COUNT(*) AS Jumlah FROM Farm UNION ALL
SELECT 'Kandang', COUNT(*) FROM Kandang UNION ALL
SELECT 'Karyawan', COUNT(*) FROM Karyawan UNION ALL
SELECT 'Supplier', COUNT(*) FROM Supplier UNION ALL
SELECT 'Batch', COUNT(*) FROM Batch UNION ALL
SELECT 'Pakan', COUNT(*) FROM Pakan UNION ALL
SELECT 'Obat_Vaksin', COUNT(*) FROM Obat_Vaksin UNION ALL
SELECT 'Panen_Telur', COUNT(*) FROM Panen_Telur UNION ALL
SELECT 'Feeding', COUNT(*) FROM Feeding UNION ALL
SELECT 'Mortality', COUNT(*) FROM Mortality UNION ALL
SELECT 'Vaksinasi', COUNT(*) FROM Vaksinasi UNION ALL
SELECT 'Customer', COUNT(*) FROM Customer UNION ALL
SELECT 'Penjualan', COUNT(*) FROM Penjualan UNION ALL
SELECT 'Detail_Penjualan', COUNT(*) FROM Detail_Penjualan;
GO

-- 7. TEST QUERY YANG DIPAKAI Form_InputTelur.java
--    Pastikan tetap kompatibel setelah ALTER TABLE di atas
SELECT p.panen_id, p.panen_tanggal, k.nama_kandang,
       p.grade_telur, p.jumlah_butir, p.berat_kg
FROM Panen_Telur p
JOIN Batch b ON p.batch_id = b.batch_id
JOIN Kandang k ON b.kandang_id = k.kandang_id
ORDER BY p.panen_tanggal DESC;
GO

SELECT kandang_id, nama_kandang FROM Kandang ORDER BY nama_kandang;
GO

SELECT karyawan_id, nama_karyawan FROM Karyawan WHERE peran_karyawan='Mandor' ORDER BY nama_karyawan;
GO

-- 8. QUERY KOMPLEKS (Tahap 3)
--    Minimal 3 query: JOIN + Subquery + Aggregation (GROUP BY/HAVING)

-- Query 1: Total produksi telur per farm per hari (JOIN + GROUP BY)
SELECT
    f.nama_farm,
    pt.panen_tanggal,
    SUM(pt.jumlah_butir) AS total_butir,
    SUM(pt.berat_kg)     AS total_berat_kg
FROM Panen_Telur pt
JOIN Batch b   ON pt.batch_id = b.batch_id
JOIN Kandang k ON b.kandang_id = k.kandang_id
JOIN Farm f    ON k.farm_id = f.farm_id
GROUP BY f.nama_farm, pt.panen_tanggal
ORDER BY pt.panen_tanggal DESC, total_berat_kg DESC;
GO

-- Query 2: Farm dengan rata-rata produksi telur (kg) di atas rata-rata
-- seluruh farm (JOIN + Subquery + HAVING)
SELECT
    f.nama_farm,
    AVG(pt.berat_kg) AS rata_rata_berat_per_panen
FROM Panen_Telur pt
JOIN Batch b   ON pt.batch_id = b.batch_id
JOIN Kandang k ON b.kandang_id = k.kandang_id
JOIN Farm f    ON k.farm_id = f.farm_id
GROUP BY f.nama_farm
HAVING AVG(pt.berat_kg) > (
    SELECT AVG(berat_kg) FROM Panen_Telur
)
ORDER BY rata_rata_berat_per_panen DESC;
GO

-- Query 3: Kandang dengan total kematian terbanyak beserta mortality rate
-- (JOIN + Subquery di kolom SELECT + UDF fn_MortalityRate)
SELECT
    k.nama_kandang,
    f.nama_farm,
    (SELECT SUM(m.jumlah_mati)
     FROM Mortality m
     WHERE m.batch_id = b.batch_id)                     AS total_mati,
    b.jumlah_awal,
    dbo.fn_MortalityRate(
        (SELECT SUM(m.jumlah_mati) FROM Mortality m WHERE m.batch_id = b.batch_id),
        b.jumlah_awal
    ) AS mortality_rate_persen
FROM Batch b
JOIN Kandang k ON b.kandang_id = k.kandang_id
JOIN Farm f    ON k.farm_id = f.farm_id
WHERE EXISTS (SELECT 1 FROM Mortality m WHERE m.batch_id = b.batch_id)
ORDER BY mortality_rate_persen DESC;
GO

-- 9. PIVOT (Tahap 3)
--    Rekap total telur (kg) per Farm (baris) per Tanggal (kolom)
--    Sesuai contoh format dashboard di panduan proyek.SELECT nama_farm,
       [2026-06-17] AS Tgl_17_Juni,
       [2026-06-18] AS Tgl_18_Juni,
       [2026-06-19] AS Tgl_19_Juni
FROM (
    SELECT
        f.nama_farm,
        pt.panen_tanggal,
        pt.berat_kg
    FROM Panen_Telur pt
    JOIN Batch b   ON pt.batch_id = b.batch_id
    JOIN Kandang k ON b.kandang_id = k.kandang_id
    JOIN Farm f    ON k.farm_id = f.farm_id
) AS src
PIVOT (
    SUM(berat_kg)
    FOR panen_tanggal IN ([2026-06-17], [2026-06-18], [2026-06-19])
) AS pvt
ORDER BY nama_farm;
GO
