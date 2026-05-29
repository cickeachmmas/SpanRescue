// ═══════════════════════════════════════════════════════
// MeshForegroundService.kt
// يُبقي التطبيق يعمل في الخلفية حتى عند إغلاق الشاشة
// ═══════════════════════════════════════════════════════

package com.spanrescue.tactical

import android.app.*
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import android.net.wifi.WifiManager

class MeshForegroundService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private val CHANNEL_ID = "span_mesh_service"
    private val NOTIFICATION_ID = 1001

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        acquireWakeLock()
        acquireMulticastLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY // يُعاد تشغيله تلقائياً إذا أُغلق
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        wakeLock?.release()
        multicastLock?.release()
        super.onDestroy()
        // أعد التشغيل فوراً
        val restartIntent = Intent(applicationContext, MeshForegroundService::class.java)
        startService(restartIntent)
    }

    private fun acquireMulticastLock() {
        try {
            val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            multicastLock = wifi.createMulticastLock("span_multicast_lock").apply { setReferenceCounted(true); acquire() }
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SPAN Mesh Network",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeping mesh network active"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SPAN Rescue — Active")
            .setContentText("Mesh Network Running")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SpanRescue::MeshWakeLock"
        ).apply { acquire(10 * 60 * 1000L) } // 10 دقائق
    }
}


// ═══════════════════════════════════════════════════════
// BootReceiver.kt
// يبدأ الخدمة تلقائياً عند تشغيل الهاتف
// ═══════════════════════════════════════════════════════

// package com.spanrescue.tactical
//
// import android.content.BroadcastReceiver
// import android.content.Context
// import android.content.Intent
// import android.os.Build
//
// class BootReceiver : BroadcastReceiver() {
//     override fun onReceive(context: Context, intent: Intent) {
//         if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
//             val serviceIntent = Intent(context, MeshForegroundService::class.java)
//             if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                 context.startForegroundService(serviceIntent)
//             } else {
//                 context.startService(serviceIntent)
//             }
//         }
//     }
// }
