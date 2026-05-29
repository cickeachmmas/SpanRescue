# SPAN Rescue — دليل التثبيت والتشغيل الكامل

---

## هيكل الملفات النهائي

```
span_rescue/
├── pubspec.yaml                              ✅
├── android/
│   ├── app/src/main/AndroidManifest.xml      ✅
│   └── app/src/main/kotlin/com/spanrescue/
│       ├── MainActivity.kt                   (تلقائي من Flutter)
│       └── MeshForegroundService.kt          ✅
│
└── lib/
    ├── main.dart                             ✅
    ├── theme/
    │   └── app_theme.dart                    ✅
    ├── models/
    │   ├── mesh_message.dart                 ✅
    │   ├── node_info.dart                    ✅
    │   └── group_info.dart                   ✅ (يحتوي BridgeConnection)
    ├── core/
    │   ├── geo_utils.dart                    ✅
    │   ├── mesh_router.dart                  ✅
    │   ├── mesh_service.dart                 ✅
    │   ├── wifi_direct_service.dart          ✅
    │   ├── bridge_manager.dart               ✅
    │   ├── store_forward_queue.dart          ✅
    │   ├── audio_service.dart                ✅
    │   ├── beacon_service.dart               ✅
    │   └── notification_service.dart         ✅
    ├── screens/
    │   ├── main_shell.dart                   ✅
    │   ├── mesh_map_screen.dart              ✅
    │   ├── chat_screen.dart                  ✅
    │   └── topology_and_logs.dart            ✅ (يحتوي الشاشتين)
    └── widgets/
        ├── map/
        │   ├── radar_overlay.dart            ✅
        │   ├── sos_button.dart               ✅
        │   └── nodes_directory_sheet.dart    ✅
        └── chat/
            └── chat_widgets.dart             ✅ (يحتوي كل widgets الـ Chat)
```

---

## خطوات التثبيت

### 1. إنشاء مشروع Flutter جديد

```bash
flutter create span_rescue
cd span_rescue
```

### 2. نسخ الملفات

انسخ كل الملفات من المجلدات المقابلة:
- `pubspec.yaml` → جذر المشروع
- `lib/` → كما هو
- `android/app/src/main/AndroidManifest.xml` → استبدل الموجود
- `android/app/src/main/kotlin/.../MeshForegroundService.kt` → أضف الملف

### 3. تحميل المكتبات

```bash
flutter pub get
```

### 4. تحميل الخطوط

حمّل من Google Fonts وضع في `assets/fonts/`:
- **Rajdhani**: Medium, SemiBold, Bold
- **SpaceMono**: Regular, Bold

```
https://fonts.google.com/specimen/Rajdhani
https://fonts.google.com/specimen/Space+Mono
```

### 5. إنشاء مجلدات Assets

```bash
mkdir -p assets/fonts
mkdir -p assets/sounds
mkdir -p assets/icons
mkdir -p assets/map_tiles
```

### 6. خرائط Offline

لتحميل خرائط المنطقة المطلوبة مسبقاً:

```bash
# تثبيت أداة تحميل الـ Tiles
pip install mobile-atlas-creator

# أو استخدم TileMill / QGIS لتصدير الـ Tiles
```

ضع الـ Tiles في: `assets/map_tiles/{z}/{x}/{y}.png`

### 7. أصوات التنبيه

ضع في `assets/sounds/`:
- `sos_alarm.mp3` — صوت تنبيه قوي
- `message_received.mp3` — صوت رسالة خفيف

---

## تشغيل التطبيق

```bash
# تشغيل على جهاز متصل
flutter run

# بناء APK للتثبيت المباشر
flutter build apk --release

# بناء APK مقسم (أصغر حجماً)
flutter build apk --split-per-abi
```

---

## اختبار الشبكة

### اختبار بسيط (جهازان):

1. ثبّت التطبيق على جهازين
2. افتح التطبيق على كلا الجهازين
3. انتظر 15-30 ثانية للـ Auto-Discovery
4. أرسل رسالة من الجهاز الأول
5. يجب أن تصل للجهاز الثاني

### اختبار Multi-hop (4+ أجهزة):

```
هاتف A ←(200m)→ هاتف B ←(200m)→ هاتف C ←(200m)→ هاتف D

اجعل A بعيداً بحيث لا يرى D مباشرة
أرسل رسالة من A
يجب أن تصل لـ D عبر B وC
```

---

## الأوزان المتوقعة

| المكون | الوصف |
|--------|-------|
| APK Release | ~15-25 MB |
| خرائط 10km² | ~50-200 MB |
| رسالة نصية | < 1 KB |
| رسالة صوتية (15s) | < 50 KB |

---

## ملاحظات مهمة

1. **Wi-Fi Direct يحتاج Location Permission** — هذا إلزامي من Android
2. **لا تغلق التطبيق** — المهمة الخلفية تبقيه حياً
3. **الشاشة الأولى للتهيئة** — انتظر 30 ثانية للاتصال الأول
4. **Battery Optimization** — أضف التطبيق لقائمة الاستثناءات في إعدادات البطارية

---

## للمذكرة الأكاديمية

> تم تطوير نظام SPAN Rescue باستخدام إطار عمل Flutter لضمان
> التوافق مع أجهزة Android المختلفة. يعتمد النظام على بروتوكول
> Wi-Fi Direct للاتصال المباشر بين الأجهزة، مع تنفيذ طبقة
> توجيه مستوحاة من AODV على مستوى التطبيق، تدعم Multi-Group
> Bridge لتجاوز القيود الطبيعية لعدد الأجهزة في شبكة واحدة.
> يضمن نظام DTN Store & Forward وصول الرسائل حتى في حالات
> الانقطاع المتكرر للاتصال.

---

*SPAN Rescue v1.0 — نبض مستقر ينقذ الأرواح*
