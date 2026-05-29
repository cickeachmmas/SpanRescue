E2E Design — التشفير طرف‑لطرف المقترح لتطبيق SPAN Rescue
=====================================================

الهدف
-----
تقديم تصميم تطبيقي وآمن لتشفير الرسائل بين العقد في شبكة لا مركزية (Wi‑Fi Direct)، مع مراعاة قيود الأجهزة (موارد، اتصال متقطع) ومتطلبات التطبيق (رسائل SOS عاجلة، رسائل دردشة غير حساسة).

الحالة الحالية
---------------
هذا المستند هو تصميم مقترح لالتقاطية التشفير الطرف‑لطرف، ولا يعكس تنفيذًا موجودًا في الإصدار الحالي من التطبيق. القسم التالي يستخدم هذا التصميم كخارطة طريق للميزات القادمة.

مقاربة عامة
------------
- استخدام X25519 لمفاتيح تبادل جلسات آمنة (ECDH) لإنشاء مفاتيح مشتركة.
- استخدام AES‑GCM (256‑bit) لتشفير الرسائل بسرية ومصادقة (AEAD).
- توقيع أو MAC اختياري (Ed25519 أو HMAC‑SHA256) للتحقق من أصالة المرسل عند الحاجة.
- اعتماد TOFU (Trust-On‑First‑Use) لبيئات لا مركزية؛ إمكانية إضافة سجل ثقة محلي والـfingerprints.

تصريحية الرسائل المشفّرة (Envelope)
------------------------------------
كل رسالة مشفّرة تُرسل بنفس هيكل JSON التالي:

```json
{
  "encrypted": true,
  "cipher": "AES-GCM",
  "kdf": "HKDF-SHA256",
  "nonce": "base64",
  "body": "base64(ciphertext)",
  "senderPub": "base64(x25519_pub)",
  "sig": "base64(ed25519_sig)" // اختياري
}
```

- `senderPub`: مفتاح المرسل العام المؤقت (ephemeral) الذي يُستخدم لتوليد مفتاح الجلسة عبر X25519.
- `body`: النص المشفّر.
- `nonce`: قيمة عشوائية لكل رسالة (96-bit إن AES‑GCM).

تبادل المفاتيح والجلسات
------------------------
1. لكل جهاز: "identity key pair" ثابت (Ed25519/X25519) مخزّن في Android Keystore أو `flutter_secure_storage` مع حماية Keystore.
2. لكل اتصال (عقدة→عقدة) يتم إنشاء مفتاح جلسة عبر X25519:
   - A (ephemeralA) وB (identityB or ephemeralB) → shared = X25519(ephemeralA, identityB)
   - استخرج مفتاح AES‑GCM عبر HKDF(shared, context=...)
3. سياسة تبنّي المفاتيح:
   - TOFU: عند أول تواصل، احتفظ ببصمة مفتاح الطرف البعيد.
   - قابلية التدوير: مفاتيح مؤقتة (ephemeral) يتم تجديدها كل N رسالة أو T وقت.

مثال تدفق مبسط (A يرسل رسالة إلى B)
-------------------------------------
- A يولد ephemeral key pair `a_pub`/`a_priv`.
- A يحسب shared = X25519(a_priv, B_pub) — B_pub قد تكون identity key أو ephemeral قدمها B.
- A يشتق sessionKey = HKDF(shared)
- A يشفر payload بواسطة AES‑GCM(sessionKey, nonce)
- A يرسل envelope مع `senderPub = a_pub` و`body` و`nonce`.
- B يستقبل، يحسب shared = X25519(b_priv, a_pub) → يُشتق نفس sessionKey → يفك الشفرة.

