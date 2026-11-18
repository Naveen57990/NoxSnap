package com.naveen.noxsnap.sensors

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.abs
import kotlin.math.sqrt

enum class DockDirection(val label: String, val wireValue: String) {
    PULL("Mac ➔ Phone (Pull)", "pull"),
    PUSH("Phone ➔ Mac (Push)", "push")
}

private enum class ContactState {
    ARMED,             // In air / away from MacBook (< 52 µT) -> Ready for next touch
    LOCKED_IN_CONTACT, // Touching magnet (> 78 µT) -> Fired ONCE, locked until lifted away
    COOLDOWN           // Lifted away, waiting 1s debounce before re-arming
}

class MagneticDockDetector(
    private val context: Context,
    private val onDockDetected: (magnitude: Float, direction: DockDirection, side: String) -> Unit,
    private val onFieldUpdated: ((magnitude: Float, bx: Float, by: Float, bz: Float, yaw: Float, roll: Float, direction: DockDirection, isCalibrated: Boolean) -> Unit)? = null,
    private val onCalibrationComplete: ((target: DockDirection, yaw: Float, roll: Float) -> Unit)? = null
) : SensorEventListener {

    private val tag = "MagneticDockDetector"
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val magneticSensor = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
    private val rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
        ?: sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        // Global atomic lock: Guarantees ONLY ONE component fires across the whole phone
        val isGlobalHandoffBusy = AtomicBoolean(false)
        val lastGlobalDockTime = AtomicLong(0L)
        
        const val PREFS_NAME = "noxsnap_prefs"
        const val KEY_INVERT_POLARITY = "invert_polarity"
        const val KEY_IS_CALIBRATED = "is_calibrated"
        const val KEY_LEFT_YAW = "calib_left_yaw"
        const val KEY_LEFT_ROLL = "calib_left_roll"
        const val KEY_RIGHT_YAW = "calib_right_yaw"
        const val KEY_RIGHT_ROLL = "calib_right_roll"
    }

    // State machine for physical immunity
    private var contactState = ContactState.ARMED
    private var releaseTime = 0L

    // Magnetic field thresholds
    private var baselineBx = 12.0f
    private var baselineBy = 28.0f
    private var baselineBz = -1.0f
    private var baselineMag = 35.0f

    private val dockThreshold = 78.0f
    private val deltaThreshold = 24.0f
    private val releaseThreshold = 52.0f

    // 3D Orientation (Bosch BMI3xy, 100% immune to magnetic fields)
    private val rotationMatrix = FloatArray(9)
    private val orientationAngles = FloatArray(3)
    private var currentYaw = 0.0f
    private var currentPitch = 0.0f
    private var currentRoll = 0.0f

    // Calibration state
    var isCalibrated: Boolean = false
    var calibLeftYaw: Float = -115.0f
    var calibLeftRoll: Float = 140.0f
    var calibRightYaw: Float = -75.0f
    var calibRightRoll: Float = -10.0f
    var activeCalibratingTarget: DockDirection? = null

    var invertPolarity: Boolean = false

    init {
        loadPreferences()
    }

    fun loadPreferences() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        invertPolarity = prefs.getBoolean(KEY_INVERT_POLARITY, false)
        val savedCalib = prefs.getBoolean(KEY_IS_CALIBRATED, false)
        val leftY = prefs.getFloat(KEY_LEFT_YAW, -115.0f)
        val rightY = prefs.getFloat(KEY_RIGHT_YAW, -75.0f)
        val leftR = prefs.getFloat(KEY_LEFT_ROLL, 140.0f)
        val rightR = prefs.getFloat(KEY_RIGHT_ROLL, -10.0f)
        
        val yawDist = angularDistance(leftY, rightY)
        val rollDist = abs(leftR - rightR)
        val totalDistance = sqrt((yawDist * yawDist + rollDist * rollDist).toDouble()).toFloat()

        if (savedCalib && totalDistance >= 25.0f) {
            isCalibrated = true
            calibLeftYaw = leftY
            calibLeftRoll = leftR
            calibRightYaw = rightY
            calibRightRoll = rightR
        } else {
            isCalibrated = false
            calibLeftYaw = -115.0f
            calibRightYaw = -75.0f
            calibLeftRoll = 140.0f
            calibRightRoll = -10.0f
        }
        Log.d(tag, "Loaded Calib: valid=$isCalibrated, LeftYaw=$calibLeftYaw, RightYaw=$calibRightYaw")
    }

    fun startCalibration(target: DockDirection) {
        activeCalibratingTarget = target
        Log.i(tag, "🎯 Started calibration for: ${target.label}")
        triggerHapticClick()
    }

    fun cancelCalibration() {
        activeCalibratingTarget = null
    }

    fun resetCalibration() {
        isCalibrated = false
        activeCalibratingTarget = null
        calibLeftYaw = -115.0f
        calibRightYaw = -75.0f
        calibLeftRoll = 140.0f
        calibRightRoll = -10.0f
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
        Log.i(tag, "Reset calibration to pure kinematic model")
        triggerHapticClick()
    }

    fun saveCalibrationCorner(target: DockDirection, yaw: Float, roll: Float) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        if (target == DockDirection.PULL) {
            calibLeftYaw = yaw
            calibLeftRoll = roll
            editor.putFloat(KEY_LEFT_YAW, yaw)
            editor.putFloat(KEY_LEFT_ROLL, roll)
        } else {
            calibRightYaw = yaw
            calibRightRoll = roll
            editor.putFloat(KEY_RIGHT_YAW, yaw)
            editor.putFloat(KEY_RIGHT_ROLL, roll)
        }
        
        // Strict separation check: Must be at least 25° separated in 3D posture!
        val yawDist = angularDistance(calibLeftYaw, calibRightYaw)
        val rollDist = abs(calibLeftRoll - calibRightRoll)
        val totalDistance = sqrt((yawDist * yawDist + rollDist * rollDist).toDouble()).toFloat()

        if (totalDistance >= 25.0f) {
            isCalibrated = true
            editor.putBoolean(KEY_IS_CALIBRATED, true)
            Log.i(tag, "✅ Calibration verified with 3D separation: %.1f°".format(totalDistance))
        } else {
            isCalibrated = false
            editor.putBoolean(KEY_IS_CALIBRATED, false)
            Log.w(tag, "⚠️ Calibration rejected: separation %.1f° < 25°".format(totalDistance))
        }
        editor.apply()
        
        activeCalibratingTarget = null
        triggerHapticCelebration()
        onCalibrationComplete?.invoke(target, yaw, roll)
        Log.i(tag, "Saved corner: ${target.label} => Yaw: $yaw, Roll: $roll")
    }

    fun startListening() {
        if (magneticSensor != null) {
            sensorManager.registerListener(this, magneticSensor, SensorManager.SENSOR_DELAY_UI)
        }
        if (rotationSensor != null) {
            sensorManager.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_UI)
        }
        contactState = ContactState.ARMED
        Log.d(tag, "🧲 Sensors registered (Immune Hysteresis Active)")
    }

    fun stopListening() {
        sensorManager.unregisterListener(this)
        contactState = ContactState.ARMED
        Log.d(tag, "🧲 Sensors stopped")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        val now = System.currentTimeMillis()

        // 1. Bosch BMI3xy 3D Rotation Vector (Immune to magnetic fields)
        if (event.sensor.type == Sensor.TYPE_GAME_ROTATION_VECTOR || event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            SensorManager.getOrientation(rotationMatrix, orientationAngles)
            
            currentYaw = Math.toDegrees(orientationAngles[0].toDouble()).toFloat()
            currentPitch = Math.toDegrees(orientationAngles[1].toDouble()).toFloat()
            currentRoll = Math.toDegrees(orientationAngles[2].toDouble()).toFloat()
            return
        }

        // 2. High-Sensitivity Magnetometer with Immune State Machine
        if (event.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
            val bx = event.values[0]
            val by = event.values[1]
            val bz = event.values[2]

            val magnitude = sqrt((bx * bx + by * by + bz * bz).toDouble()).toFloat()

            // Dynamic ambient baseline tracking when away from laptop magnets (< 52 µT)
            if (magnitude in 20.0f..52.0f) {
                baselineMag = baselineMag * 0.95f + magnitude * 0.05f
                baselineBx = baselineBx * 0.95f + bx * 0.05f
                baselineBy = baselineBy * 0.95f + by * 0.05f
                baselineBz = baselineBz * 0.95f + bz * 0.05f
            }

            val deltaMag = magnitude - baselineMag

            // Classify Direction
            val rawDirection = classifyDirection(currentYaw, currentRoll)
            val direction = if (!invertPolarity) rawDirection else {
                if (rawDirection == DockDirection.PUSH) DockDirection.PULL else DockDirection.PUSH
            }

            onFieldUpdated?.invoke(magnitude, bx, by, bz, currentYaw, currentRoll, direction, isCalibrated)

            // --- PHYSICAL IMMUNITY HYSTERESIS & RELEASE GATE ---
            when (contactState) {
                ContactState.LOCKED_IN_CONTACT -> {
                    // While phone is resting on the magnet, NOTHING CAN EVER FIRE!
                    // Zero toggles, zero secondary swaps, zero repeats!
                    if (magnitude < releaseThreshold) {
                        // Phone has been physically lifted away from the MacBook bezel
                        contactState = ContactState.COOLDOWN
                        releaseTime = now
                        Log.d(tag, "👋 Phone lifted away from bezel. Entering cooldown.")
                    }
                }

                ContactState.COOLDOWN -> {
                    if (magnitude >= releaseThreshold) {
                        // Bounced back before cooldown finished; stay locked
                        contactState = ContactState.LOCKED_IN_CONTACT
                    } else if (now - releaseTime > 800L) {
                        // Clean release confirmed; re-arm for next dock
                        contactState = ContactState.ARMED
                        isGlobalHandoffBusy.set(false)
                        Log.d(tag, "✅ Detector Re-Armed and ready for next dock.")
                    }
                }

                ContactState.ARMED -> {
                    // Check for new physical contact with MacBook lid bezel
                    if (magnitude >= dockThreshold && deltaMag >= deltaThreshold) {
                        val lastTime = lastGlobalDockTime.get()
                        val elapsed = now - lastTime

                        // Check calibration mode first
                        val calibTarget = activeCalibratingTarget
                        if (calibTarget != null && elapsed > 800L) {
                            if (lastGlobalDockTime.compareAndSet(lastTime, now)) {
                                contactState = ContactState.LOCKED_IN_CONTACT
                                saveCalibrationCorner(calibTarget, currentYaw, currentRoll)
                                return
                            }
                        }

                        // Normal Handoff Dock (Pure Phone ➔ Mac Push):
                        // Require at least 1.5s cooldown AND atomic global busy check
                        if (elapsed > 1500L && isGlobalHandoffBusy.compareAndSet(false, true)) {
                            lastGlobalDockTime.set(now)
                            contactState = ContactState.LOCKED_IN_CONTACT

                            val dockSide = if (abs(currentRoll) > 55.0f || currentYaw <= -95.0f) "left" else "right"
                            Log.i(tag, "⚡️ Discrete Snap Fired! Mag: %.1f µT, Side: %s -> Beaming to Mac"
                                .format(magnitude, dockSide))
                            
                            logEventToFile(now, magnitude, currentYaw, currentRoll, bx, by, bz, DockDirection.PUSH)
                            triggerHapticFeedback(DockDirection.PUSH)
                            onDockDetected(magnitude, DockDirection.PUSH, dockSide)

                            // Safety release timer in case sensor didn't drop below threshold
                            mainHandler.postDelayed({
                                isGlobalHandoffBusy.set(false)
                            }, 2000L)
                        }
                    }
                }
            }
        }
    }

    fun classifyDirection(yaw: Float, roll: Float): DockDirection {
        // 1. If user calibrated with verified 3D posture separation:
        if (isCalibrated) {
            val distToLeftYaw = angularDistance(yaw, calibLeftYaw)
            val distToLeftRoll = abs(roll - calibLeftRoll)
            val distToLeft = distToLeftYaw * distToLeftYaw + distToLeftRoll * distToLeftRoll

            val distToRightYaw = angularDistance(yaw, calibRightYaw)
            val distToRightRoll = abs(roll - calibRightRoll)
            val distToRight = distToRightYaw * distToRightYaw + distToRightRoll * distToRightRoll

            return if (distToLeft < distToRight) DockDirection.PULL else DockDirection.PUSH
        }

        // 2. Pure Kinematic 3D Posture Model (Zero drift, 100% deterministic):
        // Physical Fact A: If the phone is flipped/tilted (user flips phone to reach left bezel with left magnet):
        // abs(roll) > 55° is ALWAYS Left Bezel (Pull).
        if (abs(roll) > 55.0f) {
            return DockDirection.PULL
        }

        // Physical Fact B: When upright (abs(roll) <= 55°):
        // Reaching across chest to Left Bezel rotates forearm counter-clockwise: yaw <= -95.0° (range -100° to -149°) -> PULL
        // Reaching straight to Right Bezel holds phone at normal angle: yaw > -95.0° (range -40° to -90°) -> PUSH
        return if (yaw <= -95.0f) {
            DockDirection.PULL
        } else {
            DockDirection.PUSH
        }
    }

    private fun angularDistance(a: Float, b: Float): Float {
        var diff = (a - b) % 360f
        if (diff < -180f) diff += 360f
        if (diff > 180f) diff -= 360f
        return abs(diff)
    }

    private fun logEventToFile(now: Long, mag: Float, yaw: Float, roll: Float, bx: Float, by: Float, bz: Float, dir: DockDirection) {
        try {
            val dirFile = context.getExternalFilesDir(null) ?: context.filesDir
            val logFile = File(dirFile, "dock_events.log")
            logFile.appendText("TIME: $now | MAG: %.1f | YAW: %+.1f° | ROLL: %+.1f° | B: (%+.1f, %+.1f, %+.1f) | DIR: %s\n"
                .format(mag, yaw, roll, bx, by, bz, dir.label))
        } catch (e: Exception) {}
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun triggerHapticFeedback(direction: DockDirection) {
        try {
            val vibrator = getVibrator()
            if (direction == DockDirection.PULL) {
                // Pull: Soft magnetic double pulse
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val timings = longArrayOf(0, 35, 45, 60)
                    val amplitudes = intArrayOf(0, 140, 0, 230)
                    vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(longArrayOf(0, 35, 45, 60), -1)
                }
            } else {
                // Push: Crisp Apple-style haptic tap
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK))
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(50)
                }
            }
        } catch (e: Exception) {}
    }

    private fun triggerHapticCelebration() {
        try {
            val vibrator = getVibrator()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val timings = longArrayOf(0, 40, 50, 40, 50, 80)
                val amplitudes = intArrayOf(0, 160, 0, 180, 0, 255)
                vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(150)
            }
        } catch (e: Exception) {}
    }

    private fun triggerHapticClick() {
        try {
            val vibrator = getVibrator()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(25)
            }
        } catch (e: Exception) {}
    }

    private fun getVibrator(): Vibrator {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }
}
