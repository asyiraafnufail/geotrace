# GeoTrace — Travel History & Social Timeline

Aplikasi *travel history* dan *social timeline* untuk grup teman dekat berbasis **Flutter** dan **Supabase**, dirancang optimal untuk efisiensi batas kuota **Supabase Free Tier**.

---

## 🌟 Fitur Utama & Efisiensi Storage

1. **Client-Side Image Compression** (`lib/core/storage/image_compression_service.dart`):
   - Foto otomatis di-*resize* ke resolusi maksimal lebar `1080px`.
   - Format WebP/JPEG kualitas ~78% tanpa metadata EXIF berlebih.
   - Ukuran foto terpangkas dari **3–6 MB** menjadi **100–250 KB** (menghemat ~90% storage Supabase).
   - Maksimal 5 foto per check-in.

2. **Disk Caching (LRU) di Perangkat** (`lib/core/storage/custom_cache_manager.dart`):
   - Cache lokal dibatasi kapasitasnya (~150 MB / 250 objek) dengan metode LRU (*Least Recently Used*).
   - Mengurangi penggunaan kuota **Uncached/Cached Egress** Supabase saat pengguna membuka feed berulang kali.

3. **Query Egress Terkontrol (Pagination)**:
   - Feed dimuat secara bertahap (15 check-in per halaman).

4. **Peta Jejak Perjalanan (Interactive Map)**:
   - Visualisasi rute dan titik check-in menggunakan OpenStreetMap (`flutter_map`) tanpa biaya API pihak ketiga.

5. **Privasi & Keamanan Ketat**:
   - Skema 5 tabel inti dengan **Row Level Security (RLS)** penuh di Supabase.

---

## 🚀 Panduan Setup & Menjalankan Aplikasi

### 1. Eksekusi Skrip Database di Supabase
1. Buka dashboard proyek Supabase Anda.
2. Masuk ke menu **SQL Editor**.
3. Buka file [`supabase/schema.sql`](supabase/schema.sql), salin seluruh isinya, dan jalankan (Run).
   - Ini akan membuat 5 tabel (`profiles`, `trips`, `check_ins`, `check_in_photos`, `interactions`), RLS policies, trigger signup profil, dan bucket storage `checkin-photos`.

### 2. Konfigurasi Kredensial Supabase
Buka file [`lib/core/constants/supabase_constants.dart`](lib/core/constants/supabase_constants.dart):
```dart
static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 3. Jalankan Aplikasi
Di terminal:
```bash
# Masuk ke direktori
cd /Users/asyiraaf/Documents/Ngoding/geotrace

# Jalankan di Android Emulator atau iOS Simulator / Device
flutter run
```

---

## 📁 Struktur Folder Proyek

```
geotrace/
├── android/                   # Konfigurasi izin GPS, Kamera & Media Android
├── ios/                       # Konfigurasi NSLocation, NSCamera & NSPhotoLibrary iOS
├── supabase/
│   └── schema.sql             # Skrip DDL 5 tabel, RLS, Storage Bucket Policy
├── lib/
│   ├── main.dart              # Entrypoint, Supabase Init, Auth Gate
│   ├── core/
│   │   ├── constants/         # Supabase URL, Bucket Name, Limits
│   │   ├── storage/           # Kompresi foto & LRU Custom Cache Manager
│   │   └── widgets/           # Cached Network Image wrapper
│   ├── data/
│   │   ├── models/            # Profile, Trip, CheckIn, Photo, Interaction
│   │   └── repositories/      # Query Supabase, Upload, & Pagination
│   └── features/
│       ├── auth/              # Halaman Login & Sign Up
│       ├── timeline/          # Feed check-in + Interaksi (Suka/Keren/Seru)
│       ├── checkin/           # Form Check-in + Auto GPS + Preview Kompresi Foto
│       └── map/               # OpenStreetMap Jejak Rute Perjalanan
```
