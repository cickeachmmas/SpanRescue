SPAN Rescue — Documentation
=============================

ملف توثيقي مفصّل للتطبيق "SPAN Rescue" (v1.0.0)

المحتويات
---------
- **نظرة عامة**
- **مبدأ العمل والفكرة**
- **البنية المعمارية**
- **نموذج البيانات (MeshMessage)**
- **بروتوكولات الشبكة**
- **الخدمات الأساسية (شرح الملفات)**
- **مكونات Android الأصلية**
- **واجهة المستخدم (UI) وتدفقها**
- **تشغيل وبناء التطبيق**
- **حالات الفشل الشائعة وطرق التحري**
- **الأمن والخصوصية**
- **اقتراحات تحسينية**
- **فهرس الملفات المهمة مع روابط**

**نظرة عامة**
- الهدف: تطبيق ميدان تكتيكي لشبكة لامركزية تعتمد على Wi‑Fi Direct لتبادل رسائل نص/صوت، إشعارات SOS، وتبادل معلومات الميدان دون اعتماد على خادم مركزي أو إنترنت.
- تقنية الواجهة: Flutter (Dart). المكوّنات الأصلية على Android مكتوبة بـ Kotlin لخدمات الخلفية (FGS) واستجابة إقلاع الجهاز.

**مبدأ العمل والفكرة**
- كل جهاز يعمل بعقدة (`Node_XXXXX`) تنشر حالة وموقعها عبر beacons دورية.
- الرسائل تنتشر عبر Wi‑Fi Direct وتُعاد توجيهها في التطبيق بواسطة طبقة بث محسوبة مع قيود `ttl` و`hopCount` لمنع الفيض والتكرار.
- رسائل الطوارئ (SOS) لها أولوية خاصة ولا تُنهي بسرعة (ttl كبير) وتُعرض فورًا للمستخدمين.
- التطبيق يدعم: تخزين مؤقت وإعادة إرسال (store-and-forward)، تشغيلاً مستمرًا عبر Foreground Service، وطلب أذونات زمن التشغيل على Android.

**البنية المعمارية**
- طبقات:
  - UI (Flutter Widgets) — شاشات: الخريطة، الدردشة، الشاشات المساعدة.
  - Business logic (Dart services) — `MeshService`, `WifiDirectService`, `BeaconService`, `StoreForwardQueue`, `BridgeManager`, `MeshRouter`.
  - Native Android — `MeshForegroundService`, `BootReceiver`, `MainActivity` للتوافق مع Android lifecycle والأذونات.
- نمط الربط: `Provider`/`ChangeNotifier` لربط الخدمات داخل شجرة واجهة Flutter.

**نموذج البيانات — `MeshMessage`**
- الحقول الأساسية ووظائفها:
  - `messageId` (String): معرف فريد للرسالة (UUID).
  - `senderId`, `senderGroup`: هوية المرسل والمجموعة.
  - `type`: enum تُحدد نوع الرسالة (chat/voice/sos/beacon/beaconGo/rreq/rrep).
  - `content`: نص أو Base64 للصوت.
  - `audioEof`, `replyTo`, `edited`, `deleted`.
  - `ttl`, `hopCount`, `seenBy`, `path` لمراقبة انتشار الرسالة.
  - `timestamp`, `location: GeoLocation`, `medicalState`, `role`, `battery`, `triageState`.
- وظائف:
  - `copyWith`, `copyWithHop` لتعديل نسخ الرسائل عند إعادة الإرسال.
  - `toJson`/`fromJson` لتحويل الرسائل لسلاسل عند البث.

راجع: [lib/models/mesh_message.dart](lib/models/mesh_message.dart#L1-L220)

**بروتوكولات الشبكة وسلوك الرسائل**
1. Discovery / Beacon:
   - `BeaconService` يرسل beacon دوري يحتوي على هوية العقدة وحالتها وموقعها.
   - المجموعات تستخدم beacons لتحديث جداول الجيران وتكوين علاقات GO/Client.
2. نشر الرسائل:
   - عند استدعاء `wifi.broadcastMessage(msg)`، يتم إرسال JSON مرفق بفاصل (`\n`) عبر قناة P2P إلى الجيران المتصلين.
   - كل متلقٍ يفك JSON، يتحقق من `messageId` و`seenBy`، ويقرّر ما إذا كان سيعرض الرسالة أو يعيد بثّها.
3. منع التكرار:
   - استخدام `messageId` و`seenBy` و`path` يمنع الحلقات ويُقلّل من حمل الشبكة.
4. توجيه الرسائل الحالية:
   - التطبيق يعتمد في الإصدار الحالي على بث محسوب مع ضبط TTL و`seenCache` بدلاً من تنفيذ AODV كامل.
   - `MeshRouter` يقرر متى يعيد التوجيه، متى يسلم الرسالة، ومتى يوقفها بسبب التكرار أو انتهاء TTL.
5. Store-and-forward:
   - `StoreForwardQueue` يخزن الرسائل عند فشل الإرسال أو انقطاع الاتصال ويعيد المحاولة تلقائيًا.

ملاحظة قابليّة التوسعة:
- البنية الحالية تعتمد على Wi‑Fi P2P وروابط TCP بين العقد المتصلة، وهي مناسبة لتجارب المجموعات الصغيرة والمتوسطة.
- للاختبارات الكبيرة (+20 جهاز)، يفضّل استخدام حل يدعم mesh حقيقي مع relay/routing أو الاعتماد على Google Nearby Connections عبر Google Play Services.
- إنشاء اتصال TCP مباشر لكل زوج من الأجهزة لا يتوسع بسهولة ويزيد من تعقيد الإدارة والموارد في الشبكات الكبيرة.

**الخدمات الأساسية — شرح الملفات والسلوك**
- `lib/core/mesh_service.dart`:
  - مسؤول عن الحالة المحلية، قائمة الرسائل (`chatMessages`)، تعديلات الرسائل، مؤشرات الكتابة `typingIndicators`، وبث أحداث `onMessage`/`onSOS`.
  - يتعامل مع تخزين محلي للرسائل وإضافة سجلات لواجهة السجل.

- `lib/core/wifi_direct_service.dart`:
  - يتكامل مع plugin Wi‑Fi P2P (flutter_p2p_connection أو مكوّن مخصص) لإجراء `discover`, `connect`, `createGroup`, و`send/receive` raw messages.
  - طرق مهمة: `start()`, `_discover()`, `broadcastMessage(MeshMessage)`, `broadcastRaw(String)`.
  - يتصل بـ `StoreForwardQueue` و`BridgeManager` لإتمام عمليات الإرسال عبر جسور.

- `lib/core/beacon_service.dart`:
  - ينظم توقيت beacons، يبني رسائل beacon (type=`beacon`/`beaconGo`) ويصدرها عبر `WifiDirectService`.

- `lib/core/store_forward_queue.dart`:
  - قائمة انتظار دائمة تحفظ الرسائل على القرص (SharedPreferences أو ملف). يحتفظ بمؤشر retry وسياسة TTL local.

- `lib/core/notification_service.dart`:
  - يهيئ قنوات إشعارات متعددة (normal, high/SOS)، ويعرض إشعارات عند ورود رسائل أو SOS.

- `lib/core/audio_service.dart`:
  - وظيفة: تسجيل صوتي، تشفير/تحويل إلى base64، تشغيل من base64 عند الطلب.

**مكونات Android الأصلية**
- `android/app/src/main/AndroidManifest.xml` — يعرّف صلاحيات النظام الضرورية: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `RECEIVE_BOOT_COMPLETED`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`, وغيرها.
- `android/.../MainActivity.kt` — `FlutterFragmentActivity`، يطلب أذونات وقت التشغيل ويبدأ `MeshForegroundService` إذا مُنحت الأذونات.
- `android/.../MeshForegroundService.kt` — خدمة foreground تعرض إشعارًا دائماً باستخدام `startForeground()`, تُبقي الشبكة تعمل في الخلفية، وتدير WakeLock.
- `android/.../BootReceiver.kt` — يستمع لحدث BOOT_COMPLETED ويبدأ الخدمة فقط عندما تُمنح أذونات الموقع.

**واجهة المستخدم وتدفقها**
- نقطة الدخول المرئية: `MainShell` التي تُحمّل خريطة التكتيكية `MeshMapScreen`، شاشة الدردشة، الشاشة الرئيسية.
- `MeshMapScreen` يعرض:
  - `FlutterMap` مع `TileLayer` يدعم ملفات في `assets/map_tiles/{z}/{x}/{y}.png` كـ offline tiles و`fallbackUrl` إلى tile.openstreetmap.org.
  - Markers للأجهزة وMarker لموقع المستخدم.
  - أزرار عائمة: `NodesDirectory` و`SOSButton` (موقعان عبر Positioned وتم تعديلهما لاحقًا لاحترام `MediaQuery.padding.top`).

- الدردشة:
  - `MessageBubble` يدعم أنواع متعددة من المحتوى (نص/صوت/SOS) ويعرض الوقت، حالة الـedited، ومؤشر حذف.
  - `ChatInputBar` يدعم إرسال نص وتسجيل صوتي عبر long-press مع تايمر للـtyping.

**تشغيل وبناء التطبيق**
- متطلبات: Flutter SDK، Android SDK، جهاز Android أو محاكي.
- أوامر أساسية:
  - `flutter clean`
  - `flutter pub get`
  - `flutter run -d <device-id>`
- الملاحظات العملية: أثناء العمل احتجنا إلى `--refresh-dependencies` أحيانًا ووجود اتصال إنترنت لتنزيل تبعيات Gradle/flutter.

**حالات الفشل الشائعة وطرق التحري**
- `ClassNotFoundException` في BootReceiver: يحدث إذا كان `android:name` في الـmanifest لا يطابق package/class الفعلي. الحل: استخدم اسم الحزمة الكامل (`com.spanrescue.tactical.BootReceiver`).
- `SecurityException` عند بدء FGS بنوع `location`: حدث إن لم تُمنح `FOREGROUND_SERVICE_LOCATION` أو `ACCESS_FINE_LOCATION`. الحل: إما إزالة type `location` أو طلب الأذونات وقت التشغيل ومنحها قبل البدء.
- أخطاء تحميل tiles (Connection reset): شبكية/مشكلة مورد خارجي — قدم offline tiles أو طبّق caching.

**الأمن والخصوصية**
- الوضع الحالي: الرسائل ترسل كنص JSON غير مشفّر.
- توصية أمان: تنفيذ E2E encryption — تبادل مفاتيح باستخدام X25519 ثم تشفير الرسائل بـ AES-GCM مع HMAC إن تطلب الأمر.
- تخزين الحساس: تجنّب تخزين بيانات حساسة بنص واضح في SharedPreferences، وفكّر في استخدام keystore أو مكتبات تخزين مشفرة.

**اقتراحات احترافية للتحسين**
1. إدخال تشفير E2E للرسائل الحساسة.
2. تحسين Tile caching لخرائط OSM مع LRU cache محلي.
3. شاشة Onboarding تُوضّح لماذا يحتاج التطبيق صلاحيات `ACCESS_BACKGROUND_LOCATION` و`FOREGROUND_SERVICE_LOCATION`.
4. مراقبة أداء الشبكة وتصدير مقاييس (latency, delivery rate, hop distribution).
5. دعم تخصيص واجهة: زر SOS قابل للسحب (draggable) ومكان حفظه.
6. إضافة اختبارات (unit/integration) لمحاكاة تدفق الرسائل عبر عدة عُقد (mock wifi_direct).

**فهرس ملفات مهمّة**
- [lib/main.dart](lib/main.dart#L1-L200)
- [lib/core/mesh_service.dart](lib/core/mesh_service.dart#L1-L120)
- [lib/core/wifi_direct_service.dart](lib/core/wifi_direct_service.dart#L1-L140)
- [lib/core/beacon_service.dart](lib/core/beacon_service.dart)
- [lib/core/store_forward_queue.dart](lib/core/store_forward_queue.dart)
- [lib/core/notification_service.dart](lib/core/notification_service.dart)
- [lib/models/mesh_message.dart](lib/models/mesh_message.dart#L1-L220)
- [lib/screens/mesh_map_screen.dart](lib/screens/mesh_map_screen.dart#L1-L520)
- [lib/widgets/chat/chat_widgets.dart](lib/widgets/chat/chat_widgets.dart#L1-L260)
- [lib/widgets/map/sos_button.dart](lib/widgets/map/sos_button.dart#L1-L120)
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml#L1-L220)
- [android/app/src/main/kotlin/com/spanrescue/tactical/MainActivity.kt](android/app/src/main/kotlin/com/spanrescue/tactical/MainActivity.kt#L1-L200)
- [android/app/src/main/kotlin/com/spanrescue/tactical/MeshForegroundService.kt](android/app/src/main/kotlin/com/spanrescue/tactical/MeshForegroundService.kt#L1-L200)
- [android/app/src/main/kotlin/com/spanrescue/tactical/BootReceiver.kt](android/app/src/main/kotlin/com/spanrescue/tactical/BootReceiver.kt#L1-L200)

---

هذا الملف هو توثيق تفصيلي عام للتطبيق. إن رغبت، أُوسّعه إلى ملفات منفصلة لكل مكوّن (مثلاً: "تفصيل `WifiDirectService` — حقل بحقل، مخاطر، أمثلة رسائل JSON") أو أصدّره إلى PDF/Markdown منسق مع مخططات وتدفقات. أي جزء تريدني أن أوسّعه أولاً؟

**تفصيل أكاديمي واحترافي: البروتوكول والآلية (Protocol & Mechanism Specification)**

مقدمة مختصرة
- الهدف من هذا القسم: تقديم وصف رسمي وممنهج لبروتوكول التوزيع المستخدم في التطبيق، قابلية القياس، خواص التكامل، وتحليل سلوكي تحت فشل الشبكة.
- المستوى: مواصفات طبقية (نموذج)، تعاريف رسائل، آلات حالة العقدة، وخوارزميات رئيسية مع أمثلة تنفيذية بلغة Dart وقطع Kotlin لنقاط الحياة على Android.

1) نموذج طبقات البروتوكول (Logical Layers)
- Link/Discovery layer: مسؤول عن اكتشاف الجيران (Wi‑Fi P2P discovery / beacons) وإدارة وصلات GO/Client.
- Transport/Message layer: إرسال/استقبال رسائل JSON الخام عبر socket/stream داخل جلسة P2P.
- Routing/Overlay layer: إدارة إعادة البث والتوجيه بالاعتماد على `ttl` و`seenCache`، مع استعداد لملاءمة `MeshRouter` لاحقًا لخصائص أكثر تعقيدًا.
- Application layer: تخزين الرسائل، UI، وقياسات جودة الخدمة (delivery, latency).

2) شكل/مخطط الرسالة (Message Envelope)
كل رسالة مرسلة عبر الشبكة تتبع الـJSON التالي (schema رسمي):

```json
{
  "messageId": "uuid-v4",
  "type": "chat|voice|sos|beacon|rreq|rrep",
  "senderId": "Node_ABC",
  "senderGroup": "alpha",
  "timestamp": 1687212345678,
  "ttl": 8,
  "hopCount": 0,
  "path": ["Node_ABC"],
  "seenBy": [],
  "payload": { /* content depends on type */ }
}
```

مثال `payload` لرسالة chat:

```json
"payload": { "text": "Help at grid D4", "edited": false, "deleted": false }
```

ملاحظات تصميمية:
- الحقول `seenBy` و`path` تستخدمان لمنع الحلقات ودعم قياسات المسار.
- `ttl` و`hopCount` يضمنان انحسار البث تلقائيًا (flood‑control).
- `rreq` و`rrep` هما أنواع احتياطية مخصصة لاحقًا لتحكم الطريق، لكن التطبيق الحالي يعتمد على بث محسوب و`MeshRouter` لعملية التوجيه.

3) آلة حالة العقدة (Node State Machine)
- حالات رئيسية:
  - IDLE: لا اتصالات، فقط استماع للـbeacons.
  - DISCOVERING: جارٍ اكتشاف الجيران.
  - CONNECTED: يوجد قناة فعالة مع جيران محددين.
  - RELAYING: العقدة تعيد بثّ أو تستجيب لطلبات توجيه.

انتقالات أساسية (مبسطة):
- IDLE --(discover_timer)--> DISCOVERING
- DISCOVERING --(found_peer)--> CONNECTED
- CONNECTED --(incoming_message)--> RELAYING
- RELAYING --(no_peers)--> IDLE

4) خوارزمية النشر (Flood + Controlled Forwarding)
وصف مبسط:

```pseudo
onReceive(msg):
  if msg.messageId in seenCache: return  // duplicate
  add msg.messageId to seenCache
  if shouldDeliverToApp(msg): deliver(msg)
  if msg.ttl - msg.hopCount > 0 and forwardPolicyAllows(msg):
    msg.hopCount += 1
    msg.path.append(selfId)
    broadcast(msg)

forwardPolicyAllows(msg):
  // سياسة قابلة للتخصيص: مثال بسيط يتركز على ttl والعبء الشبكي
  return (msg.type == "sos") or (currentLoad < LOAD_THRESHOLD)
```

تعقيد زمني: O(1) لكل رسالة على العقدة من حيث اتخاذ القرار (بافتراض عمليات hash/set للـseenCache).

5) توجيه مسارات (النسخة الحالية)
- التطبيق الحالي يعتمد على بث محدود وتوجيه متحكم به عبر `MeshRouter`، ولا يستخدم آلية RREQ/RREP التفاعلية بشكل فعلي.
- `MeshRouter` يحفظ سجل الرسائل التي تمت معالجتها ويمنع إعادة بث الرسائل المكررة.
- جداول الطريق تُستخدم للتوسيع المستقبلي، لكن لا تُعد المحرك الرئيسي لتوجيه الرسائل البثية في الإصدار الحالي.

6) Store‑and‑Forward queue (موثوقية عند الانقطاع)
- عند فشل الإرسال (noPeers أو socket error) تُسجل الرسالة في `StoreForwardQueue` مع سياسة retry:
  - retryIntervals = [1s, 5s, 20s, 60s, 300s]
  - maxAttempts = 5
  - عند تجاوز maxAttempts تُعلَن الرسالة كفاشلة في واجهة المستخدم.

7) تقسيم/تجميع الصوت (Chunking for audio)
- ملفات الصوت الكبيرة تُقسم إلى قطع ثابتة الحجم (مثلاً 12 KB payload) مع حقل `chunkIndex` و`chunkCount` في payload.
- كل قطعة تُرسل كرسالة مستقلة مع نفس `messageId` و`chunkIndex` لتمكين إعادة التجميع وإعادة الإرسال الجزئي.

8) آليات اكتشاف ومنع التكرار (Dedup & Loop Prevention)
- `seenCache`: cache محلي بقيود حجم (LRU) يخزن معرفات الرسائل لمدة زمنية محددة (مثلاً 10 دقائق).
- `path` يساعد في تشخيص حلقة وإحصائيات هوب.

9) أمثلة كود — Dart: ترميز/فك رسالة وإحكام إعادة البث

```dart
// Encode JSON and broadcast
Future<void> broadcastMessage(MeshMessage msg) async {
  final jsonStr = jsonEncode(msg.toJson());
  // append newline as delimiter if using streaming sockets
  await _socket.write('$jsonStr\n');
}

// Handler on receive
void onReceiveRaw(String raw) {
  final msg = MeshMessage.fromJson(jsonDecode(raw));
  if (_seenCache.contains(msg.messageId)) return;
  _seenCache.add(msg.messageId);
  _deliverToAppIfNeeded(msg);
  if (msg.ttl - msg.hopCount > 0 && shouldForward(msg)) {
    final fwd = msg.copyWith(hopCount: msg.hopCount + 1, path: [...msg.path, selfId]);
    broadcastMessage(fwd);
  }
}
```

10) مثال Kotlin — بدء `MeshForegroundService` بأمان في `MainActivity`

```kotlin
fun ensureServiceRunningIfAllowed(ctx: Context) {
  if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
  val intent = Intent(ctx, MeshForegroundService::class.java)
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(intent) else ctx.startService(intent)
}
```

11) القياسات ووصف الجودة (Metrics)
- deliveryRate = deliveredMessages / sentMessages (local, windowed)
- medianLatency: زمن الحصول على ACK أو الزمن المتوسط حتى ظهور الرسالة في عقدة مستهدفة (مقدر عبر علامات زمنية path timestamps)
- hopDistribution: توزيع عدد الهوبات لكل رسالة واستخدامه لتقييد TTL الافتراضي.

12) تحليل سلوك تحت فشل جزئي
- تقنيات متبعة:
  - تقليل إعادة البث على أساس الحمولة (adaptive forwarding)
  - استخدام store‑and‑forward للأماكن المقطوعة مع backpressure
  - إعطاء أولوية عالية لرسائل SOS عبر قواعد لون وTTL أكبر

13) تصميم أمني مقترح (End‑to‑End Encryption, اختياري)
- متطلبات: ضمان سرية الرسائل، مصداقيتها، والحماية من إعادة التشغيل (replay).
- مقترح سريع:
  1. تبادل مفاتيح انصرافية (Ephemeral) عبر X25519 بين العقدتين المتواصلتين أو عبر بروتوكول وضع‑الشفرة العام.
  2. إنشاء مفتاح جلسة AES‑GCM لكل زوج عقدة‑عقدة (or per‑message ephemeral keys).
  3. إضافة حقل `sig` أو `mac` في الغلاف لتوقيع/التحقق (مثلاً HMAC‑SHA256 أو Ed25519 signature للمحتوى المشفّر).

Envelope عند التشفير (JSON):

```json
{
 "encrypted": true,
 "cipher": "AES-GCM",
 "nonce": "base64..",
 "body": "base64(ciphertext)",
 "senderPub": "base64(x25519_pub)",
 "sig": "base64(ed25519_sig)"
}
```

ملاحظات تنفيذية:
- مفتاح الجهاز (identity key) يجب أن يُخزن في Android Keystore أو في `flutter_secure_storage` مع backing keystore.
- تبادل المفاتيح في بيئة لا مركزية يحتاج إلى آليات اكتساب ثقة (trust-on-first-use TOFU) أو PKI تسلسلي إن وُجدت سلطة شهادة.

14) ملاحظات هندسية ونهائية
- ضبط القيم الافتراضية للـ`ttl`, retry intervals وcache durations يلعب دورًا حاسمًا في سلوك الشبكة.
- التوازن بين قابلية الاكتشاف والتشويش: beacons كثيفة تؤدي لاستهلاك طاقة أعلى؛ beacons متباعدة تؤدي لفترات اندماج أبطأ.
- استخدام أدوات محاكاة (ns‑3 أو مَحاكٍ مخصص في Dart) يُساعد في اختيار القيم الأمثل قبل النشر.

---

انتهى القسم الأكاديمي المفصّل. إذا رغبت، أستطيع الآن:
- (أ) فصل هذا القسم إلى ملف مستقل `docs/PROTOCOL_SPEC.md`،
- (ب) توسيع كل مقتطف كود إلى مثال كامل قابل للتجريب (micro‑package) بلغة Dart، أو
- (ج) تنفيذ تصميم التشفير (E2E) عمليًا داخل `lib/core` مع اختبارات توافقيّة.

