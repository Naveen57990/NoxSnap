package com.naveen.noxsnap.network

import android.os.Build
import android.util.Log
import com.naveen.noxsnap.sensors.DockDirection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

data class DiscoveredMac(
    val name: String,
    val host: String,
    val port: Int
)

class NoxSnapClient {
    private val tag = "NoxSnapClient"

    suspend fun checkStatus(host: String, port: Int = 53320): JSONObject? = withContext(Dispatchers.IO) {
        val target = "http://$host:$port/status"
        try {
            val url = URL(target)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 1500
            conn.readTimeout = 1500
            conn.requestMethod = "GET"
            if (conn.responseCode in 200..299) {
                val resp = conn.inputStream.bufferedReader().use { it.readText() }
                conn.disconnect()
                return@withContext JSONObject(resp)
            }
            conn.disconnect()
            null
        } catch (e: Exception) {
            null
        }
    }

    suspend fun sendDock(
        mac: DiscoveredMac,
        direction: DockDirection = DockDirection.PUSH,
        handoffUrl: String? = null,
        handoffText: String? = null,
        side: String = "right"
    ): JSONObject? = withContext(Dispatchers.IO) {
        val target = "http://${mac.host}:${mac.port}/dock?direction=push&side=$side"
        try {
            val url = URL(target)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 3500
            conn.readTimeout = 3500
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("X-Sender-Name", "${Build.MANUFACTURER} ${Build.MODEL}")
            conn.setRequestProperty("X-Dock-Direction", "push")
            conn.setRequestProperty("X-Dock-Side", side)
            if (!handoffUrl.isNullOrEmpty()) {
                conn.setRequestProperty("X-Handoff-URL", handoffUrl)
            }
            if (!handoffText.isNullOrEmpty()) {
                val encodedText = URLEncoder.encode(handoffText, "UTF-8")
                conn.setRequestProperty("X-Handoff-Text", encodedText)
            }

            val body = JSONObject().apply {
                put("direction", "push")
                put("side", side)
                put("url", handoffUrl ?: "")
                put("text", handoffText ?: "")
            }

            conn.outputStream.use { os ->
                os.write(body.toString().toByteArray())
                os.flush()
            }

            if (conn.responseCode in 200..299) {
                val resp = conn.inputStream.bufferedReader().use { it.readText() }
                conn.disconnect()
                return@withContext JSONObject(resp)
            }
            conn.disconnect()
            null
        } catch (e: Exception) {
            Log.e(tag, "sendDock error: ${e.message}")
            null
        }
    }
}
