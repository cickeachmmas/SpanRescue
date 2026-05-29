package com.spanrescue.tactical

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.net.wifi.p2p.WifiP2pManager
import android.net.wifi.p2p.WifiP2pManager.Channel
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface
import java.util.Collections

class MainActivity: FlutterFragmentActivity() {
	private val PERMISSION_REQUEST_CODE = 1001

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		intent?.let { handleIntent(it) }
		checkAndRequestPermissions()
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		GeneratedPluginRegistrant.registerWith(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.spanrescue.tactical/foreground").setMethodCallHandler { call, result ->
			when (call.method) {
				"startService" -> {
					val serviceIntent = Intent(this, MeshForegroundService::class.java)
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
						ContextCompat.startForegroundService(this, serviceIntent)
					} else {
						startService(serviceIntent)
					}
					result.success(true)
				}
				"stopService" -> {
					val serviceIntent = Intent(this, MeshForegroundService::class.java)
					stopService(serviceIntent)
					result.success(true)
				}
				else -> result.notImplemented()
			}
		}

		// P2P info channel: returns groupOwnerAddress and whether group formed
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.spanrescue.tactical/p2p").setMethodCallHandler { call, result ->
			when (call.method) {
				"getP2pInfo" -> {
					val wifiP2p = getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
					if (wifiP2p == null) {
						result.error("NO_SERVICE", "WifiP2pManager not available", null)
						return@setMethodCallHandler
					}
					val ch: Channel = wifiP2p.initialize(this, Looper.getMainLooper(), null)
					wifiP2p.requestConnectionInfo(ch) { info: WifiP2pInfo ->
						val map = HashMap<String, Any?>()
						map["groupFormed"] = info.groupFormed
						map["isGroupOwner"] = info.isGroupOwner
						val goAddr: InetAddress? = info.groupOwnerAddress
						map["groupOwnerAddress"] = goAddr?.hostAddress
						val localIp = findP2pLocalIp() ?: try {
							val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
							val ipInt = wm.connectionInfo.ipAddress
							String.format("%d.%d.%d.%d", ipInt and 0xff, ipInt shr 8 and 0xff, ipInt shr 16 and 0xff, ipInt shr 24 and 0xff)
						} catch (e: Exception) {
							null
						}
						map["localIp"] = localIp
						result.success(map)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun findP2pLocalIp(): String? {
		return try {
			val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
			for (iface in interfaces) {
				val name = iface.name.lowercase()
				if (name.contains("p2p") || name.contains("wlan") || name.contains("wifi")) {
					val addresses = Collections.list(iface.inetAddresses)
					for (addr in addresses) {
						if (!addr.isLoopbackAddress && addr is Inet4Address) {
							return addr.hostAddress
						}
					}
				}
			}
			null
		} catch (e: Exception) {
			Log.w("MainActivity", "findP2pLocalIp failed", e)
			null
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		handleIntent(intent)
	}

	private fun handleIntent(intent: Intent) {
		// Keep intent available for Flutter plugins (e.g., deep links)
	}

	private fun checkAndRequestPermissions() {
		val required = mutableListOf<String>()

		if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
			required.add(Manifest.permission.ACCESS_FINE_LOCATION)
		}
		if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
			required.add(Manifest.permission.ACCESS_COARSE_LOCATION)
		}

		// Foreground service location permission (if defined on platform)
		try {
			val fsl = Manifest.permission.FOREGROUND_SERVICE_LOCATION
			if (ContextCompat.checkSelfPermission(this, fsl) != PackageManager.PERMISSION_GRANTED) {
				required.add(fsl)
			}
		} catch (e: NoSuchFieldError) {
			// Manifest.permission.FOREGROUND_SERVICE_LOCATION might not exist on older SDK — ignore
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
				required.add(Manifest.permission.POST_NOTIFICATIONS)
			}
		}

		if (required.isNotEmpty()) {
			ActivityCompat.requestPermissions(this, required.toTypedArray(), PERMISSION_REQUEST_CODE)
		} else {
			ensureServiceRunningIfAllowed()
		}
	}

	override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode == PERMISSION_REQUEST_CODE) {
			var grantedAnyLocation = false
			for (i in permissions.indices) {
				val p = permissions[i]
				val r = grantResults.getOrNull(i) ?: PackageManager.PERMISSION_DENIED
				if ((p == Manifest.permission.ACCESS_FINE_LOCATION || p == Manifest.permission.ACCESS_COARSE_LOCATION || p == Manifest.permission.FOREGROUND_SERVICE_LOCATION) && r == PackageManager.PERMISSION_GRANTED) {
					grantedAnyLocation = true
				}
			}

			if (grantedAnyLocation) {
				Toast.makeText(this, "Location permission granted", Toast.LENGTH_SHORT).show()
				ensureServiceRunningIfAllowed()
			} else {
				Toast.makeText(this, "Location permission is required for mesh background service", Toast.LENGTH_LONG).show()
			}
		}
	}

	private fun ensureServiceRunningIfAllowed() {
		val hasLocation = (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
				|| ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
				|| try {
			ContextCompat.checkSelfPermission(this, Manifest.permission.FOREGROUND_SERVICE_LOCATION) == PackageManager.PERMISSION_GRANTED
		} catch (e: NoSuchFieldError) { false })

		if (hasLocation) {
			val serviceIntent = Intent(this, MeshForegroundService::class.java)
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				startForegroundService(serviceIntent)
			} else {
				startService(serviceIntent)
			}
		}
	}
}
