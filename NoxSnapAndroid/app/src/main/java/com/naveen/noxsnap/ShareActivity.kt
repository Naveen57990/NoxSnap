package com.naveen.noxsnap

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrEmpty()) {
                NoxSnapState.latestClipboardText = sharedText
                if (NoxSnapState.isWebUrl(sharedText)) {
                    NoxSnapState.latestHandoffUrl = NoxSnapState.formatUrl(sharedText)
                }
                Toast.makeText(this, "⚡️ Ready to Snap to Mac:\n${NoxSnapState.latestHandoffUrl}", Toast.LENGTH_LONG).show()
            }
        }

        finish()
    }
}
