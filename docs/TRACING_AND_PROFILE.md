Tracing & Profile — تعليمات جمع CPU/MEMORY وLogcat
====================================================

هدف الملف
---------
إرشادات خطوة‑بخطوة لجمع بيانات أداء (CPU profile، memory snapshot، وAndroid logcat) من تطبيق Flutter لتشخيص ANR وتسخين الجهاز.

البيئة
------
- جهاز Android متصل عبر USB مع `adb` متاح في PATH.
- Flutter SDK مثبت.
- أوامر أدناه على Windows PowerShell (تعمل كذلك في Bash مع تغييرات طفيفة).

1) تشغيل التطبيق في وضع `profile` (Flutter)
-----------------------------------------
- افتح PowerShell في مجلد المشروع.

```powershell
flutter clean
flutter pub get
flutter run --profile -d <device-id>
```

- افتح DevTools عبر الرابط الذي يطبعه `flutter run` أو عبر تشغيل:

```powershell
flutter pub global activate devtools
flutter pub global run devtools
# افتح المتصفح على http://127.0.0.1:9100
```

- في DevTools → Performance → ابدأ تسجيل CPU profile قبل إعادة السيناريو الذي يسبّب التجمّد (فتح الشاشة أو بدء Discovery)، ثم أوقف التسجيل بعد حدوث التجمّد أو بعد 30–60 ثانية.
- احفظ الـtrace (export) كـ `.json` أو `.trace` وشاركه معي.

2) جمع Flutter logs
--------------------
- سجّل لوجات Flutter إلى ملف أثناء إعادة إنتاج المشكلة:

```powershell
flutter logs > flutter_logs.txt
# بعد الانتهاء، اضغط Ctrl+C لحفظ الملف
```

3) جمع Android `logcat` مفصّل
-----------------------------
- لالتقاط أخطاء النظام وANR وstack traces:

```powershell
adb logcat -v threadtime *:V > logcat_full.txt
# أو للأخطاء فقط
adb logcat -v time '*:E' > logcat_error.txt
```

- إن ظهرت ANR، ستجد رسائل `ANR` وstack traces في `logcat_full.txt`، وابحث عن `Input dispatching timed out` أو `ANR in`.

4) جمع heap (اختياري)
----------------------
- للحصول على heap snapshot عبر `adb` (مفيد لزيادة الذاكرة):

```powershell
adb shell dumpsys meminfo <your.package.name> > meminfo.txt
```

5) ماذا أرسل لي بعد التجميع
---------------------------
- `flutter_logs.txt`
- `logcat_error.txt` أو `logcat_full.txt`
- CPU profile/trace من DevTools (ملف محفوظ)
- وصف موجز للخطوات التي قمت بها قبل حدوث التجمد (مثلاً: افتح الدردشة، شغّل SOS، مدة التحميل)

6) تعليمات سريعة لتشغيل تجارب خفيفة (بدون DevTools)
---------------------------------------------------
- لتشغيل التطبيق وإعادة تجربة الخطوات مع مراقبة درجات الحرارة والـCPU:

```powershell
# تشغيل عادي
flutter run -d <device-id>
# مراقبة استخدام CPU (على الجهاز) — يتطلب adb shell top
adb shell top -m 10 -d 1
```

7) ملاحظات خاصة بالأداء
-----------------------
- قم بتجربة نسخة مبسطة: عطل الشبكة المحلية أو أوقف Discovery مؤقتًا لتحديد ما إذا كانت الوظائف الشبكية الموزعة هي السبب.
- قلل زمن Beacon/Discovery لتشخيص التحسّن مؤقتاً.

8) تسليم الملفات
-----------------
- ضع الملفات في سرفر مشارك (Google Drive/Dropbox) أو أرفقها هنا عبر المحادثة إذا كانت صغيرة.

---

إذا رغبت، أُنشئ سكربت PowerShell تلقائي لجمع `flutter logs`, `adb logcat`، و`adb meminfo` ثم أرشّف النتائج إلى ملف ZIP لتسهيل الإرسال. أطبّق السكربت الآن؟