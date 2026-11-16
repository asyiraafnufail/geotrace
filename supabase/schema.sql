-- ==============================================================================
-- GeoTrace Database Schema (Supabase / PostgreSQL)
-- Spesifikasi: 5 Tabel Inti, RLS Penuh, dan Storage Policy
-- Target: ~10 Pengguna (Grup Teman Dekat), Hemat Storage & Egress Supabase Free Tier
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 2. TABEL 1: PROFILES (Data Pengguna & Teman)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Index untuk username lookup
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- ==============================================================================
-- 3. TABEL 2: TRIPS (Perjalanan / Kategori Timeline)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    start_date DATE,
    end_date DATE,
    cover_image_url TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_trips_user_id ON public.trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_created_at ON public.trips(created_at DESC);

-- ==============================================================================
-- 4. TABEL 3: CHECK_INS (Titik Lokasi & Catatan Timeline)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.check_ins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    note TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location_name TEXT,
    checked_in_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_check_ins_user_id ON public.check_ins(user_id);
CREATE INDEX IF NOT EXISTS idx_check_ins_trip_id ON public.check_ins(trip_id);
CREATE INDEX IF NOT EXISTS idx_check_ins_checked_in_at ON public.check_ins(checked_in_at DESC);

-- ==============================================================================
-- 5. TABEL 4: CHECK_IN_PHOTOS (Foto Terkompresi, Maks 3-5 Foto per Check-in)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.check_in_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_in_id UUID NOT NULL REFERENCES public.check_ins(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    photo_url TEXT NOT NULL,
    width INT,
    height INT,
    file_size_kb INT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_check_in_photos_check_in_id ON public.check_in_photos(check_in_id);

-- ==============================================================================
-- 6. TABEL 5: INTERACTIONS (Reaksi & Komentar Timeline)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_in_id UUID NOT NULL REFERENCES public.check_ins(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reaction_type TEXT DEFAULT 'like' NOT NULL, -- 'like', 'love', 'fire', 'comment'
    content TEXT, -- diisi jika jenis interaksi adalah komentar teks singkat
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_interactions_check_in_id ON public.interactions(check_in_id);

-- ==============================================================================
-- 7. TRIGGER: AUTO CREATE PROFILE SAAT USER SIGNUP
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, display_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- Aktifkan RLS pada seluruh 5 tabel
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_in_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interactions ENABLE ROW LEVEL SECURITY;

-- Policy Profiles
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON public.profiles;
CREATE POLICY "Authenticated users can view profiles"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

-- Policy Trips
DROP POLICY IF EXISTS "Authenticated users can view trips" ON public.trips;
CREATE POLICY "Authenticated users can view trips"
    ON public.trips FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can insert their own trips" ON public.trips;
CREATE POLICY "Users can insert their own trips"
    ON public.trips FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own trips" ON public.trips;
CREATE POLICY "Users can update their own trips"
    ON public.trips FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own trips" ON public.trips;
CREATE POLICY "Users can delete their own trips"
    ON public.trips FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Policy Check-ins
DROP POLICY IF EXISTS "Authenticated users can view check_ins" ON public.check_ins;
CREATE POLICY "Authenticated users can view check_ins"
    ON public.check_ins FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can insert their own check_ins" ON public.check_ins;
CREATE POLICY "Users can insert their own check_ins"
    ON public.check_ins FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own check_ins" ON public.check_ins;
CREATE POLICY "Users can update their own check_ins"
    ON public.check_ins FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own check_ins" ON public.check_ins;
CREATE POLICY "Users can delete their own check_ins"
    ON public.check_ins FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Policy Check-in Photos
DROP POLICY IF EXISTS "Authenticated users can view check_in_photos" ON public.check_in_photos;
CREATE POLICY "Authenticated users can view check_in_photos"
    ON public.check_in_photos FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can insert their own photos" ON public.check_in_photos;
CREATE POLICY "Users can insert their own photos"
    ON public.check_in_photos FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own photos" ON public.check_in_photos;
CREATE POLICY "Users can delete their own photos"
    ON public.check_in_photos FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Policy Interactions
DROP POLICY IF EXISTS "Authenticated users can view interactions" ON public.interactions;
CREATE POLICY "Authenticated users can view interactions"
    ON public.interactions FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can insert their own interactions" ON public.interactions;
CREATE POLICY "Users can insert their own interactions"
    ON public.interactions FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own interactions" ON public.interactions;
CREATE POLICY "Users can delete their own interactions"
    ON public.interactions FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- ==============================================================================
-- 9. SUPABASE STORAGE BUCKET & POLICIES (checkin-photos)
-- ==============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'checkin-photos',
    'checkin-photos',
    true,
    524288, -- Maks 512 KB per file (mencegah upload foto mentah tanpa kompresi)
    ARRAY['image/jpeg', 'image/webp', 'image/png']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 524288,
    allowed_mime_types = ARRAY['image/jpeg', 'image/webp', 'image/png'];

-- Policy Akses Storage: Izinkan pembacaan gambar publik untuk cached network image di aplikasi
DROP POLICY IF EXISTS "Public Read Authenticated for checkin-photos" ON storage.objects;
DROP POLICY IF EXISTS "Public read for checkin-photos" ON storage.objects;
CREATE POLICY "Public read for checkin-photos"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'checkin-photos');

-- Policy Upload Storage: User hanya bisa upload ke folder dengan nama auth.uid mereka
DROP POLICY IF EXISTS "Users upload to own folder in checkin-photos" ON storage.objects;
CREATE POLICY "Users upload to own folder in checkin-photos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'checkin-photos' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Policy Hapus Storage: User hanya bisa hapus foto miliknya
DROP POLICY IF EXISTS "Users delete own photos in checkin-photos" ON storage.objects;
CREATE POLICY "Users delete own photos in checkin-photos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'checkin-photos' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );
