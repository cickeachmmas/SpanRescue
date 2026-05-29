WIFI_DIRECT_SERVICE — تفصيل دالة‑بدالة
=====================================

الغرض
-----
ملف `WifiDirectService` هو طبقة الحافة المسؤولة عن التفاعل مع واجهات Wi‑Fi Direct والـTCP sockets. يوفر:
- اكتشاف الأجهزة (peers) عبر Wi‑Fi P2P.
- إدارة وضع Group Owner (GO) وتهيئة TCP Server كـGO.
- اتصالات TCP للـClients، وإرسال/استقبال رسائل JSON متسلسلة مفصولة بـ\n.
- دعم Bridge بين GOs عبر `BridgeManager`، وتفريغ `StoreForwardQueue` على الاتصالات.

التبعيات
--------
- `flutter_p2p_connection` plugin
- `dart:io` sockets
- `permission_handler` لطلب صلاحيات الجهاز
- الموديلات والخدمات: `MeshService`, `StoreForwardQueue`, `BridgeManager`, `MeshRouter`

واجهات وظيفية رئيسية (API)
-------------------------
- `Future<void> start()`
  - يهيئ الـplugin، يسجل لتيّارات المعلومات (`streamWifiP2PInfo`, `streamPeers`) ويبدأ حلقات الـdiscovery وbeacon.
  - يفعل `_requestPermissions()` قبل التشغيل.

- `Future<void> stop()`
  - يقفل مؤقتات الـdiscovery والـbeacon، يغلق السرفر، يدمّر الـsockets، ويُلغِي تسجيل الـp2p plugin.

- `Future<void> connectAsClient(String goIp)`
  - كـclient يتصل إلى GO عبر `Socket.connect(goIp, clientPort)` ويُسجّل السوكيت في `_clientSockets`.
  - عند اتصال ناجح، يقوم باستدعاء `_queue.flushToSocket(socket)` لإفراغ قائمة الانتظار.

- `Future<void> broadcastMessage(MeshMessage message)`
  - يرسل رسالة JSON بجميع الـclient sockets المتصلة، ويُحاول إرسالها إلى bridges عبر `_bridgeManager` إن كانت العقدة GO.
  - في حالة فشل إرسال، يُدخِل الرسالة في الـ`StoreForwardQueue`.

سلوك داخلي دالة‑بدالة
---------------------
- `_requestPermissions()`
  - يطلب الصلاحيات: `Permission.location`, `Permission.nearbyWifiDevices`, `Permission.microphone`.
  - يسجل نتائج الطلبات عبر `_meshService.addLog`.

- `_startDiscoveryLoop()` و`_discover()`
  - تبدأ مؤقتًا دوريًا (`Timer.periodic`) كل 15 ثانية لاستدعاء `_p2p.discover()`.
  - تتعامل مع الاستثناءات وتلّقِي الأخطاء في سجل النظام.

- `_onP2PInfoChanged(WifiP2PInfo info)`
  - يستقبل حالة P2P، يحدّد إن كانت العقدة GO، ويُحدّث `_isGroupOwner` و`_myIp` و`_meshService` تبعًا لذلك.
  - عند الترقية إلى GO يستدعي `_startClientTCPServer()` و`_bridgeManager.startBridgeServer()`.
  - عند الزوال، يغلق السرفر ويحذف حالة GO.
  - إن لم يُعثر على شبكة، يستدعي `_selfPromoteToGO()` لخلق مجموعة محلية.

- `_onPeersChanged(dynamic devices)` و`_connectToPeer(dynamic peer)`
  - عندما تُكتشف أجهزة جديدة، يحاول الاتصال بها عبر `_p2p.connect(deviceAddress)`.
  - أي أخطاء تُسجَّل مع اسم الجهاز (إن وجد).

- `_startClientTCPServer()`
  - ينشئ `ServerSocket.bind(InternetAddress.anyIPv4, clientPort)` ويستمع للاتصالات.
  - لكل سوكيت جديد: يُخزن في `_clientSockets`، يستدعي `_handleIncomingSocket(socket)`، ويتابع `socket.done` لحذف السوكيت عند الانفصال.
  - يعالج الأخطاء ويحافظ على السجل.

- `_handleIncomingSocket(Socket socket)`
  - يستقبل بايتات من السوكيت، يحوّلها إلى `utf8.decode`، ويجمعها في `StringBuffer`.
  - يفك الرسائل المفصولة بـ"\n" ويستدعي `_processRawMessage` على كل سطر مكتمل.
  - عند الخطأ أو الانتهاء يُدمر السوكيت أو يسجّل الخطأ.

