# GeoTrace — Spesifikasi Arsitektur Online & Efisiensi Storage

Dokumen ini merangkum arsitektur sistem **GeoTrace**, aplikasi *travel history* dan *social timeline* untuk grup kecil (~10 teman dekat) menggunakan **Flutter** dan **Supabase**.

---

## 1. Ringkasan Sistem & Tech Stack

| Komponen | Pilihan | Catatan |
| :--- | :--- | :--- |
| **Frontend** | Flutter (Android & iOS) | Diuji via Android Emulator & iOS sideloading (macOS 13 Ventura) |
| **Backend & Database** | Supabase (PostgreSQL + Storage + Auth) | Skema minimalis 5 tabel dengan Row Level Security (RLS) |
| **Model Koneksi** | Online-first + *Disk Caching* | Sinkronisasi *real-time* antar teman dengan *cache* lokal di HP |
| **Target Pengguna** | ~10 pengguna (grup teman dekat) | Fokus privat, ringan, dan bebas biaya server (*free tier*) |

---

## 2. Alur Koneksi (Online & Cache Lokal)

Karena tujuan utama GeoTrace adalah bertukar *timeline* perjalanan antar pengguna, sistem utamanya berjalan secara **online**:

1. **Sinkronisasi Timeline:** Data lokasi, catatan perjalanan, dan foto yang di-*upload* disimpan di server Supabase agar langsung bisa dilihat oleh anggota grup lainnya.
2. **Disk Caching di Perangkat:** Foto dan *feed* yang sudah pernah dimuat disimpan sementara di penyimpanan lokal HP. Saat membuka ulang *timeline* atau berada di area dengan sinyal lemah, aplikasi membaca dari *cache* tanpa mengunduh ulang dari server.
3. **Opsi Pengembangan (Offline Queue):** Jika dibutuhkan saat traveling di area tanpa sinyal sama sekali, aplikasi dapat ditambahkan antrean lokal (*offline-first queue*) untuk menyimpan *draft* catatan dan foto di HP terlebih dahulu, lalu otomatis melakukan *sync* ke Supabase saat koneksi internet kembali tersedia.

---

## 3. Batas Kuota Supabase Free Tier

Berdasarkan [Supabase Pricing](https://supabase.com/pricing) dan dokumentasi [Bandwidth & Storage Egress Supabase](https://supabase.com/docs/guides/storage/serving/bandwidth), batas paket gratis per proyek meliputi:

| Sumber Daya | Batas Free Tier | Kecukupan untuk ~10 Pengguna |
| :--- | :--- | :--- |
| **Database Size** | 500 MB | Sangat cukup; data teks, koordinat GPS, dan relasi hanya memakan ukuran kecil. |
| **File Storage** | 1 GB | Cukup untuk ribuan foto apabila dikompresi sebelum *upload*. |
| **Uncached Egress** | 5 GB / bulan | Aman selama pengambilan data difilter dan tidak *fetch* ulang berulang kali. |
| **Cached Egress** | 5 GB / bulan | Terbantu oleh *disk caching* di sisi aplikasi Flutter. |
| **Upload Maksimal** | 50 MB / file | Jauh di atas ukuran foto terkompresi. |

> **Catatan Operasional:** Proyek pada paket gratis Supabase akan di-*pause* otomatis jika tidak ada aktivitas database selama 7 hari berturut-turut, namun data tetap aman dan dapat diaktifkan kembali melalui dashboard Supabase.

---

## 4. Strategi Penghematan Storage & Egress

### A. Di Sisi Server (Supabase Storage & Database)
* **Kompresi Client-Side:** Foto dari galeri atau kamera dikompresi di HP terlebih dahulu sebelum di-*upload* (misalnya resolusi maksimal lebar `1080px`, format **WebP** atau **JPEG** kualitas ~75–80%). Ukuran file turun dari 3–5 MB menjadi sekitar 100–250 KB per foto.
* **Pembatasan Media per Check-in:** Batasi jumlah foto per *post* atau *check-in* (misalnya maksimal 3–5 foto) dan hindari penyimpanan file video di *free tier*.
* **Query Efisien:** Ambil hanya kolom yang dibutuhkan di *timeline* (*pagination* per 10–15 *post*) agar tidak memboroskan kuota *egress*.

### B. Di Sisi HP (Penyimpanan Lokal)
* **Tanpa Duplikasi Galeri:** Aplikasi tidak perlu menyalin foto mentah dari galeri ke folder terpisah secara permanen.
* **Batas Disk Cache (LRU):** Batasi ukuran *cache* gambar lokal (misalnya maksimal **100–200 MB**). Jika penuh, *cache* terlama otomatis dihapus tanpa mengganggu foto yang tersimpan di server.

### C. Kontrol Anti-Spam & Keamanan
* **RLS Cooldowns:** Terapkan aturan Row Level Security (RLS) dan batasan jeda waktu (*cooldown*) antar *upload*/*check-in* untuk mencegah *flood* request maupun pembengkakan *storage* secara tidak sengaja.

---

## 5. Checklist Implementasi

- [ ] Siapkan proyek Supabase dan aktifkan RLS pada seluruh 5 tabel inti.
- [ ] Tambahkan *package* kompresi gambar di Flutter sebelum proses *upload* ke Supabase Storage.
- [ ] Gunakan widget/library *cached network image* dengan batas ukuran *cache* lokal (100–200 MB).
- [ ] Terapkan *pagination* pada *timeline* agar beban *egress* tetap rendah.
- [ ] *(Opsional)* Tambahkan antrean lokal untuk menyimpan *check-in* saat perangkat sedang *offline*.
