#!/bin/bash
set -e

echo "🚀 [1/3] Memulai build iOS Release (tanpa code-signing)..."
flutter build ios --release --no-codesign

echo "📦 [2/3] Mengemas Runner.app menjadi format Payload (.ipa)..."
OUTPUT_DIR="build/sideload"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Payload"

cp -R "build/ios/iphoneos/Runner.app" "$OUTPUT_DIR/Payload/"

cd "$OUTPUT_DIR"
zip -qry "GeoTrace.ipa" Payload
cd - > /dev/null

echo "✅ [3/3] Selesai! File .ipa untuk sideload berhasil dibuat di:"
echo "👉 $(pwd)/build/sideload/GeoTrace.ipa"
echo ""
echo "📱 Cara Install ke iPhone:"
echo "1. Buka Sideloadly di Mac."
echo "2. Drag file 'build/sideload/GeoTrace.ipa' ke Sideloadly."
echo "3. Masukkan Apple ID Anda, lalu klik Start!"