- `_processRawMessage(String raw, Socket sourceSocket)`
  - يكشف أولًا رسائل النوع GO_BEACON ويعالجها عبر `GroupInfo.fromJson` ثم `_bridgeManager.connectToBridge(group)`.
  - لغير ذلك يمرر `raw` إلى `_meshService.processIncoming(raw)` ويطبق قرار التوجيه (deliver/forward).
  - عند قرار Forward يقوم باستدعاء `_forwardMessage(result.processedMessage, excluding: sourceSocket)`.

- `_forwardMessage(MeshMessage message, {Socket? excluding})`
  - يرسل إلى جميع `_clientSockets` باستثناء socket المصدر، ويضع الرسالة في `_queue` عند فشل الإرسال.
  - إن كانت العقدة GO، يفوّض البث إلى `_bridgeManager.broadcastToBridges(message)` أيضًا.

اعتبارات الأداء والموثوقية
-------------------------
- `StringBuffer` لالتقاط بيانات السوكيت يتعامل مع تدفق بيانات غير مكتمل؛ لكن يجب ضمان عدم نمو Buffer بلا تحكّم عند هجمات أو خطأ بروتوكول.
- كتابة الرسائل عبر `socket.add(bytes)` غير متزامنة؛ إن فشل الإرسال يحاول الإعادة عبر `StoreForwardQueue`.
- `ServerSocket.bind(InternetAddress.anyIPv4)` سيستمع على كافة واجهات الشبكة المحلية — مناسب لبيئة GO لكن قد يحتاج لتقييد في حالات خاصة.
- النموذج الحالي يعتمد على شبكة Wi‑Fi Direct وTCP sockets بين GO وClients. هذا جيد للمجموعات الصغيرة، لكن عند زيادة عدد الأجهزة فوق 20 يكون إنشاء اتصال TCP مباشر لكل زوج غير قابل للتوسعة بسهولة.
- للحالات الأكبر أو عند الحاجة إلى شبكة mesh حقيقية، يُنصح بدراسة استخدام مكتبة تدعم relay/routing أو Google Nearby Connections (Google Play Services) لخفض تكلفة الاكتشاف وإدارة الاتصالات.

حالات الخطأ المعروفة وحلولها
---------------------------
- فشل الربط على المنفذ `clientPort` (بسبب قيود النظام أو بورت محجوز): سجّل الخطأ وحاول بورت احتياطي أو أخطر المستخدم.
- رسالة JSON غير صالحة: `_processRawMessage` يحتاط للتقاط خطأ `jsonDecode` ويُسجل الخطأ دون تحطم التطبيق.
- أخطاء P2P plugin: `_p2p.discover()` أو `_p2p.connect()` قد يطرحون استثناءات — يتم التقاطها وتسجيلها.

اختبارات مقترحة (Unit/Integration)
---------------------------------
1. Unit: محاكاة Sockets واردة بإرسال سلاسل JSON مفصولة بـ"\n" والتحقق من أن `_processRawMessage` يستدعي `_meshService.processIncoming`.
2. Integration: تشغيل خدمة وهمية `MeshService` و`BridgeManager`، ثم محاكاة Peer connect وارسال رسالة، والتحقق من تفريغ `StoreForwardQueue` عند اتصال Client.
3. Load test: إنشاء 100 اتصال client محلي عبر loopback والتحقق من استقرار `_clientSockets` وإدارة الذاكرة.

تحسينات مقترحة
---------------
- إضافة حدود لحجم الـbuffer لكل socket وإغلاق الاتصالات عند تجاوزه لحماية ضد هجمات large‑payload.
- دعم backpressure: استخدام `socket.addStream` أو آلية صفوف لتجنب تجاوز الذاكرة.
- قياس زمن الرحلة (RTT) وإدخاله كـ metric في `MeshService` لسياسات التوجيه.
- فصل القواعد البروتوكولية للـGO_BEACON وإعطاؤها مكتبة parser منفصلة لسهولة التوسع.

خلاصة
-----
هذا الملف يوثّق آلية عمل `WifiDirectService` تفصيليًا، مع توضيح سلوك كل دالة، استثناءات متوقعة، والاختبارات المقترحة. سأكمل بتفصيل ملفات أخرى (مثل `mesh_router.dart` أو `bridge_manager.dart`) وفق ترتيب أولويتك.