التعامل مع الرسائل المُعاد توجيهها (store-and-forward & relay)
---------------------------------------------------------------
- إذا كانت الرسالة مُشفّرة بمفتاح جلسة end‑to‑end بين A وB، فإن العقد الوسطاء غير قادرين على فكها — هذا جيد لأمن الخصوصية.
- للرسائل التي تتطلب إعادة بث عام (مثل beacons أو SOS غير مشفّرة على مستوى E2E)، يمكن:
  - تركها كنص واضح مع توقيع لتأكيد المصداقية، أو
  - تشفير جزء الحسّاس (payload) وترك header غير مشفّر يتضمن metadata وTTL.

مفارقات وتصميم اختياري
----------------------
- SOS: يمكن إعطاء خيار إرسال نسخة مشفّرة E2E ومُوازية نسخة "عامة" مُوقعة تُسمح للأجهزة الأخرى بقراءة المعلومات الأساسية (نوع الطوارئ والموقع) حتى يتمكن متوسطو الشبكة من توجيه الرسالة.
- Metadata غير الحسّاسة (messageId, ttl, path) يمكن تركها غير مشفّرة لتمكين التوجيه، مع تشفير الـ`payload` فقط.

حفظ المفاتيح وآلية الاسترجاع
---------------------------
- على Android، استخدم Android Keystore مع مفتاح RSA/EC لتشفير المفتاح الثابت أو لتخزين الـseed.
- على Flutter، استخدم `flutter_secure_storage` مع Keystore backing.
- خزّن fingerprints (hash of public key) في ملف محلي واظهر تنبيهًا على تغيير المفتاح عند mismatch (TOFU warning).

دالة‑بدالة (pseudocode) في Dart
--------------------------------

```dart
import 'package:cryptography/cryptography.dart';

final algorithm = X25519();
final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

Future<SecretKey> deriveSessionKey(SimpleKeyPair myEphemeral, SimplePublicKey theirPub) async {
  final shared = await algorithm.sharedSecretKey(keyPair: myEphemeral, remotePublicKey: theirPub);
  final raw = await shared.extractBytes();
  final session = await hkdf.deriveKey(secretKey: SecretKey(raw), info: [], nonce: []);
  return session;
}

Future<List<int>> encryptAesGcm(SecretKey key, List<int> plaintext) async {
  final cipher = AesGcm.with128bits();
  final nonce = _randomBytes(12);
  final secretBox = await cipher.encrypt(
    plaintext,
    secretKey: key,
    nonce: nonce,
  );
  return concat(nonce, secretBox.cipherText, secretBox.mac.bytes);
}
```

مخاطر وقيود
-----------
- overhead: تبادل مفاتيح وحسابات ECDH يستهلك CPU ووقت، خصوصًا على أجهزة قديمة.
- إعادة التوجيه: E2E يمنع الوسطاء من فحص محتوى الرسائل مما قد يؤثر على سلوكيات التوجيه والسياسات.
- إدارة المفاتيح المفقودة: إذا فقدت العقدة مفتاح هويتها، لا يمكن استعادة الرسائل القديمة المشفّرة.

خيارات تنفيذية مقترحة للتدرج (phased rollout)
-----------------------------------------------
1. المرحلة 0: Metadata-only signing — أضف توقيع Ed25519 إلى الرسائل غير الحساسة.
2. المرحلة 1: Session keys for 1:1 chat — تطبيق X25519 + AES‑GCM للرسائل المباشرة.
3. المرحلة 2: Hybrid for SOS — جزء عام قابل للتوجيه + جزء مشفر.
4. المرحلة 3: PKI/CA option (اختياري) للشبكات المدارة حيث يمكن توزيع شهادات موثوقة.

خاتمة
------
التصميم أعلاه يعطي مزيجًا عمليًا بين الأمان وقابلية العمل في بيئة لامركزية. يمكنني الآن:
- (أ) توليد `lib/core/crypto_service.dart` مع اعتمادية على `cryptography` وكتابة أمثلة اختبارية،
- (ب) إضافة ميزات TOFU UI وواجهة إدارة المفاتيح في التطبيق، أو
- (ج) تنفيذ توقيع رسائل خفيف (Ed25519) على الفور كخطوة أولى.

اختر أحد البدائل لأكمل التنفيذ العملي.