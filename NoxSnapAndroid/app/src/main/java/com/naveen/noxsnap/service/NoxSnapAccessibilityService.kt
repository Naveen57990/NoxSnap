package com.naveen.noxsnap.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.naveen.noxsnap.NoxSnapState

class NoxSnapAccessibilityService : AccessibilityService() {

    private val tag = "NoxSnapA11y"

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        // Filter for browser packages and media apps
        val isBrowser = pkg.contains("chrome") ||
                        pkg.contains("browser") ||
                        pkg.contains("firefox") ||
                        pkg.contains("opera") ||
                        pkg.contains("duckduckgo") ||
                        pkg == "com.google.android.youtube"

        if (!isBrowser) return

        val rootNode = rootInActiveWindow ?: return
        try {
            val url = extractUrlFromNode(rootNode, pkg)
            if (!url.isNullOrEmpty() && NoxSnapState.isWebUrl(url)) {
                val formatted = NoxSnapState.formatUrl(url)
                if (NoxSnapState.latestHandoffUrl != formatted) {
                    NoxSnapState.latestHandoffUrl = formatted
                    NoxSnapState.savePersistentUrl(this, formatted)
                    Log.d(tag, "⚡️ Auto-captured live browser URL: $formatted")
                }
            }
        } catch (e: Exception) {
            Log.w(tag, "Error extracting URL: ${e.message}")
        }
    }

    private fun extractUrlFromNode(node: AccessibilityNodeInfo?, pkg: String): String? {
        if (node == null) return null

        // 1. Check known URL bar resource IDs
        val knownIds = listOf(
            "$pkg:id/url_bar",
            "com.android.chrome:id/url_bar",
            "com.brave.browser:id/url_bar",
            "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
            "com.microsoft.emmx:id/search_box_text"
        )

        for (id in knownIds) {
            val matches = node.findAccessibilityNodeInfosByViewId(id)
            for (m in matches) {
                val txt = m.text?.toString()?.trim()
                if (!txt.isNullOrEmpty() && (txt.contains(".") || txt.startsWith("http"))) {
                    return txt
                }
            }
        }

        // 2. Fallback: Search for any EditText or view containing web URL text
        if (node.className?.toString()?.contains("EditText") == true) {
            val text = node.text?.toString()?.trim()
            if (!text.isNullOrEmpty() && NoxSnapState.isWebUrl(text)) {
                return text
            }
        }

        // Recursively inspect children up to depth 5
        val childCount = node.childCount
        for (i in 0 until childCount.coerceAtMost(25)) {
            val child = node.getChild(i)
            val res = extractUrlFromNode(child, pkg)
            if (res != null) return res
        }

        return null
    }

    override fun onInterrupt() {
        Log.d(tag, "Accessibility Service Interrupted")
    }
}
