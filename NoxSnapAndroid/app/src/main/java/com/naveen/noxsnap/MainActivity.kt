package com.naveen.noxsnap

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.naveen.noxsnap.databinding.ActivityMainBinding
import com.naveen.noxsnap.discovery.NoxSnapDiscovery
import com.naveen.noxsnap.network.DiscoveredMac
import com.naveen.noxsnap.network.NoxSnapClient
import com.naveen.noxsnap.sensors.DockDirection
import com.naveen.noxsnap.sensors.MagneticDockDetector
import com.naveen.noxsnap.service.NoxSnapService
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    companion object {
        var isActivityVisible: Boolean = false
    }

    private lateinit var binding: ActivityMainBinding
    private lateinit var discovery: NoxSnapDiscovery
    private lateinit var detector: MagneticDockDetector
    private val client = NoxSnapClient()
    private var selectedDevice: DiscoveredMac? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Trap any unexpected crash and log to file
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            android.util.Log.e("MainActivity", "Uncaught exception in ${thread.name}", throwable)
            try {
                val dirFile = getExternalFilesDir(null) ?: filesDir
                val crashFile = java.io.File(dirFile, "crash.log")
                crashFile.appendText("CRASH [${java.util.Date()}]: ${throwable.stackTraceToString()}\n")
            } catch (e: Exception) {}
        }

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Cache initial clipboard
        NoxSnapState.updateFromClipboard(this)
        updatePushUrlDisplay()

        discovery = NoxSnapDiscovery(this) { mac ->
            runOnUiThread {
                selectedDevice = mac
                binding.tvDeviceName.text = "${mac.name} • Ready"
                binding.viewOnlineDot.visibility = View.VISIBLE
            }
        }

        detector = MagneticDockDetector(
            context = this,
            onDockDetected = { magnitude, direction, side ->
                runOnUiThread {
                    executeHandoff(side, magnitude)
                }
            },
            onFieldUpdated = { magnitude, bx, by, bz, yaw, roll, direction, isCalibrated ->
                runOnUiThread {
                    updateMagneticGauge(magnitude, bx, by, bz, yaw, roll, direction, isCalibrated)
                }
            }
        )

        setupUI()
        updateCalibrationUI()
    }

    private fun setupUI() {
        // Calibration Buttons
        binding.btnCalibrateLeft.setOnClickListener {
            detector.startCalibration(DockDirection.PULL)
            binding.tvCalibStatus.text = "👉 Touch phone's top-left to Mac's LEFT corner now..."
            binding.tvCalibStatus.setTextColor(Color.parseColor("#38BDF8"))
            binding.tvCalibStatus.setBackgroundColor(Color.parseColor("#172554"))
            Toast.makeText(this, "Touch top-left corner of phone to Mac's LEFT lid bezel", Toast.LENGTH_SHORT).show()
        }

        binding.btnCalibrateRight.setOnClickListener {
            detector.startCalibration(DockDirection.PUSH)
            binding.tvCalibStatus.text = "👉 Touch phone's top-left to Mac's RIGHT corner now..."
            binding.tvCalibStatus.setTextColor(Color.parseColor("#C084FC"))
            binding.tvCalibStatus.setBackgroundColor(Color.parseColor("#2E1065"))
            Toast.makeText(this, "Touch top-left corner of phone to Mac's RIGHT lid bezel", Toast.LENGTH_SHORT).show()
        }

        binding.btnResetCalib.setOnClickListener {
            detector.resetCalibration()
            updateCalibrationUI()
            Toast.makeText(this, "Calibration reset to smart kinematics mode", Toast.LENGTH_SHORT).show()
        }

        // Test Pull Button (Simulate Left Bezel Beam)
        binding.btnTestPull.setOnClickListener {
            executeHandoff("left", 220f)
        }

        // Test Push Button (Simulate Right Bezel Beam)
        binding.btnTestPush.setOnClickListener {
            executeHandoff("right", 220f)
        }

        // Paste URL Button
        binding.btnPasteUrl.setOnClickListener {
            NoxSnapState.updateFromClipboard(this)
            updatePushUrlDisplay()
            Toast.makeText(this, "Updated link from clipboard!", Toast.LENGTH_SHORT).show()
        }

        // Invert Polarity Switch
        val prefs = getSharedPreferences(MagneticDockDetector.PREFS_NAME, Context.MODE_PRIVATE)
        binding.switchInvert.isChecked = detector.invertPolarity
        binding.switchInvert.setOnCheckedChangeListener { _, isChecked ->
            detector.invertPolarity = isChecked
            prefs.edit().putBoolean(MagneticDockDetector.KEY_INVERT_POLARITY, isChecked).apply()
            val mode = if (isChecked) "Inverted (Left=Push, Right=Pull)" else "Standard (Left=Pull, Right=Push)"
            Toast.makeText(this, "Orientation: $mode", Toast.LENGTH_SHORT).show()
        }

        // Background Service Toggle
        binding.switchBackgroundService.setOnCheckedChangeListener { _, isChecked ->
            val intent = Intent(this, NoxSnapService::class.java)
            if (isChecked) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                Toast.makeText(this, "⚡️ Background Snap Service active", Toast.LENGTH_SHORT).show()
            } else {
                stopService(intent)
                Toast.makeText(this, "Background service paused", Toast.LENGTH_SHORT).show()
            }
        }

        // Auto-start background service
        val serviceIntent = Intent(this, NoxSnapService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun updateCalibrationUI() {
        binding.cardCalibration.visibility = View.GONE
    }

    private fun updatePushUrlDisplay() {
        val url = NoxSnapState.getBestAvailableUrl(this)
        binding.tvActivePushUrl.text = if (url.isNotEmpty()) url else "https://google.com"
    }

    private fun updateMagneticGauge(
        magnitude: Float,
        bx: Float,
        by: Float,
        bz: Float,
        yaw: Float,
        roll: Float,
        direction: DockDirection,
        isCalibrated: Boolean
    ) {
        val magInt = magnitude.toInt()
        binding.tvMagnitude.text = "$magInt µT"
        binding.progressStrength.progress = magInt.coerceAtMost(500)
        
        val modeStr = if (isCalibrated) "Calibrated" else "Smart Kinematic"
        binding.tvVectorDetails.text = String.format("Yaw: %+.1f°  |  Roll: %+.1f°  |  %s", yaw, roll, modeStr)

        when {
            magnitude >= 80f -> {
                binding.tvMagnitude.setTextColor(Color.parseColor("#10B981"))
                binding.progressStrength.setIndicatorColor(Color.parseColor("#10B981"))
                binding.tvFieldStatus.text = "⚡ MAGNET CONTACT: BEAMING TAB TO MAC CHROME"
                binding.tvFieldStatus.setTextColor(Color.parseColor("#FFFFFF"))
                binding.tvFieldStatus.setBackgroundColor(Color.parseColor("#064E3B"))
                binding.cardGauge.setStrokeColor(Color.parseColor("#10B981"))
            }
            magnitude >= 55f -> {
                binding.tvMagnitude.setTextColor(Color.parseColor("#38BDF8"))
                binding.progressStrength.setIndicatorColor(Color.parseColor("#38BDF8"))
                binding.tvFieldStatus.text = "🌊 Approaching MacBook..."
                binding.tvFieldStatus.setTextColor(Color.parseColor("#38BDF8"))
                binding.tvFieldStatus.setBackgroundColor(Color.parseColor("#172554"))
                binding.cardGauge.setStrokeColor(Color.parseColor("#38BDF8"))
            }
            else -> {
                binding.tvMagnitude.setTextColor(Color.parseColor("#06B6D4"))
                binding.progressStrength.setIndicatorColor(Color.parseColor("#06B6D4"))
                binding.tvFieldStatus.text = "👉 Snap phone to ANY Mac bezel magnet to beam tab"
                binding.tvFieldStatus.setTextColor(Color.parseColor("#94A3B8"))
                binding.tvFieldStatus.setBackgroundColor(Color.parseColor("#1E2438"))
                binding.cardGauge.setStrokeColor(Color.parseColor("#252A40"))
            }
        }
    }

    private fun executeHandoff(side: String, magnitude: Float) {
        val mac = selectedDevice ?: NoxSnapDiscovery.getCachedMac(this)
        if (mac == null) {
            Toast.makeText(this, "⚠️ Searching for Mac on Wi-Fi...", Toast.LENGTH_SHORT).show()
            return
        }

        lifecycleScope.launch {
            val handoffUrl = NoxSnapState.getBestAvailableUrl(this@MainActivity)
            val handoffText = NoxSnapState.latestClipboardText

            val resp = client.sendDock(
                mac = mac,
                direction = DockDirection.PUSH,
                handoffUrl = handoffUrl,
                handoffText = handoffText,
                side = side
            )

            if (resp == null) {
                Toast.makeText(this@MainActivity, "❌ Failed to connect to ${mac.name}", Toast.LENGTH_SHORT).show()
                return@launch
            }

            val displayLink = handoffUrl.ifEmpty { handoffText ?: "Active Tab" }
            Toast.makeText(this@MainActivity, "🌊 Beamed to Chrome on ${mac.name}!\n$displayLink", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onResume() {
        super.onResume()
        isActivityVisible = true
        NoxSnapState.updateFromClipboard(this)
        updatePushUrlDisplay()
        detector.loadPreferences()
        updateCalibrationUI()
        discovery.startDiscovery()
        detector.startListening()
    }

    override fun onPause() {
        super.onPause()
        isActivityVisible = false
        detector.stopListening()
    }

    override fun onDestroy() {
        super.onDestroy()
        isActivityVisible = false
        discovery.stopDiscovery()
    }
}
