#!/bin/bash
# ═══════════════════════════════════════════════════════
# setup.sh — تثبيت SPAN Rescue تلقائياً
# شغّل هذا السكريبت في مجلد المشروع
# ═══════════════════════════════════════════════════════

echo "🚀 SPAN Rescue — بدء التثبيت..."

# ─── إنشاء مجلدات assets ─────────────────────────────
echo "📁 إنشاء مجلدات assets..."
mkdir -p assets/fonts
mkdir -p assets/sounds
mkdir -p assets/icons
mkdir -p assets/map_tiles

# ─── تحميل الخطوط من Google Fonts ───────────────────
echo "🔤 تحميل الخطوط..."

# Rajdhani
curl -L "https://fonts.gstatic.com/s/rajdhani/v10/LDI2apCSOBg7S-QT7pasEcOsc-bGkqIw.woff2" -o /tmp/rajdhani.zip 2>/dev/null || true

# SpaceMono
curl -L "https://fonts.gstatic.com/s/spacemono/v13/i7dPIFZifjKcF5UAWdDRYEF8RQ.woff2" -o /tmp/spacemono.zip 2>/dev/null || true

echo "⚠️  حمّل الخطوط يدوياً من:"
echo "   https://fonts.google.com/specimen/Rajdhani"
echo "   https://fonts.google.com/specimen/Space+Mono"
echo "   وضعها في: assets/fonts/"
echo ""

# ─── إنشاء ملفات صوت بديلة فارغة ────────────────────
echo "🔊 إنشاء ملفات صوت مؤقتة..."
# سيتم استبدالها بملفات حقيقية
dd if=/dev/zero bs=1 count=100 2>/dev/null | \
  base64 > assets/sounds/sos_alarm.mp3 2>/dev/null || \
  touch assets/sounds/sos_alarm.mp3
touch assets/sounds/message_received.mp3

# ─── تحميل المكتبات ───────────────────────────────────
echo "📦 flutter pub get..."
flutter pub get

# ─── بناء APK ─────────────────────────────────────────
echo "🔨 بناء APK..."
echo "لتشغيل على جهاز متصل: flutter run"
echo "لبناء APK: flutter build apk --release"

echo ""
echo "✅ التثبيت اكتمل!"
echo ""
echo "📋 الخطوات التالية:"
echo "1. ضع ملفات الخطوط في assets/fonts/"
echo "2. شغّل: flutter pub get"
echo "3. شغّل: flutter run"
