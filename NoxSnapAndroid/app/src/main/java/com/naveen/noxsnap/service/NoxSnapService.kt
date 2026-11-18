package com.naveen.noxsnap.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.naveen.noxsnap.MainActivity
import com.naveen.noxsnap.NoxSnapState
import com.naveen.noxsnap.R
import com.naveen.noxsnap.discovery.NoxSnapDiscovery
import com.naveen.noxsnap.network.DiscoveredMac
import com.naveen.noxsnap.network.NoxSnapClient
import com.naveen.noxsnap.sensors.DockDirection
import com.naveen.noxsnap.sensors.MagneticDockDetector
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class NoxSnapService : Service() {

    private val tag = "NoxSnapService"
    private val scope = CoroutineScope(Dispatchers.Main)
    private val client = NoxSnapClient()

    private var dockDetector: MagneticDockDetector? = null
    private var discovery: NoxSnapDiscovery? = null
    private var activeMac: DiscoveredMac? = null

    companion object {
        const val CHANNEL_ID = "noxsnap_service_channel"
        const val NOTIF_ID = 2026
        var isServiceRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification("⚡️ NoxSnap Active • Snap Bezel to Handoff"))

        // Update cached URL from clipboard
        NoxSnapState.updateFromClipboard(this)

        // Discover Mac
        discovery = NoxSnapDiscovery(this) { mac ->
            activeMac = mac
            Log.d(tag, "Connected Mac: ${mac.name} (${mac.host})")
            updateNotification("Connected to ${mac.name} • Option A Active")
        }
        discovery?.startDiscovery()

        // Magnetic Dock Detector (Pure Phone ➔ Mac Push)
        dockDetector = MagneticDockDetector(
            context = this,
            onDockDetected = { magnitude, direction, side ->
                handleMagneticDock(side)
            }
        )
        dockDetector?.startListening()
    }

    private fun handleMagneticDock(side: String) {
        if (MainActivity.isActivityVisible) {
            Log.d(tag, "MainActivity is currently in foreground; delegating dock execution to activity.")
            return
        }

        val mac = activeMac ?: NoxSnapDiscovery.getCachedMac(this)
        if (mac == null) {
            Toast.makeText(this, "⚠️ Mac not discovered yet. Searching...", Toast.LENGTH_SHORT).show()
            return
        }

        scope.launch(Dispatchers.IO) {
            val handoffUrl = NoxSnapState.getBestAvailableUrl(this@NoxSnapService)
            val handoffText = NoxSnapState.latestClipboardText

            val resp = client.sendDock(
                mac = mac,
                direction = DockDirection.PUSH,
                handoffUrl = handoffUrl,
                handoffText = handoffText,
                side = side
            )

            scope.launch(Dispatchers.Main) {
                if (resp != null) {
                    val sentUrl = handoffUrl.ifEmpty { handoffText ?: "Webpage" }
                    Toast.makeText(this@NoxSnapService, "🌊 Beamed to Chrome!\n$sentUrl", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(this@NoxSnapService, "❌ Could not reach ${mac.name}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "NoxSnap Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors lid magnets for instant directional handoff"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("⚡️ NoxSnap Active")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIF_ID, buildNotification(text))
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        dockDetector?.stopListening()
        discovery?.stopDiscovery()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        dockDetector?.loadPreferences()
        val action = intent?.action
        if (action == "com.naveen.noxsnap.TEST_DOCK") {
            val side = intent.getStringExtra("side") ?: "right"
            handleMagneticDock(side)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
