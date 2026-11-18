package com.naveen.noxsnap

import android.content.ClipboardManager
import android.content.Context
import android.util.Log

object NoxSnapState {
    private const val TAG = "NoxSnapState"
    const val PREFS_STATE = "noxsnap_state"
    const val KEY_LAST_URL = "last_captured_url"
    
    var latestHandoffUrl: String = ""
    var latestClipboardText: String = ""

    fun updateFromClipboard(context: Context) {
        try {
            val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            if (cm != null && cm.hasPrimaryClip()) {
                val text = cm.primaryClip?.getItemAt(0)?.text?.toString()?.trim()
                if (!text.isNullOrEmpty()) {
                    latestClipboardText = text
                    if (isWebUrl(text)) {
                        val formatted = formatUrl(text)
                        latestHandoffUrl = formatted
                        savePersistentUrl(context, formatted)
                        Log.d(TAG, "Cached active URL from clipboard: $latestHandoffUrl")
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Clipboard read restricted: ${e.message}")
        }
    }

    fun savePersistentUrl(context: Context, url: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_STATE, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_LAST_URL, url).apply()
        } catch (e: Exception) {}
    }

    fun isWebUrl(text: String): Boolean {
        val lower = text.lowercase()
        return lower.startsWith("http://") || 
               lower.startsWith("https://") || 
               lower.contains(".com") || 
               lower.contains(".org") || 
               lower.contains(".net") || 
               lower.contains(".io") || 
               lower.contains(".edu") || 
               lower.contains(".be") || 
               lower.contains(".in") ||
               lower.contains("youtu.be") || 
               lower.contains("youtube.com")
    }

    fun formatUrl(text: String): String {
        var trimmed = text.trim()
        val suffixes = listOf(
            ". Connection is not secure",
            ". Secure connection",
            "• Connection is not secure",
            "• Secure connection"
        )
        for (suffix in suffixes) {
            val idx = trimmed.indexOf(suffix, ignoreCase = true)
            if (idx != -1) {
                trimmed = trimmed.substring(0, idx).trim()
            }
        }
        if (trimmed.startsWith("http://", ignoreCase = true) || trimmed.startsWith("https://", ignoreCase = true)) {
            trimmed = trimmed.replace(" ", "%20")
        } else if (trimmed.contains(" ")) {
            trimmed = trimmed.split(" ")[0].trim()
        }
        if (!trimmed.lowercase().startsWith("http://") && !trimmed.lowercase().startsWith("https://")) {
            trimmed = "https://$trimmed"
        }
        return trimmed
    }

    fun getBestAvailableUrl(context: Context): String {
        updateFromClipboard(context)
        if (latestHandoffUrl.isNotEmpty()) {
            return latestHandoffUrl
        }
        val prefs = context.getSharedPreferences(PREFS_STATE, Context.MODE_PRIVATE)
        val saved = prefs.getString(KEY_LAST_URL, "") ?: ""
        if (saved.isNotEmpty()) {
            latestHandoffUrl = saved
            return saved
        }
        if (latestClipboardText.isNotEmpty() && isWebUrl(latestClipboardText)) {
            val formatted = formatUrl(latestClipboardText)
            latestHandoffUrl = formatted
            savePersistentUrl(context, formatted)
            return formatted
        }
        // Failsafe: Never abort Push! Always beam a valid web page!
        return "https://www.google.com"
    }
}
